# Phase 0 Report — Foundation, decisions & first APK

**Date:** 2026-10-25
**Branch / commit:** `mvp/phase-0` (uncommitted — owner commits, D9)

**APK:** `dist/resq-0.0.0-b1-debug.apk`
- versionName 0.0.0, versionCode 1, 145.7 MB (debug, all ABIs)
- SHA-256 `c49e042e969ee9704958ad27efc376d78ab314ff303b08dcad34a1cca261d4c3`
- Installed on: **not yet installed on a phone**

## Done

- **Toolchain** under `C:\dev`, with every download checksum-verified:
  - Flutter 3.47.8 / Dart 3.13.7 (SHA-256);
  - Temurin JDK 17.0.20.1 (SHA-256);
  - Android cmdline-tools 16111833 (SHA-1 from Google's repository index);
  - platform-tools 37.0.1, platform 36, build-tools 36.1.0, NDK 28.2.13676358.
- **Environment:** Flutter is pointed at JDK 17 through `flutter config --jdk-dir`. The system-wide `JAVA_HOME`/JDK 23 is untouched. `ANDROID_HOME` and the Flutter/adb PATH entries were added for the user.
- **Repo cleanup:**
  - prototype archived to `archive/prototype/` (D6);
  - windows/linux/macos/web folders removed (D7);
  - docs moved to `docs/`.
- **Android config:**
  - package ID `com.darubaaz.resq` (D1);
  - Gradle wrapper on the cached 8.14.3;
  - Gradle heap lowered from 8 GB to 3 GB to fit the 7.4 GB machine;
  - project kept on AGP 8.11.1.
- **App:** skeleton with the monochrome theme and bundled Roboto Mono (OFL).
- **Docs and scripts:** ADR skeletons; `scripts/build_apk.ps1`.
- **Transport spike:** `spikes/transport_spike` written against both packages' verified APIs. **Not built or run.** The owner deferred testing.

## Commands run and results

| Command | Result |
|---|---|
| `flutter doctor -v` | No issues found |
| `flutter analyze` | No issues found |
| `flutter test` | 2 passed |
| `flutter build apk --debug` | Built after manual NDK install (Gradle's automatic NDK download failed) |
| `aapt2 dump badging` | `com.darubaaz.resq`, minSdk 24, targetSdk 36, only INTERNET (debug manifest) |

## Not done / not verified

- **Two-phone transport spike:** owner-deferred.
- **APK install on a physical phone.**

## Decisions

- **Recorded:** D1, D6, D7, D8 (2 phones), D9 (owner commits).
- **Provisional, implemented with the recommended defaults pending owner confirmation:**
  - D2: transport `nearby_connections`;
  - D3: rules-only triage;
  - D4: authority keys plus vouching;
  - D5: victim choice, default share openly.
