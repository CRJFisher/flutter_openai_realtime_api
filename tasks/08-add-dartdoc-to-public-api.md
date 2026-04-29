# 08 — Add dartdoc /// comments to public API

## Problem

Current dartdoc coverage is ~27.9% of public members (passes pana's 20% gate, but barely). The biggest gap is `lib/src/models/events.dart` — ~30 concrete event classes have no `///` at all, dragging coverage down.

This is not a publication blocker (pana already passes) but is a meaningful adoption signal — pub.dev surfaces dartdoc on every type page, and undocumented events make the library feel half-finished.

## Priority order (highest impact first)

| #   | Location                                | Symbols                                                                                                                                                                    |
| --- | --------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | `lib/src/models/events.dart`            | 6 abstract bases (`SessionEvent`, `ConversationEvent`, `ResponseEvent`, `AudioEvent`, `ConnectionEvent`, `ConnectionEvent` subclasses) + ~30 concrete events without `///` |
| 2   | `lib/src/client/realtime_client.dart`   | `connectionState`, `isMuted`, `sessionId` getters (lines 70-73), `createConversationItem()` (line 131)                                                                     |
| 3   | `lib/src/models/conversation_item.dart` | `ConversationItemType` (160), `ConversationItemStatus` (180), `ConversationRole` (197), `ContentType` (266) — including per-enum-value docs                                |
| 4   | `lib/src/auth/ephemeral_token.dart:146` | `EphemeralTokenException`                                                                                                                                                  |
| 5   | `lib/src/models/tool.dart`              | `Tool.name`, `Tool.description`, `Tool.parameters` (lines 6, 8, 9)                                                                                                         |
| 6   | `lib/src/internal/logger.dart`          | `RealtimeLogging.enableConsoleOutput` `level` parameter                                                                                                                    |

## Approach

One sentence per symbol. For events, the pattern is:

```dart
/// Emitted when the server VAD detects speech start.
class InputAudioBufferSpeechStarted extends AudioEvent { ... }
```

For class-level docs on `RealtimeClient`, add an `{@example}` block showing the minimal connect → send → listen flow — pub.dev rewards example presence.

## Files

- `lib/src/models/events.dart`
- `lib/src/client/realtime_client.dart`
- `lib/src/models/conversation_item.dart`
- `lib/src/auth/ephemeral_token.dart`
- `lib/src/models/tool.dart`
- `lib/src/internal/logger.dart`

## Verification

- `dart doc .` produces no warnings (currently 1 warning at events.dart:375 — see task #07)
- Coverage rises to >50% (rough target — there's no hard pana ceiling, but 50% feels professional)

## Risk

None. Pure documentation additions.
