# 17 — WASM compatibility for the Web build

## Problem

Pana awards +5 points for WASM-compatible Web support. The package
currently advertises `web:` in its platforms list (and the WebRTC SDP
exchange compiles on Web after task #02), but the WebSocket transport
still pulls `dart:io` via `package:web_socket_channel/io.dart`:

```dart
// lib/src/connection/websocket_connection.dart
import 'dart:io';
import 'package:web_socket_channel/io.dart';
```

`dart:io` is unavailable in WASM Web builds and in the JavaScript Web
build under strict mode. As long as that import sits on the Web
compile path, pana flags the package as non-WASM-compatible.

## Approach

Replace the unconditional `dart:io` / `IOWebSocketChannel` usage with a
conditional import that picks an `IOWebSocketChannel` on the VM and an
`HtmlWebSocketChannel` (from `package:web_socket_channel/html.dart`)
on the Web. The `web_socket_channel` package already ships both
implementations.

Sketch:

```dart
// lib/src/connection/websocket_connection.dart
import 'package:web_socket_channel/web_socket_channel.dart';
import 'ws_factory_io.dart'
    if (dart.library.html) 'ws_factory_html.dart' as ws_factory;

WebSocketChannel _open(Uri url, {required Map<String, String> headers}) =>
    ws_factory.connect(url, headers: headers);
```

```dart
// lib/src/connection/ws_factory_io.dart
import 'dart:io';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel connect(Uri url, {required Map<String, String> headers}) =>
    IOWebSocketChannel.connect(url, headers: headers);
```

```dart
// lib/src/connection/ws_factory_html.dart
import 'package:web_socket_channel/html.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel connect(Uri url, {required Map<String, String> headers}) {
  // Browsers do not allow setting arbitrary HTTP headers on a WebSocket
  // handshake. The Authorization bearer must be carried via a
  // subprotocol or a server-side proxy. See: …
  return HtmlWebSocketChannel.connect(url);
}
```

The `headers` parameter on the Web side is the awkward bit — the
browser API does not let callers set them. For the OpenAI Realtime
WebSocket endpoint that means either (a) routing through a server-side
proxy that adds the `Authorization` header, or (b) using the
subprotocol form (`Sec-WebSocket-Protocol`) the OpenAI server accepts.
Whichever path is chosen, document it in the README.

## Files

- `lib/src/connection/websocket_connection.dart` (replace `dart:io`
  import with conditional import; thin out the `IOWebSocketChannel`
  references)
- `lib/src/connection/ws_factory_io.dart` (new)
- `lib/src/connection/ws_factory_html.dart` (new)
- `README.md` (Web WebSocket section: explain the header limitation
  and the subprotocol / proxy workaround)

## Verification

- `dart pub global run pana .` reports WASM-compatible Web support;
  platform score rises from 15/20 (with task #16) → 20/20.
- `flutter build web --wasm` from `example/` succeeds.
- `flutter test` still passes (transport tests run on the VM, so the
  io.dart path is exercised; pure-Web tests would be a follow-up).
- Manual smoke: a Web build of the example connects to the Realtime
  WebSocket endpoint via the documented header workaround.

## Risk

Medium. The conditional-import refactor is mechanical, but the
header-limitation workaround is a real product decision: browsers
genuinely cannot send `Authorization: Bearer …` on a WebSocket
upgrade, and the resolution shapes how Web users authenticate.
Document the constraint and the chosen workaround clearly so users
don't get bitten.

## Out of scope

- Web-specific examples in `example/web/`.
- Audio capture on Web (the Realtime API's WebSocket transport is
  text-only; audio on Web should go via WebRTC).
