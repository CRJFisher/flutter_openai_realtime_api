# 16 — Windows + Linux desktop support

## Problem

`pubspec.yaml platforms:` declares `android`, `ios`, `web`, `macos`. Pana
docks 5 points for missing desktop platforms, and Flutter desktop is no
longer marginal — Windows + Linux are first-class targets.

`flutter_webrtc` itself advertises support for Android, iOS, Windows,
Linux, and macOS in its own `platforms:` block, so the dependency is
not the blocker. The blocker is mechanical: declare the platforms,
ensure the example builds and runs on each, and stage a manual smoke
test against the live Realtime endpoint.

## Approach

1. Add `windows:` and `linux:` to `pubspec.yaml platforms:`.
2. From `example/`, run:
   ```bash
   flutter create --platforms=windows,linux .
   ```
3. Verify each desktop build:
   - Windows: microphone capture path uses Windows Media Foundation;
     no extra entitlement / capability work needed beyond shipping the
     built binary.
   - Linux: PulseAudio / PipeWire are the audio backends; Flutter
     ships those by default. Worth a manual smoke on a Wayland session.
4. Add `windows-latest` (and optionally `ubuntu-latest` already in CI
   for the desktop build path) to `.github/workflows/ci.yml`'s matrix.
   Run `flutter build windows` / `flutter build linux` as a smoke step.
5. Update `README.md`'s "Platform support" section.

## Files

- `pubspec.yaml` (declare windows + linux)
- `example/windows/`, `example/linux/` (generated)
- `example/.metadata` (windows + linux platform entries; preserve
  android/ios/macos as in task #14)
- `.github/workflows/ci.yml` (add a Windows runner)
- `README.md` (platform support section)

## Verification

- `flutter build windows` from `example/` succeeds.
- `flutter build linux` from `example/` succeeds.
- Manual smoke: `flutter run -d windows` and `flutter run -d linux`
  connect to the Realtime endpoint, capture mic, hear assistant
  audio.
- pana platform score moves from 10/20 → 15/20 (the remaining 5 is
  task #17, WASM).

## Risk

Low–medium. The dependency claims support; the actual integration is
unproven on this codebase. Most likely failure modes are around audio
device enumeration on Linux distros without PipeWire, or Windows
sandboxing quirks for code-signed builds (not a concern for the
example app).

## Out of scope

- Code-signing the example binaries.
- Distribution channels (winget, snap, flatpak).
