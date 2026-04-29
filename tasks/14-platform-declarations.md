# 14 — Align pubspec platform declarations with example scaffolding

## Problem

`pubspec.yaml` declares `android`, `ios`, `web`, `macos`. But:

- `example/` has scaffolding for `android/` and `ios/` only. No `example/macos/` exists, so macOS support is undemonstrated and untestable from the example app.
- `example/web/` is also absent (Web support is broken anyway until task #02 lands).

A user who follows the README's macOS setup steps has no working reference app to crib from.

Separately, the SDK floor at `pubspec.yaml:9` is `>=3.1.0` (mid-2023). For a fresh package with no legacy callers, raising the floor costs nothing and lets the codebase use Dart 3.3+ features (extension types, etc.).

## Decision

**Scaffold macOS into the example** rather than dropping macOS from `pubspec.yaml`. Reasoning: macOS is the largest desktop Flutter audience and `flutter_webrtc` supports it well. A user enabling macOS needs working entitlements + Info.plist as a reference; the README snippet alone is error-prone.

**Web example** is deferred until task #02 lands — no point scaffolding `example/web/` against a broken compile.

**SDK floor** raise to `>=3.3.0`.

## Approach

```bash
cd example
flutter create --platforms=macos .
```

Then configure:

- `example/macos/Runner/Info.plist` — `NSMicrophoneUsageDescription`
- `example/macos/Runner/DebugProfile.entitlements` and `Release.entitlements` — add `com.apple.security.device.audio-input` and `com.apple.security.network.client`

Verify with `flutter run -d macos` from `example/`.

For the SDK bump:

- `pubspec.yaml:9` → `sdk: '>=3.3.0 <4.0.0'`
- `flutter` constraint stays at `>=3.13.0` (released alongside Dart 3.1)... actually Flutter 3.19 ships Dart 3.3, so bump `flutter: ">=3.19.0"` to match.

## Files

- New: `example/macos/` (generated)
- `example/macos/Runner/Info.plist`
- `example/macos/Runner/DebugProfile.entitlements`
- `example/macos/Runner/Release.entitlements`
- `pubspec.yaml` (SDK + Flutter constraints)

## Verification

- `flutter run -d macos` from `example/` connects successfully and captures microphone audio
- `dart pub publish --dry-run` shows no platform-mismatch warnings
- pana platform score still 10/20 (the +10 for desktop is gated on Windows/Linux, see task #16, not on macOS)

## Risk

Low. Adding the macOS scaffold doesn't affect existing platforms. SDK floor raise could break consumers on older Dart, but this is a fresh package — no consumers to break.
