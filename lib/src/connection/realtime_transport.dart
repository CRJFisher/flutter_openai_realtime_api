/// Connection state of the underlying transport.
///
/// This is what callers see via `RealtimeClient.connectionState`. It does
/// not distinguish protocol-level state (e.g. session.created received) —
/// for that, listen to `RealtimeClient.events`.
enum ConnectionState {
  disconnected,
  connecting,
  connected,
  failed,
}

/// Internal: minimal transport contract used by [RealtimeClient].
///
/// Both [RealtimeWebSocketTransport] and [RealtimeWebRtcTransport] implement
/// this interface as a "dumb pipe" for raw JSON events. The client/session
/// logic lives one layer above.
abstract class RealtimeTransport {
  Stream<String> get onMessage;
  Stream<ConnectionState> get onState;
  ConnectionState get state;

  /// Optional opaque correlation id assigned by the server when the
  /// connection was established (e.g. WebRTC `rtc_…` from the
  /// `Location` header). Useful for cross-referencing client logs with
  /// OpenAI billing / support.
  String? get callId;

  Future<void> connect();
  Future<void> disconnect();
  Future<void> sendMessage(String rawJson);

  /// Forwards the configured `MuteStrategy`. For WebSocket transport,
  /// this is a no-op.
  Future<void> setMicEnabled(bool enabled);

  Future<void> dispose();
}
