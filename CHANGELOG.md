# Changelog

The 0.1.x and 0.2.x history was internal/private; 0.3.0 is the first public release on pub.dev.

## [Unreleased]

### Breaking

- Raise SDK floor to Dart `>=3.8.0` and Flutter `>=3.32.0`. Required by
  the new `flutter_lints ^6.0.0` dev dependency.
- Bump `web_socket_channel` to `^3.0.0` (major version). Consumers
  pinned to v2 may need to migrate.

### Added

- macOS scaffolding in `example/` with the microphone usage description
  and the `audio-input` / `network.client` / `network.server`
  entitlements wired up in both Debug and Release.
- GitHub Actions CI workflow (`analyze` + `test` on Ubuntu and macOS).
- Unit tests for `RealtimeClient` lifecycle, event dispatch, and
  dispose semantics via a fake transport.

### Fixed

- WebRTC SDP exchange uses `package:http` instead of `dart:io.HttpClient`
  so Flutter Web can compile the package.

### Changed

- Bump dev dependency `flutter_lints` to `^6.0.0` and runtime dependency
  `rxdart` to `^0.28.0`.

### Docs

- Dartdoc on the public API: every concrete event class, `RealtimeClient`
  members (with a class-level usage example), `ConversationItem` enums,
  `ContentPart`, `Tool`, `EphemeralTokenException`, and `RealtimeLogging`.
- README polish for pub.dev: install command, badges, accurate
  `minSdkVersion`, complete macOS entitlements, Web caller-side audio
  wiring, WebSocket transport quickstart, link to dartdoc.

## [0.3.0] - 2026-04-29

Targets the OpenAI Realtime GA API. Breaks every name from 0.2.x.

- Switch SDP exchange to `POST /v1/realtime/calls`. Drop deprecated
  `?model=` query parameter and the `OpenAI-Beta: realtime=v1` header.
- Switch ephemeral key minting to `POST /v1/realtime/client_secrets`
  with the GA flat response shape (`{value, expires_at, session}`) and
  `ek_…` token prefix.
- Send `session.update` and `client_secrets` body using the GA
  discriminated `audio.{input,output}` schema. Use `output_modalities`
  and `max_output_tokens`.
- Fix `Tool.toJson` to include the required `'type': 'function'`
  discriminator. Replace `ToolChoice` enum with a sealed type that
  supports `auto` / `none` / `required` / `function(name)`.
- Voice enum now lists the 10 voices the Realtime server actually
  accepts. The TTS-only voices (`fable`, `nova`, `onyx`) have been
  removed; `sage`, `marin`, and `cedar` added.
- Model enum is GA-only: `gpt-realtime`, `gpt-realtime-mini`,
  `gpt-realtime-2025-08-28`. The `gpt-4o-realtime-preview-*` snapshots
  have been removed.
- Add `clearOutputAudioBuffer` for WebRTC barge-in. Document the full
  three-step interruption sequence (`cancelResponse`,
  `clearOutputAudioBuffer`, `truncateConversation`).
- Auto-mute on Android while the assistant is speaking when
  `MuteStrategy.aggressive` (or `auto` resolving to it) is set.
- Capture WebRTC `Location` header into `RealtimeClient.callId` for
  log correlation with OpenAI billing.
- Replace `RealtimeApiClient` + `RealtimeApiClientFactory` +
  `RealtimeSession` with a single `RealtimeClient` class with
  `.webRtc(...)` / `.webSocket(...)` named constructors. Move
  ephemeral-token fetch into `connect()`.
- Drop `RealtimeAudioProcessor`, `VoiceActivityDetector`, and the
  `AudioFormatConverter` — none were exercised on the WebRTC happy
  path.
- Trim the public barrel from 16 exports to 13 modules of stable
  public API. Make protocol constants and the event parser private.
- Expose `connectionState` and `isMuted` as `ValueListenable` for
  Flutter's `ValueListenableBuilder`.
- Add typed `RealtimeUsage` parsing for `response.done`. Add
  `UnknownRealtimeEvent` so unrecognised event types surface instead
  of being silently dropped. Handle pre-GA `response.text.*` and
  `response.audio.*` aliases alongside the GA names.
