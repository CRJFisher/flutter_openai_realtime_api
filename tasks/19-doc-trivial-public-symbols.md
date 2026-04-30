# 19 — Doc remaining trivial public symbols

## Problem

Task #08 documented the structurally important parts of the public
API (event classes, RealtimeClient, the user-facing enums). A
post-hoc audit flagged a long tail of *trivial* public symbols still
without `///`:

- `Tool.toJson` (`lib/src/models/tool.dart`)
- `ConversationItem.toJson`, `ConversationItem.fromJson`
  (`lib/src/models/conversation_item.dart`)
- `ContentPart.fromJson` (`lib/src/models/conversation_item.dart`)
- `ContentPart` default constructor (same file)
- `ConversationItemStatus.fromId`, `ConversationRole.fromId`,
  `ContentType.fromId` static methods
- ~44 generative constructors across `lib/src/models/events.dart`
  (one per concrete event class — they all just forward `eventId`,
  `timestamp`, and the class's own fields).

These were intentionally left undocumented under YAGNI: their names
already convey their behaviour, and adding boilerplate one-liners
violates the "default to writing no comments" rule.

## Decision required before this task can land

Pick one of:

**A. Honour YAGNI, close this task without changes.** Pana already
awards full points for dartdoc coverage at >20%; the package sits at
~68%. Adding more docs costs effort and clutter without moving the
score or the user-facing API understanding.

**B. Document anyway for pub.dev surface polish.** Each undocumented
symbol shows up on pub.dev's per-type pages with a "no documentation"
note. For a package marketing itself as production-ready, this can
read as half-finished. Adding one-line docs is cheap.

The recommendation is **A**: the API is well-documented at the level
that matters. If `B` is chosen, follow the approach below.

## Approach (option B only)

For each constructor in `events.dart`, add the same one-line summary
the parent class already has — the constructor is just the
class-level summary in imperative form. Example:

```dart
/// Final transcript for a user audio item.
class InputAudioTranscriptionCompleted extends ConversationEvent {
  // …fields…

  /// Construct an [InputAudioTranscriptionCompleted].
  const InputAudioTranscriptionCompleted({…});
}
```

For `toJson` / `fromJson`: `/// Encode as the wire JSON shape.` /
`/// Parse from the wire JSON shape.`

For `fromId`: `/// Look up the value by its wire id; returns null
when unrecognised.`

## Files

- `lib/src/models/events.dart`
- `lib/src/models/conversation_item.dart`
- `lib/src/models/tool.dart`

## Verification

- `dart doc .` produces no new warnings.
- pana coverage rises to ~95%+. (No score change beyond the existing
  full marks.)

## Risk

None. Pure documentation.
