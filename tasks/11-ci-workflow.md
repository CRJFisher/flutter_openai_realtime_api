# 11 — Add GitHub Actions CI workflow

## Problem

No `.github/workflows/` directory exists. CI is a baseline expectation for an open-source Flutter package: it gates regressions, signals quality to pub.dev consumers, and unblocks the README CI badge (task #09 item 2).

## Approach

Single workflow at `.github/workflows/ci.yml` that runs on push and pull request:

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, macos-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
      - run: flutter pub get
      - run: dart format --output=none --set-exit-if-changed .
      - run: flutter analyze
      - run: flutter test
```

## Why this matrix

- `ubuntu-latest` covers Android + Web build paths and runs faster for the bulk of analyze/test.
- `macos-latest` is required for the iOS/macOS plugin build paths in `flutter_webrtc`. Without it, an iOS-only regression slips through.
- No Windows runner — `pubspec.yaml` doesn't declare Windows support (see task #16 for the deferred upstream blocker).

## Format check rationale

`dart format --set-exit-if-changed` enforces task #15's formatting permanently — any future PR that breaks formatting fails CI rather than relying on a developer to remember.

## Files

- New: `.github/workflows/ci.yml`

## Verification

- Push triggers a CI run that completes green on both runners
- README CI badge (task #09) resolves to a "passing" image

## Future scope (not now)

- Code coverage upload (Codecov) — defer until coverage is meaningful (task #12)
- Automated publishing via OIDC — defer until first manual publish has happened
