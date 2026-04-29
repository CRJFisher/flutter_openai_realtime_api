# 06 — Bump flutter_lints to ^6.0.0 and rxdart to ^0.28.0

## Problem

- `pubspec.yaml:25` — `flutter_lints: ^3.0.0` is three majors behind (`6.0.0` available). Each major adds stricter rules.
- `pubspec.yaml:19` — `rxdart: ^0.27.7` is one major behind (`0.28.0` available).

Pana docks 5 points per outdated direct dependency.

## Approach

1. Bump `flutter_lints` to `^6.0.0`. Run `flutter analyze` — expect new lint failures (stricter `prefer_const_*`, `use_super_parameters`, `unused_element_parameter`, etc.). Fix each at the source rather than suppressing.
2. Bump `rxdart` to `^0.28.0`. Confirm `BehaviorSubject`, `ValueStream`, and any other rxdart usages still compile. v0.28 dropped some legacy operators — check the changelog.
3. If `flutter_lints 6` introduces a lot of warnings, audit `analysis_options.yaml` to see whether any rules should be disabled (rare — usually the right move is to fix the code).

## Files likely to change

- `pubspec.yaml` (both bumps)
- Multiple `lib/` files for lint fixups
- Possibly `analysis_options.yaml` if a specific rule is wrong for this codebase

## Verification

- `dart analyze` clean
- `flutter test` passes
- No new `// ignore:` comments added (that would defeat the point)

## Risk

Low for `flutter_lints` (failures are mechanical to fix). Medium for `rxdart` if 0.28 dropped an operator the codebase uses.
