# Changelog

## [0.0.1] - 2026-04-30

Initial public release. Targets the OpenAI Realtime GA API.

- WebRTC transport (low-latency voice) and WebSocket transport
  (server-side and text-only) behind a single `RealtimeClient`.
- Ephemeral-token auth via `EphemeralTokenProvider` and
  `CachingEphemeralTokenProvider`. `OpenAIClientSecretMinter` ships
  for server-side Dart backends; **do not** use it from a Flutter
  app shipped to users.
- Typed event hierarchy: `session.*`, `conversation.*`, `response.*`,
  `input_audio_buffer.*`, `output_audio_buffer.*`,
  `rate_limits.updated`, `error`, plus locally-synthesised
  `ConnectionConnected` / `ConnectionDisconnected` / `ConnectionFailed`
  lifecycle events. Forward-compatible `UnknownRealtimeEvent` keeps
  unrecognised types visible.
- Typed `RealtimeUsage` parsing for `response.done`. Pre-GA
  `response.text.*` / `response.audio.*` aliases recognised alongside
  GA names.
- WebRTC barge-in support: `cancelResponse`, `clearOutputAudioBuffer`,
  `truncateConversation`.
- `MuteStrategy.standard` / `aggressive` / `auto` for handling
  assistant echo on platforms with imperfect AEC. `ConnectionState`
  and `isMuted` exposed as `ValueListenable` for
  `ValueListenableBuilder`.
- `RealtimeClient.callId` exposes the WebRTC `Location` header for
  log correlation with OpenAI billing.
- Example app scaffolded for Android, iOS, and macOS with the
  required mic + network entitlements.
- GitHub Actions CI (analyze + test on Ubuntu and macOS).
- Dartdoc on the public API.
