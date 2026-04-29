# 12 — Unit tests for RealtimeClient via fake transport

## Problem

`RealtimeClient` is the public entry point of the library and has zero direct test coverage. Existing tests at `test/` cover config serialization, ephemeral token fetching, and event parsing — but not the client lifecycle, event dispatch, or dispose semantics.

This is the highest-risk gap in the library: a behavioral regression in `connect()` or event routing wouldn't be caught.

## Approach

Add `test/realtime_client_test.dart`. Use a hand-rolled fake implementing the transport interface — no mocking package needed. The fake exposes a method to push raw JSON events into the client and assertions on outbound messages.

### Test cases

1. **Connect lifecycle** — `client.connect()` transitions `connectionState` from `disconnected` → `connecting` → `connected` and emits the corresponding `ConnectionEvent`s in order.
2. **Event dispatch from raw JSON** — feed a synthetic `session.created` JSON through the fake transport; assert `sessionId` is populated and the typed event surfaces on the public stream.
3. **Unknown event types** — feed an event with a `type` not in the model; assert it surfaces as `UnknownRealtimeEvent` rather than throwing.
4. **Send message round-trip** — `sendUserMessage("hi")` should produce a well-formed `conversation.item.create` payload on the fake's outbound channel.
5. **Mute toggle** — `client.mute(true)` updates `isMuted`. (No-op for WebSocket transport; for WebRTC the audio track enabled flag flips. Test the public observable.)
6. **Dispose closes subscriptions** — `client.dispose()` causes the public event stream to emit done, and subsequent calls are no-ops (or throw, depending on the chosen contract — pin this in the test).

### Fake transport sketch

```dart
class FakeTransport implements RealtimeTransport {
  final _incoming = StreamController<String>.broadcast();
  final outbound = <String>[];

  @override
  Stream<String> get events => _incoming.stream;

  @override
  Future<void> send(String json) async => outbound.add(json);

  @override
  Future<void> connect() async { /* immediate success */ }

  @override
  Future<void> close() async => _incoming.close();

  void pushIncoming(Map<String, dynamic> event) =>
      _incoming.add(jsonEncode(event));
}
```

The exact interface depends on what `RealtimeClient` actually depends on — read `lib/src/client/realtime_client.dart` and the connection classes to find the seam. If there's no clean transport interface today, extracting one is itself worth doing (small refactor, but it pays off here and for future Pusher/SSE transports).

## Files

- New: `test/realtime_client_test.dart`
- Possibly: `lib/src/connection/realtime_transport.dart` if a transport interface needs to be extracted (small refactor)

## Verification

- `flutter test` passes with the new file
- Coverage of `lib/src/client/realtime_client.dart` rises substantially (no hard target — the goal is the lifecycle + event paths, not 100%)

## Risk

Low. Test-only addition. If a transport interface needs extracting, that's a localized refactor with no behavioral change.
