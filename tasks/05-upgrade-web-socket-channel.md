# 05 — Upgrade web_socket_channel ^2.4.0 → ^3.0.0

## Problem

`pubspec.yaml:18` pins `web_socket_channel: ^2.4.0`. Latest is `3.0.3`. Pana docks dependency points for being a major version behind, and v2 is heading toward unmaintained.

## Breaking changes in v3

The v3 release reorganized imports. `package:web_socket_channel/io.dart` (the `IOWebSocketChannel` entry point used in `lib/src/connection/websocket_connection.dart:3`) has moved or its API has shifted. Confirm the exact change against the `web_socket_channel` v3 changelog before upgrading.

Other surface area to verify:

- `WebSocketChannel.connect` signature
- Any subscription/closing semantics

## Approach

1. Bump `pubspec.yaml:18` to `web_socket_channel: ^3.0.0`.
2. Run `flutter pub get` and read the migration warnings.
3. Update `lib/src/connection/websocket_connection.dart` per the v3 API.
4. Run `flutter test` — `test/event_parser_test.dart` and friends should still pass since they don't exercise the live transport.

## Files likely to change

- `pubspec.yaml`
- `lib/src/connection/websocket_connection.dart`

## Verification

- `flutter pub get` resolves cleanly
- `dart analyze` clean
- `flutter test` passes
- `dart pub publish --dry-run` shows no new warnings

## Risk

Medium. Real transport behavior isn't covered by unit tests (see task #12), so a subtle behavioral regression in WebSocket connect/close could slip through. Manual smoke against the live OpenAI Realtime endpoint via the example app is the only way to fully validate.
