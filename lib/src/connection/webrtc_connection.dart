import 'dart:async';
import 'dart:convert';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:rxdart/rxdart.dart';

import '../internal/logger.dart';
import '../internal/protocol.dart';
import '../models/config.dart';
import 'realtime_transport.dart';

/// WebRTC transport for the Realtime API.
///
/// Authenticates with an ephemeral key (`ek_…`), creates an offer with
/// audio + a single data channel for events, and exchanges SDP via
/// `POST https://api.openai.com/v1/realtime/calls`. The data channel
/// carries the same JSON event protocol as the WebSocket transport.
class RealtimeWebRtcTransport with LoggerMixin implements RealtimeTransport {
  final RealtimeConfig _config;

  RTCPeerConnection? _pc;
  RTCDataChannel? _dc;
  MediaStream? _localStream;
  MediaStreamTrack? _localAudioTrack;
  RTCRtpSender? _audioSender;

  ConnectionState _state = ConnectionState.disconnected;
  final _messages = BehaviorSubject<String>();
  final _stateCtrl = BehaviorSubject<ConnectionState>();
  Completer<void>? _dataChannelOpen;

  String? _callId;
  bool _disposed = false;

  RealtimeWebRtcTransport(this._config) {
    _stateCtrl.add(_state);
  }

  @override
  Stream<String> get onMessage => _messages.stream;

  @override
  Stream<ConnectionState> get onState => _stateCtrl.stream;

  @override
  ConnectionState get state => _state;

  @override
  String? get callId => _callId;

  @override
  Future<void> connect() async {
    if (_state == ConnectionState.connected) return;
    if (_disposed) {
      throw StateError('RealtimeWebRtcTransport has been disposed');
    }

    _setState(ConnectionState.connecting);
    try {
      _dataChannelOpen = Completer<void>();

      await _createPeerConnection();
      await _setupLocalStream();
      _createDataChannel();

      final offer = await _pc!.createOffer();
      await _pc!.setLocalDescription(offer);

      // Wait briefly for ICE gathering to settle so the SDP we POST has
      // host candidates. flutter_webrtc emits candidates synchronously on
      // most platforms, so this is usually a microtask hop.
      await _waitForIceGathering();

      final localDesc = await _pc!.getLocalDescription();
      final answer = await _exchangeSdp(localDesc?.sdp ?? offer.sdp ?? '');
      await _pc!.setRemoteDescription(
        RTCSessionDescription(answer, 'answer'),
      );

      // Connection isn't usable until the data channel opens.
      await _dataChannelOpen!.future.timeout(const Duration(seconds: 10),
          onTimeout: () {
        throw TimeoutException(
          'Realtime data channel did not open within 10 s',
        );
      });

      _setState(ConnectionState.connected);
      logInfo('WebRTC connected (callId: $_callId)');
    } catch (e, st) {
      logError('WebRTC connect failed', e, st);
      _setState(ConnectionState.failed);
      await _teardown();
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    if (_state == ConnectionState.disconnected) return;
    await _teardown();
    _setState(ConnectionState.disconnected);
  }

  @override
  Future<void> sendMessage(String rawJson) async {
    final dc = _dc;
    if (dc == null || dc.state != RTCDataChannelState.RTCDataChannelOpen) {
      throw StateError('Data channel not open');
    }
    await dc.send(RTCDataChannelMessage(rawJson));
  }

  @override
  Future<void> setMicEnabled(bool enabled) async {
    final track = _localAudioTrack;
    final sender = _audioSender;
    if (track == null) return;

    final strategy = _config.muteStrategy;

    if (!enabled && strategy.replaceTrack && sender != null) {
      // Aggressive: stop RTP entirely.
      try {
        await sender.replaceTrack(null);
      } catch (e) {
        logError('replaceTrack(null) failed; falling back to enabled=false', e);
        track.enabled = false;
      }
    } else if (enabled && strategy.replaceTrack && sender != null) {
      if (track.enabled == false) track.enabled = true;
      try {
        await sender.replaceTrack(track);
      } catch (e) {
        logError('replaceTrack(track) failed; falling back to enabled=true', e);
        track.enabled = true;
      }
    } else {
      // Standard: flip enabled flag.
      track.enabled = enabled;
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _teardown();
    await _messages.close();
    await _stateCtrl.close();
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Future<void> _createPeerConnection() async {
    _pc = await createPeerConnection({
      'iceServers': _config.iceServers ??
          [
            {'urls': 'stun:stun.l.google.com:19302'},
          ],
      'sdpSemantics': 'unified-plan',
    });

    _pc!.onIceConnectionState = (state) {
      logInfo('ICE state: ${state.name}');
      // Translate sustained failure only — `disconnected` is recoverable.
      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        _setState(ConnectionState.failed);
      }
    };
    _pc!.onConnectionState = (state) {
      logInfo('Peer connection state: ${state.name}');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _setState(ConnectionState.failed);
      }
    };
    _pc!.onTrack = (event) {
      if (event.track.kind == 'audio') {
        // The remote audio track is wired automatically through
        // flutter_webrtc's native side; on Web, callers must attach the
        // remote stream to an audio element themselves (see README).
        logInfo('Remote audio track received');
      }
    };
  }

  Future<void> _setupLocalStream() async {
    final constraints = <String, dynamic>{
      'audio': {
        'echoCancellation': _config.enableEchoCancellation,
        'noiseSuppression': _config.enableNoiseSuppression,
        'autoGainControl': _config.enableAutoGainControl,
        // Channel count is the only constraint that matters here. Sample
        // rate is forced to 48 kHz by the Opus encoder regardless of any
        // value we pass.
        'channelCount': 1,
      },
      'video': false,
    };

    _localStream = await navigator.mediaDevices.getUserMedia(constraints);

    final tracks = _localStream!.getAudioTracks();
    if (tracks.isEmpty) {
      throw StateError('getUserMedia returned no audio track');
    }
    _localAudioTrack = tracks.first;
    _audioSender = await _pc!.addTrack(_localAudioTrack!, _localStream!);
  }

  void _createDataChannel() {
    final init = RTCDataChannelInit()..ordered = true;
    _pc!.createDataChannel(Protocol.dataChannelLabel, init).then((dc) {
      _dc = dc;
      dc.onDataChannelState = (state) {
        if (state == RTCDataChannelState.RTCDataChannelOpen &&
            !_dataChannelOpen!.isCompleted) {
          _dataChannelOpen!.complete();
        }
      };
      dc.onMessage = (msg) {
        // The server always sends JSON text; tolerate binary frames just
        // in case some older Chrome stack delivers them as Uint8List.
        try {
          final json = msg.isBinary ? utf8.decode(msg.binary) : msg.text;
          _messages.add(json);
        } catch (e, st) {
          _messages.addError(e, st);
        }
      };
    });
  }

  Future<void> _waitForIceGathering() async {
    final pc = _pc!;
    if (pc.iceGatheringState ==
        RTCIceGatheringState.RTCIceGatheringStateComplete) {
      return;
    }
    final completer = Completer<void>();
    void Function(RTCIceGatheringState)? prev;
    prev = pc.onIceGatheringState;
    pc.onIceGatheringState = (state) {
      prev?.call(state);
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete &&
          !completer.isCompleted) {
        completer.complete();
      }
    };
    await completer.future.timeout(
      const Duration(milliseconds: 500),
      onTimeout: () {/* proceed with whatever candidates we have */},
    );
  }

  Future<String> _exchangeSdp(String offerSdp) async {
    final bearer = await _config.resolveBearerToken();
    final url = Uri.parse('${_config.effectiveBaseUrl}${Protocol.callsPath}');

    final resp = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $bearer',
        'Content-Type': 'application/sdp',
      },
      body: offerSdp,
    );

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      final location = resp.headers['location'];
      if (location != null) {
        final segments = location.split('/');
        _callId = segments.isNotEmpty ? segments.last : null;
      }
      return resp.body;
    }

    throw StateError(
      'SDP exchange failed: ${resp.statusCode} ${resp.reasonPhrase} — ${resp.body}',
    );
  }

  Future<void> _teardown() async {
    final dc = _dc;
    final pc = _pc;
    final stream = _localStream;

    _dc = null;
    _pc = null;
    _localStream = null;
    _localAudioTrack = null;
    _audioSender = null;
    _callId = null;

    final completer = _dataChannelOpen;
    if (completer != null && !completer.isCompleted) {
      completer.completeError(
        StateError('connection torn down before open'),
      );
    }
    _dataChannelOpen = null;

    try {
      await dc?.close();
    } catch (_) {}
    if (stream != null) {
      for (final t in stream.getTracks()) {
        try {
          await t.stop();
        } catch (_) {}
      }
      try {
        await stream.dispose();
      } catch (_) {}
    }
    try {
      await pc?.close();
    } catch (_) {}
  }

  void _setState(ConnectionState newState) {
    if (_state == newState || _disposed) return;
    _state = newState;
    if (!_stateCtrl.isClosed) _stateCtrl.add(newState);
  }
}
