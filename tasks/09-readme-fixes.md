# 09 — README fixes for pub.dev publication

## Problem

The README is structurally sound but has six concrete issues that hurt pub.dev presentation and contain small factual errors.

## Fixes

### 1. Install instruction (README.md:9-12)

Lead with the canonical command, not a raw pubspec snippet:

```bash
flutter pub add flutter_openai_realtime_api
```

Keep the YAML snippet as a secondary fallback below it.

### 2. Badges at top (after H1 title)

Add three:

```markdown
[![pub package](https://img.shields.io/pub/v/flutter_openai_realtime_api.svg)](https://pub.dev/packages/flutter_openai_realtime_api)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![CI](https://github.com/crjfisher/flutter_openai_realtime_api/actions/workflows/ci.yml/badge.svg)](https://github.com/crjfisher/flutter_openai_realtime_api/actions/workflows/ci.yml)
```

(CI badge depends on task #11 landing first.)

### 3. minSdkVersion is wrong (README.md:282)

Says `minSdkVersion 23` with comment `// flutter_webrtc requires 23+`. Actual flutter_webrtc 1.2.0 ships `minSdkVersion 21`. Correct to `21`.

### 4. macOS network entitlement (README.md:303-307)

Snippet is missing `com.apple.security.network.client`, which is required for the outbound HTTPS SDP exchange. Add:

```xml
<key>com.apple.security.network.client</key>
<true/>
```

Also clarify that _both_ `DebugProfile.entitlements` and `Release.entitlements` need the change — a wildcard plist path is misleading.

### 5. Web caller-side audio wiring (README.md:289-292)

Web section omits a critical implementation detail. The code comment at `lib/src/connection/webrtc_connection.dart:185-186` says callers must attach the remote stream to an audio element themselves on Web. Add a paragraph explaining that on Web, the consumer wires the `RTCPeerConnection`'s remote audio track to an `<audio>` element via `flutter_webrtc`'s renderer or JS interop.

### 6. WebSocket transport quickstart (currently absent)

Only WebRTC is shown end-to-end. Add a minimal WebSocket example so readers know the dual-transport story is real:

```dart
final client = RealtimeClient.webSocket(
  apiKey: '<server-side-key>',
  model: 'gpt-realtime',
);
```

Include a one-line explanation of when to choose WebSocket over WebRTC (server-side, text-only, or platforms without WebRTC support).

### 7. Stale "Zyx" reference (example/README.md:17)

"See when you're speaking and when Zyx is responding" — Zyx is a stale internal name. Remove or replace with a generic phrase ("when the assistant is responding").

### 8. Link to dartdoc (currently absent)

Add a one-liner near the top:

> Full API reference: https://pub.dev/documentation/flutter_openai_realtime_api/latest/

## Verification

- README renders cleanly on https://github.com/crjfisher/flutter_openai_realtime_api
- All badges load (after CI is wired)
- All in-page anchors and external links resolve
