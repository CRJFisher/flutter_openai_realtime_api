import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:rxdart/rxdart.dart';

import '../auth/ephemeral_token.dart';
import '../connection/realtime_transport.dart';
import '../connection/webrtc_connection.dart';
import '../connection/websocket_connection.dart';
import '../internal/event_parser.dart';
import '../internal/logger.dart';
import '../internal/protocol.dart';
import '../models/config.dart';
import '../models/conversation_item.dart';
import '../models/enums.dart';
import '../models/events.dart';
import '../models/mute_strategy.dart';
import '../models/tool.dart';
import '../models/turn_detection.dart';

/// Top-level client for the OpenAI Realtime API.
///
/// One client manages one connection. To start a new session after
/// `dispose()`, construct a fresh client.
class RealtimeClient with LoggerMixin {
  final RealtimeConfig config;
  final RealtimeTransport _transport;

  final _events = BehaviorSubject<RealtimeEvent>();
  final _connectionState = ValueNotifier<ConnectionState>(
    ConnectionState.disconnected,
  );
  final _isMuted = ValueNotifier<bool>(false);

  StreamSubscription<String>? _msgSub;
  StreamSubscription<ConnectionState>? _stateSub;
  StreamSubscription<RealtimeEvent>? _autoMuteSub;

  String? _sessionId;
  bool _disposed = false;
  int _seq = 0;

  RealtimeClient._(this.config, this._transport) {
    _stateSub = _transport.onState.listen(_onState);
    _msgSub = _transport.onMessage.listen(_onRawMessage);
  }

  /// WebRTC client. Use this from Flutter apps.
  ///
  /// Provide either an [EphemeralTokenProvider] (recommended) or an
  /// `apiKey` directly via [config]. The provider is invoked lazily
  /// inside [connect].
  factory RealtimeClient.webRtc(RealtimeConfig config) =>
      RealtimeClient._(config, RealtimeWebRtcTransport(config));

  /// WebSocket client. Suitable for server-side Dart (e.g. Cloud
  /// Functions). Not recommended for browser builds.
  factory RealtimeClient.webSocket(RealtimeConfig config) =>
      RealtimeClient._(config, RealtimeWebSocketTransport(config));

  // ---------------------------------------------------------------------------
  // Public state
  // ---------------------------------------------------------------------------

  /// All events: protocol-level (server-emitted) plus locally synthesized
  /// `ConnectionEvent`s.
  Stream<RealtimeEvent> get events => _events.stream;

  ValueListenable<ConnectionState> get connectionState => _connectionState;
  ValueListenable<bool> get isMuted => _isMuted;

  String? get sessionId => _sessionId;

  /// Server-assigned WebRTC call id (`rtc_…`). `null` for WebSocket
  /// transport or before the connection is established. Useful for
  /// correlating client logs with OpenAI billing.
  String? get callId => _transport.callId;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Connects to the server and applies the session config.
  Future<void> connect() async {
    if (_disposed) throw StateError('RealtimeClient has been disposed');
    if (_connectionState.value == ConnectionState.connected) return;

    try {
      await _transport.connect();
      // Push our session config so the server uses it for the rest of
      // the session.
      await _send({
        'event_id': _nextId(),
        'type': Protocol.sessionUpdate,
        'session': config.toSessionJson(),
      });

      // If the caller chose `MuteStrategy.aggressive` (or `auto` resolved
      // to it on Android), mute the mic while assistant audio is playing.
      if (config.muteStrategy.enabled) _wireAutoMute();
    } catch (e, s) {
      logError('connect failed', e, s);
      rethrow;
    }
  }

  /// Closes the connection and frees all resources. Idempotent.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _autoMuteSub?.cancel();
    await _msgSub?.cancel();
    await _stateSub?.cancel();
    await _transport.dispose();
    if (!_events.isClosed) await _events.close();
    _connectionState.dispose();
    _isMuted.dispose();
  }

  // ---------------------------------------------------------------------------
  // Conversation
  // ---------------------------------------------------------------------------

  /// Convenience: send a user text message and ask for a response.
  Future<void> sendMessage(String text, {bool createResponse = true}) async {
    await createConversationItem(ConversationItem.userMessage(text: text));
    if (createResponse) await this.createResponse();
  }

  Future<void> createConversationItem(ConversationItem item) {
    return _send({
      'event_id': _nextId(),
      'type': Protocol.conversationItemCreate,
      'item': item.toJson(),
    });
  }

  /// WebSocket-only. Append a chunk of input audio to the server-side
  /// buffer. No-op semantically meaningful in WebRTC mode (audio flows
  /// over the RTC track), but the server will accept and ignore the event.
  Future<void> appendInputAudioBuffer(List<int> bytes) {
    return _send({
      'event_id': _nextId(),
      'type': Protocol.inputAudioBufferAppend,
      'audio': base64Encode(bytes),
    });
  }

  Future<void> commitInputAudioBuffer() => _send({
        'event_id': _nextId(),
        'type': Protocol.inputAudioBufferCommit,
      });

  Future<void> clearInputAudioBuffer() => _send({
        'event_id': _nextId(),
        'type': Protocol.inputAudioBufferClear,
      });

  /// Truncates a previously-emitted assistant item. Use this together
  /// with [cancelResponse] and [clearOutputAudioBuffer] when implementing
  /// barge-in. `audioEndMs` is the playback position (in ms relative to
  /// the start of the item's audio) at which the user interrupted.
  Future<void> truncateConversation({
    required String itemId,
    required int contentIndex,
    required int audioEndMs,
  }) {
    return _send({
      'event_id': _nextId(),
      'type': Protocol.conversationItemTruncate,
      'item_id': itemId,
      'content_index': contentIndex,
      'audio_end_ms': audioEndMs,
    });
  }

  Future<void> deleteConversationItem(String itemId) => _send({
        'event_id': _nextId(),
        'type': Protocol.conversationItemDelete,
        'item_id': itemId,
      });

  // ---------------------------------------------------------------------------
  // Response control
  // ---------------------------------------------------------------------------

  /// Asks the model to generate the next response. Required after a
  /// `function_call_output` item — the server does not auto-respond
  /// after a tool result.
  Future<void> createResponse({
    List<Modality>? outputModalities,
    String? instructions,
    Voice? voice,
    List<Tool>? tools,
    ToolChoice? toolChoice,
    double? temperature,
    int? maxOutputTokens,
    /// Pass `"none"` for an out-of-band response that does not affect
    /// the conversation history.
    String? conversation,
    Map<String, String>? metadata,
  }) {
    final response = <String, dynamic>{
      if (outputModalities != null)
        'output_modalities': outputModalities.map((m) => m.id).toList(),
      if (instructions != null) 'instructions': instructions,
      if (voice != null) 'voice': voice.id,
      if (tools != null) 'tools': tools.map((t) => t.toJson()).toList(),
      if (toolChoice != null) 'tool_choice': toolChoice.toJson(),
      if (temperature != null) 'temperature': temperature,
      if (maxOutputTokens != null) 'max_output_tokens': maxOutputTokens,
      if (conversation != null) 'conversation': conversation,
      if (metadata != null) 'metadata': metadata,
    };
    return _send({
      'event_id': _nextId(),
      'type': Protocol.responseCreate,
      if (response.isNotEmpty) 'response': response,
    });
  }

  Future<void> cancelResponse() => _send({
        'event_id': _nextId(),
        'type': Protocol.responseCancel,
      });

  /// WebRTC-only. Tells the server to stop streaming any queued audio
  /// for the current response. The full barge-in sequence is:
  ///
  /// 1. [cancelResponse]
  /// 2. [clearOutputAudioBuffer]
  /// 3. [truncateConversation] with the playback position
  Future<void> clearOutputAudioBuffer() => _send({
        'event_id': _nextId(),
        'type': Protocol.outputAudioBufferClear,
      });

  // ---------------------------------------------------------------------------
  // Session updates
  // ---------------------------------------------------------------------------

  /// Patch the session's runtime configuration. Pass only the fields you
  /// want to change. Some fields (e.g. `voice`) are rejected after the
  /// model has produced its first audio in the session.
  Future<void> updateSession({
    List<Modality>? outputModalities,
    String? instructions,
    Voice? voice,
    TurnDetection? turnDetection,
    List<Tool>? tools,
    ToolChoice? toolChoice,
    double? temperature,
    int? maxOutputTokens,
  }) {
    final session = <String, dynamic>{
      'type': 'realtime',
      if (outputModalities != null)
        'output_modalities': outputModalities.map((m) => m.id).toList(),
      if (instructions != null) 'instructions': instructions,
      if (voice != null || turnDetection != null)
        'audio': {
          if (turnDetection != null)
            'input': {'turn_detection': turnDetection.toJson()},
          if (voice != null)
            'output': {'voice': voice.id},
        },
      if (tools != null) 'tools': tools.map((t) => t.toJson()).toList(),
      if (toolChoice != null) 'tool_choice': toolChoice.toJson(),
      if (temperature != null) 'temperature': temperature,
      if (maxOutputTokens != null) 'max_output_tokens': maxOutputTokens,
    };
    return _send({
      'event_id': _nextId(),
      'type': Protocol.sessionUpdate,
      'session': session,
    });
  }

  // ---------------------------------------------------------------------------
  // Audio control
  // ---------------------------------------------------------------------------

  /// Mute / unmute the local microphone. WebRTC transport applies the
  /// configured [MuteStrategy]; WebSocket transport ignores this (callers
  /// control input by not appending audio).
  Future<void> setMuted(bool muted) async {
    await _transport.setMicEnabled(!muted);
    _isMuted.value = muted;
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Future<void> _send(Map<String, dynamic> message) async {
    if (_disposed) return;
    await _transport.sendMessage(jsonEncode(message));
  }

  String _nextId() {
    _seq++;
    return 'client_${DateTime.now().microsecondsSinceEpoch}_$_seq';
  }

  void _onState(ConnectionState state) {
    _connectionState.value = state;
    final id = _nextId();
    final ts = DateTime.now();
    switch (state) {
      case ConnectionState.connected:
        _events.add(ConnectionConnected(eventId: id, timestamp: ts));
        break;
      case ConnectionState.disconnected:
        _events.add(ConnectionDisconnected(
          eventId: id,
          timestamp: ts,
          reason: 'transport disconnected',
        ));
        break;
      case ConnectionState.failed:
        _events.add(ConnectionFailed(
          eventId: id,
          timestamp: ts,
          error: 'transport failed',
        ));
        break;
      case ConnectionState.connecting:
        break;
    }
  }

  void _onRawMessage(String rawJson) {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(rawJson) as Map<String, dynamic>;
    } catch (e, s) {
      logError('Failed to decode message', e, s);
      return;
    }

    final event = EventParser.parse(json);

    if (event is SessionCreated) _sessionId = event.sessionId;
    _events.add(event);
  }

  void _wireAutoMute() {
    _autoMuteSub?.cancel();
    bool userMuted = false;
    _autoMuteSub = _events.listen((event) async {
      if (event is OutputAudioBufferStarted) {
        userMuted = _isMuted.value;
        if (!userMuted) await _transport.setMicEnabled(false);
      } else if (event is OutputAudioBufferStopped ||
          event is OutputAudioBufferCleared) {
        if (!userMuted) await _transport.setMicEnabled(true);
      }
    });
  }
}
