# 02 — Fix Web platform compilation

## Problem

`pubspec.yaml` declares `web` as a supported platform, but `lib/src/connection/webrtc_connection.dart:3` imports `dart:io` unconditionally and `_exchangeSdp()` (lines 263-294) uses `dart:io.HttpClient` for the SDP POST. `dart:io` is unavailable on the Web compile target, so any Flutter Web app that imports the package fails to build.

Comment at `webrtc_connection.dart:185-186` ("on Web, callers must attach the remote stream to an audio element themselves") implies Web is intended to work, so the right fix is to make Web actually work — not to drop the platform.

`lib/src/connection/websocket_connection.dart` is a separate matter: it explicitly opts out of Web (comment at lines 66-70) by using `IOWebSocketChannel`. WebSocket-on-Web is out of scope here; only WebRTC needs fixing.

## Approach

Replace `dart:io.HttpClient` in `_exchangeSdp` with `package:http` (already a declared dependency, used in `lib/src/auth/ephemeral_token.dart`).

Then drop the top-level `import 'dart:io'` from `webrtc_connection.dart` if nothing else in the file needs it. Audit the remaining usages — if any other `dart:io` symbol is referenced, that needs handling too (the only file-level use case is the HTTPS SDP exchange, but verify).

## Files

- `lib/src/connection/webrtc_connection.dart` — rewrite `_exchangeSdp` using `package:http`'s `http.post`, remove `dart:io` import if possible.

## Verification

- `dart analyze` clean
- `flutter test` still passes
- Add a quick manual smoke: `flutter build web` from `example/` should succeed once `dart:io` is purged from the import graph.

## Risk

Low. `package:http` and `dart:io.HttpClient` have equivalent capabilities for a single HTTPS POST with custom headers and string body. No behavioral change expected.
