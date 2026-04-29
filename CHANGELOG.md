# Changelog

The 0.1.x and 0.2.x history was internal/private; 0.3.0 is the first public release on pub.dev.

## [Unreleased]

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
