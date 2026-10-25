# RESQ — Verification Report

**Version under test:** 0.8.0+2
**Last updated:** 2026-10-25
**Overall status:** **PARTIALLY VERIFIED.** Static analysis and all automated tests pass (2026-10-25, owner-approved verification). The APK build and every physical-device check are still pending. This document records only what was actually observed.

Automated tests passing proves the logic in a simulated mesh. It does **not** prove real radio behaviour on phones.

## Implemented

See `docs/IMPLEMENTATION_REPORT.md` (Phases 1–8) and `docs/phase-reports/PHASE_0_REPORT.md`.

## Verified by automated tests

| What | Command | Result | Date |
|---|---|---|---|
| Phase 0 skeleton | `flutter analyze` | No issues | 2026-10-25 |
| Phase 0 skeleton | `flutter test` | 2 passed | 2026-10-25 |
| Phase 0 skeleton | `flutter build apk --debug` | Built: `dist/resq-0.0.0-b1-debug.apk` | 2026-10-25 |
| Core layers mid-implementation (crypto, protocol, domain, node) | `flutter analyze` | 0 errors, 4 minor issues → fixed | 2026-10-25 |
| Full Phase 1–8 code | `flutter analyze` | 1 error (test name clash `Matcher` vs flutter_test) → fixed → **No issues found** | 2026-10-25 |
| Full Phase 1–8 code | `flutter test` | **59 passed, 0 failed** (~42 s), including all 7 Red Team simulator scenarios | 2026-10-25 |
| Full Phase 1–8 code | `flutter build apk --debug` | Built `dist/resq-0.8.0-b2-debug.apk` (165.9 MB, SHA-256 `a0e5a38c…b167`), after re-pinning Gradle 8.14.3 and installing SDK platform 37 | 2026-10-25 |

Test suites written and waiting to run:
- `test/triage_test.dart`
- `test/protocol_test.dart`
- `test/reconciler_test.dart`
- `test/matcher_test.dart`
- `test/red_team_test.dart`
- `test/app_test.dart`

## Bug-fix pass (2026-10-25)

A code review found 23 issues. All were fixed and re-verified with `flutter analyze` (clean) and `flutter test` (**66 passed**: the original 59 plus 7 regression tests). The C5 regression test was mutation-checked: it fails with the fix disabled.

| ID | Fix | Proof |
|---|---|---|
| C1 | Link flood guard tolerates a full store-and-forward replay (burst 260 > sync batch 200) | regression test |
| C2 | Process-wide cached Flutter engine (`ResqApplication`) survives the Activity; mesh auto-restores headless when the service restarts | device test pending |
| C3 | High-priority alerts (sound + vibration) for new offers, victim status changes and stand-downs | device test pending |
| C4 | Sealed SOS only offered to verified responders; a phone that can't open it never gets the offer | regression test |
| C5 | Offer rounds restart once every candidate has lapsed (declines stay excluded) | regression test, mutation-checked |
| H1 | Radio state comes only from real transport status; UI shows RADIO NOT RUNNING, Bluetooth off, location off | device test pending |
| H2 | Mesh-on choice persisted and restored at launch | device test pending |
| H3 | Clock skew tolerance 30 min, plus a "this phone's clock differs" warning from neighbour samples | code review |
| H4 | Heartbeats expire after 15 min instead of 24 h | code review |
| H5 | Backups disabled; unreadable Keystore → new keys instead of a startup failure | device test pending |
| H6 | Only the Bluetooth permissions are required; location / Wi-Fi / notifications become visible warnings | device test pending |
| M1 | UI rebuilds throttled to 4/s | code review |
| M2 | Beacons travel 3 hops instead of 4 | code review |
| M3 | Discovery pauses once 3 peers are connected; periodic re-scan | device test pending |
| M4 | Co-location Sybil rule ignores verified or vouched identities and differing skills | 3 regression tests |
| M5 | Data wipe also clears the duplicate filter, beacons, penalties and offer state | code review |
| M6 | Acceptance caveat only shown while the status is ACCEPTED | code review |
| M7 | Hazard size chosen by the reporter (widened by GPS uncertainty) | code review |
| M8 | Drawer lines derived from live state | code review |
| M9 | Penalties persisted for 24 h | code review |
| M10 | Local database AES-encrypted, key in Keystore | device test pending |
| L1 | A responder is never matched to their own SOS | regression test |
| L2 | Delivery state persisted only for SOS publishes | code review |

## Verified on physical devices

**None yet.** Device plan (2 phones available, D8):

1. Install the APK on both phones; turn on the mesh; confirm permission prompts and the denial states.
2. Airplane mode with Bluetooth/Wi-Fi on → phone A sends an SOS → phone B shows it as an open request or offer.
3. Responder phone accepts → the victim phone shows `RESPONDER ACCEPTED — DEPARTURE NOT CONFIRMED`.
4. Screen-off relay with the foreground service.
5. Split/rejoin the two phones (out of range, then back) → statuses reconcile.
6. Demo authority on A, pin on B, issue a credential → B shows VERIFIED.

The A–B–C three-hop relay can't be proven with 2 phones. It is covered by the simulator only.

## Not verified

Everything in Phases 1–8. Specifically:
- radio interoperability;
- background survival;
- sealed-box interoperability between devices;
- simulator performance;
- triage p95 latency;
- release build with R8;
- the release-signing path.

## Security limitations

- The sealed-box composition (age-style X25519 + HKDF + XChaCha20-Poly1305) has **not been independently reviewed** (ADR-002).
- No forward secrecy for sealed SOS.
- Local data is AES-encrypted, but a rooted phone with Keystore access can still read it (ADR-006).
- Signatures prove key control, not real-world identity or qualifications.
- Trust anchors in the demo are self-declared **DEMO AUTHORITY** phones.

## Known risks / release blockers

1. Full static analysis and tests have not run, so compile errors are possible.
2. Nearby behaviour on the actual phones is unproven, and the transport spike hasn't run.
3. Independent crypto review is pending, so no production E2E claim can be made.
4. OEM background killing is unmeasured.
5. No release keystore yet: `key.properties` is absent, so a release build would be debug-signed.
6. Not clinically validated; triage is a rule-based recommendation only.

## How to run

```powershell
flutter pub get
flutter analyze
flutter test
powershell -ExecutionPolicy Bypass -File scripts\build_apk.ps1            # debug
powershell -ExecutionPolicy Bypass -File scripts\create_release_keystore.ps1   # once
powershell -ExecutionPolicy Bypass -File scripts\build_apk.ps1 -Release -SplitPerAbi
adb install -r dist\resq-0.8.0-b2-debug.apk
```
