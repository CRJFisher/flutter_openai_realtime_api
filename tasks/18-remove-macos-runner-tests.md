# 18 — Remove the macOS RunnerTests placeholder

## Problem

`flutter create --platforms=macos` (task #14) generated
`example/macos/RunnerTests/RunnerTests.swift`, a stock placeholder with
one empty `testExample()` function and no assertions. The file is wired
into `example/macos/Runner.xcodeproj/project.pbxproj` as the test
target `331C80D4294CF70F00263BE5`.

Per YAGNI, dead code should be deleted, not left to rot. The
placeholder either needs to be filled with a real macOS-side test or
removed (along with its pbxproj references).

There is no precedent for native-side macOS tests in this repo — the
Flutter side is exercised by Dart unit tests. So removal is the
appropriate move.

## Approach

This is more delicate than a normal file deletion because the test
target is wired into the Xcode project. Three things must be edited:

1. Delete the directory:
   ```bash
   rm -rf example/macos/RunnerTests
   ```

2. Remove from `example/macos/Runner.xcodeproj/project.pbxproj`:
   - The `RunnerTests` `PBXGroup`, `PBXFileReference` for
     `RunnerTests.swift`, `Info.plist` (if present), and the
     `PBXNativeTarget` (`331C80D4294CF70F00263BE5`).
   - The `PBXTargetDependency` linking the test target to the main
     `Runner` target.
   - The `XCConfigurationList` and `XCBuildConfiguration` entries for
     the test target.
   - The test target reference under `PBXProject`'s `targets` array.

3. Verify `example/macos/Runner.xcworkspace/contents.xcworkspacedata`
   still references the project correctly (it shouldn't need editing,
   but worth a check).

The pbxproj edits are mechanical but easy to get wrong. The safest
path is `xcodeproj` (Ruby gem) or, more pragmatically, opening
`Runner.xcodeproj` in Xcode, deleting the `RunnerTests` group from the
sidebar (selecting "Move to Trash"), and committing the resulting
diff. Xcode handles all the pbxproj surgery.

## Files

- Delete: `example/macos/RunnerTests/` (directory)
- Edit: `example/macos/Runner.xcodeproj/project.pbxproj`

## Verification

- `flutter run -d macos` from `example/` still launches and connects.
- `flutter build macos --release` from `example/` succeeds.
- `xcodebuild -workspace example/macos/Runner.xcworkspace -list`
  shows only the `Runner` target, not `RunnerTests`.

## Risk

Low. The placeholder isn't exercised by any CI step or `flutter test`
invocation, so removing it cannot regress test coverage. The only
risk is corrupting the pbxproj — mitigated by editing through Xcode.

## Out of scope

- Adding genuine native macOS tests. The Realtime client is Dart-only;
  any platform-side behaviour worth testing belongs in
  `flutter_webrtc`'s test suite, not this package's example.
