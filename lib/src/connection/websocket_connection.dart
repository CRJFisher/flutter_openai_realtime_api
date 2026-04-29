import 'dart:async';
import 'dart:io';

import 'package:rxdart/rxdart.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../internal/logger.dart';
import '../internal/protocol.dart';
import '../models/config.dart';
import 'realtime_transport.dart';

/// WebSocket transport for the Realtime API.
///
/// Best suited to server-side Dart (Cloud Functions, Shelf) where you have
/// the long-lived API key. From a Flutter client, prefer the WebRTC
/// transport: browsers cannot set the `Authorization` header on a WebSocket
/// upgrade, so client-side WebSocket use requires the OpenAI-specific
/// subprotocol auth hack which is not robust.
class RealtimeWebSocketTransport
    with LoggerMixin
    implements RealtimeTransport {
  final RealtimeConfig _config;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  ConnectionState _state = ConnectionState.disconnected;
  final _messages = BehaviorSubject<String>();
  final _stateCtrl = BehaviorSubject<ConnectionState>();
  bool _disposed = false;

  RealtimeWebSocketTransport(this._config) {
    _stateCtrl.add(_state);
  }

  @override
  Stream<String> get onMessage => _messages.stream;

  @override
  Stream<ConnectionState> get onState => _stateCtrl.stream;

  @override
  ConnectionState get state => _state;

  @override
  String? get callId => null;

  @override
  Future<void> connect() async {
    if (_state == ConnectionState.connected) return;
    if (_disposed) {
      throw StateError('RealtimeWebSocketTransport has been disposed');
    }
    _setState(ConnectionState.connecting);

    try {
      final bearer = await _config.resolveBearerToken();
      final base = _config
          .effectiveBaseUrl
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://');
      final uri = Uri.parse(
        '$base${Protocol.webSocketPath}?model=${_config.model.id}',
      );

      // dart:io WebSockets accept arbitrary headers — that includes
      // `Authorization`. This path is exercised on iOS, Android, macOS,
      // Windows, Linux, and the Dart VM (server-side). Flutter Web uses
      // a different WebSocket implementation that cannot set custom
      // headers; that path is intentionally unsupported.
      // ignore: close_sinks — wrapped in _channel below; closed in disconnect()
      final socket = await WebSocket.connect(
        uri.toString(),
        headers: {'Authorization': 'Bearer $bearer'},
      );

      _channel = IOWebSocketChannel(socket);
      _sub = _channel!.stream.listen(
        (data) => _messages.add(data as String),
        onError: (Object e, StackTrace s) {
          logError('WebSocket error', e, s);
          _setState(ConnectionState.failed);
        },
        onDone: () {
          _setState(ConnectionState.disconnected);
        },
        cancelOnError: false,
      );

      _setState(ConnectionState.connected);
    } catch (e, s) {
      logError('WebSocket connect failed', e, s);
      _setState(ConnectionState.failed);
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    await _sub?.cancel();
    _sub = null;
    await _channel?.sink.close();
    _channel = null;
    _setState(ConnectionState.disconnected);
  }

  @override
  Future<void> sendMessage(String rawJson) async {
    final ch = _channel;
    if (ch == null || _state != ConnectionState.connected) {
      throw StateError('Not connected');
    }
    ch.sink.add(rawJson);
  }

  @override
  Future<void> setMicEnabled(bool enabled) async {
    // No-op: WebSocket transport does not own the mic. Callers control
    // input by appending or not appending audio bytes.
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await disconnect();
    await _messages.close();
    await _stateCtrl.close();
  }

  void _setState(ConnectionState newState) {
    if (_state == newState || _disposed) return;
    _state = newState;
    if (!_stateCtrl.isClosed) _stateCtrl.add(newState);
  }
}
