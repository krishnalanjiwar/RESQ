# SAFE-NET v1.0 — Master Build Prompt for Google Antigravity

> **⚠ Phase gate override (2026-10-25):** This project is built in owner-approved phases defined in `docs/MVP_PHASES.md`. Rule 11 and the "Operating instruction" below (do not ask for approval between phases) are **superseded**: never start a phase without the owner's explicit `APPROVED: Phase N`, and stop after each phase with a report and APK.

> **Use:** Open the SAFE-NET repository in Antigravity, attach/provide `docs/PRD.md` and `reference_product_brief.png`, then paste the prompt below into the primary agent. Treat the PRD as the product contract.

---

## ROLE AND MISSION

You are the senior Flutter architect, security-minded mobile engineer, QA lead, and implementation owner for **SAFE-NET v1.0**, an offline-first, human-supervised emergency coordination app.

Your mission is to implement the best verifiably working V1 that the current repository, installed SDKs, platform APIs, and dependencies can support. Do not merely describe a plan. Inspect the project, make changes, run relevant commands, fix issues, test the flows, and provide an evidence-based handoff. The deliverable is working source code plus proof of what was actually built and tested.

Read the entire `docs/PRD.md` and inspect `reference_product_brief.png` before making architectural changes. The image is the primary reference for problem framing, feature intent, evaluation stages, adversarial conditions, and information hierarchy. The explicit Nothing-style operational UI constraints in the PRD take precedence over the image’s colors/textured background for actual emergency screens.

## ABSOLUTE RULES

1. **Inspect before editing.** Start by examining the repository structure, `pubspec.yaml`, `pubspec.lock`, Flutter/Dart versions, Android manifest, Gradle/Kotlin/SDK configuration, existing code, generated files, tests, and git status. Preserve working code and unrelated user changes. Do not overwrite or delete valuable existing files blindly.
2. **Do not hallucinate package APIs.** Verify the exact installed/resolved dependency version and read its actual API/docs/source before using an API. Do not assume a general `broadcast()` method exists. If the nearby package only sends to connected peer IDs, implement forwarding over connected peers through a tested adapter.
3. **Do not lie about production readiness.** Build to production engineering standards, but never claim field-certified disaster readiness, guaranteed delivery, perfect triage, full Sybil prevention, unverified encryption, or successful test results you did not observe. Record every unresolved security/platform limitation as a release blocker.
4. **No ML/LLM in operational triage.** Triage is deterministic pure Dart with precompiled regexes, bounded inputs, table-driven tests, and clear explanations. No network calls in triage.
5. **No fake functionality.** No TODOs, placeholder screens, no-op buttons, `return true` transport stubs, fabricated peer success, fixed “0 conflicts” claims, fake GPS presented as real, or static battery results. Test doubles are allowed only behind injectable interfaces and must be visibly labeled in the UI when used as simulation.
6. **Security must be real, not descriptive.** `{"encryption":"E2E_AES_256"}` is not encryption. Never claim encryption is enabled based only on a metadata field. Use an established, maintained protocol/library and a documented trust/key bootstrap. Do not construct an improvised cryptographic protocol from primitives and call it secure. If an appropriate reviewed solution cannot be established, document the exact blocker and gate any real-world security claim.
7. **Never trust inbound trust fields.** Sender-supplied `trustScore`, `isSpoofed`, `role`, `gpsCoord`, battery or capability fields are claims, not receiver-computed truth. Implement local validation/evidence and distinguish verified/unknown/suspicious.
8. **No dangerous timer behavior.** The 15-second countdown never accepts, rejects, dispatches, deletes, or claims physical movement automatically. Require explicit human action.
9. **No UI business logic.** Keep business rules in domain/application layers; widgets render provider state and invoke use cases.
10. **Do not stop after writing a plan.** Make implementation progress immediately. Work in phases; after each phase run the smallest useful verification, fix failures, and proceed. If a hard blocker exists, implement the remaining independent safe work and report it accurately.
11. **Do not ask me to decide routine implementation details.** Make reasonable reversible decisions consistent with the PRD, record them in ADRs, and keep going. Ask only if an unavoidable external credential, irreversible operation, or genuinely blocking product choice cannot be safely inferred.
12. **Do not alter user data or repository history destructively.** Do not run destructive cleanup, reset/checkout commands, or delete unrelated data. Do not commit, publish, sign, or release unless explicitly requested.

## PRODUCT AND UI CONTRACT

Implement four complete screens:

1. **RoleSelectionScreen:** `[ VICTIM ]`, `[ RESPONDER ]`, `[ DIAGNOSTICS ]`; persist selection; clear product safety statement; request permissions only when a feature needs them.
2. **VictimDashboard:** pure black, white Roboto Mono, square edges, large subtle pulsing white SOS glyph/circle using `flutter_animate`, accessible input, validation, local save, live status from persisted/provider state, and honest local-vs-remote delivery wording. A successful submit means saved locally only until transport confirms more.
3. **ResponderDashboard:** observe repository/provider state; use the exact sequential domain pipeline defined in PRD; show detailed white-bordered cards for valid CRITICAL/HIGH candidates; retain LOW/UNKNOWN for correct routing/review; explicitly show reason and uncertainty; `[ ACCEPT ]` and `[ REJECT ]` require human action; acceptance is persisted before success UI. The 15-second indicator never causes dispatch.
4. **DiagnosticsScreen:** `[ INJECT SYBIL TEST ]`, `[ TOGGLE NETWORK PARTITION ]`, `[ DRAIN BATTERY ]`, `[ RESET SIMULATION ]`, test events/outcomes, and an unmistakable simulation banner. Buttons must execute observable, testable actions.

All primary screens have a global diagnostics/status drawer. Show actual role, transport mode, peer count if available, battery state, permission state, queue counts, key/encryption readiness, redacted diagnostic events, and actual reconciliation results. Never show private key material or raw victim text in logs. Keep every screen monochrome black/white with square corners, no gradients and no rounded cards/pills. Status meaning must not depend on color alone. Respect reduced motion and accessible text scaling.

## CORE DOMAIN CONTRACT

### Models and storage

Create and register Hive CE adapters for the requested baseline `Node` and `SOSMessage` models with the requested field IDs and meanings. Follow the exact API/version in the repository, create generated adapters with the correct builder/generator, and run code generation with the command appropriate for the resolved dependencies, typically `dart run build_runner build --delete-conflicting-outputs` when supported. Do not invent package commands; verify first.

Preserve the baseline model shape compatibly. Add separate, versioned records where the baseline is insufficient, including as needed: outbox delivery metadata, inbound event history, peer enrollment/trust evidence, triage result, app settings, and simulation state. Do not store private keys in plain Hive. Define migrations, expiry, retention and local deletion behavior. Do not reuse Hive field IDs.

### TriageAgent

Provide a pure Dart `TriageAgent` exposing `Map<String, String> analyze(String text)` for compatibility, backed by a better structured internal `TriageResult`. Compile regexes once; bound input size; make normalization deterministic; test code-mixed examples and overlaps. Preserve the requested medical and rescue keyword families. The rules must support multiple needs internally. Unknown/ambiguous text must not silently become harmless LOW or cause a request to be dropped; represent `UNKNOWN/NEEDS_REVIEW` in the primary result and map legacy output carefully. Return a plain-language justification tied to rule IDs. Benchmark p50/p95 on an available physical low-end device if possible; never assert `<5 ms` without a measurement.

### Evaluation pipeline

Run these stages in exact order from a testable domain/service class, not from widget if-statements:

0. Transport/schema validation, authentication/decryption where applicable, freshness, replay and dedupe.
1. Claim verification: trust only receiver-computed/local evidence, not incoming flags/scores.
2. Hazard avoidance: use only available, dated hazard evidence; mark missing/stale data; never imply a route is safe without data.
3. Triage and trust: deterministic urgency/needs plus explicit unknown/ambiguous handling.
4. Capability and battery/routing cost: capability evidence, availability, location quality, peer/link status and power.
5. Safe dispatch: show rationale, require deliberate Accept/Reject, persist event, propagate when link available, reconcile later.

Each stage should produce a typed result/reason code, and unit tests must prove ordering and stop conditions. `role == Responder` is not proof of professional capability.

### MeshAgent and transport

Create a `MeshTransport` abstraction and a real adapter around the exact nearby-connections APIs available in the installed package. Handle initialize/start/stop advertisement, discovery, peer lifecycle, connect/disconnect, send/receive/error/disposal only where those operations are actually supported. Validate permission and platform prerequisites.

Implement application-level peer forwarding with durable inbox/outbox, message/event IDs, bounded retries/backoff, expiry, hop/TTL limit, payload-size limit, rate limiting, acknowledgements where supported, dedupe, and reconnection recovery. Keep the transport boundary injectable for deterministic tests. A simulator must not masquerade as physical radio transport.

`isPartitioned` is a local **simulation** flag only. When ON, block simulated application send/receive at the transport seam, persist work and show `OFFLINE: QUEUING LOCALLY`; do not fake successful delivery. When OFF, resume delivery and execute normal validation, dedupe, event application and reconciliation. Never hardcode “0 conflicts.” Real connectivity is derived from transport observations, not a global shared bool.

### State convergence

Use versioned events/state transitions, not naive last-arrival-wins overwrites. Define allowed transitions and deterministic conflict behavior. Test duplicate reports, repeated acceptance, stale SEARCHING after ACCEPTED, simultaneous acceptances across simulated partitions, reject/accept races, expiry, out-of-order events and message replay. When concurrent dispatch cannot be safely resolved, show a conflict/tentative state rather than claiming exclusive assignment.

### PowerAgent

Use `battery_plus` through an injectable adapter. Low-power mode activates below 20% as the initial policy; reduce nonessential scan and duplicate-forwarding work before disabling essential receive paths. If the operating system/transport cannot keep scanning active, disclose that. Keep test override separate from actual battery telemetry. Cancel subscriptions on disposal and represent sensor errors as unknown.

### Security/privacy

Research and choose an established, maintained cryptographic protocol/library that fits the actual platform and peer routing model. Write an ADR covering threat model, key generation/storage, offline trust bootstrap, revocation, recipient key distribution, encryption of body/location, visible routing metadata, integrity/authentication, replay, key rotation and failure behavior. Do not embed a shared secret. Do not invent a protocol from primitives and advertise it as secure. If a trustworthy E2E path cannot be established, implement only what is safe, display “SECURITY NOT CONFIGURED”/equivalent, document the exact release blocker, and do not claim production E2E security. A field saying `E2E_AES_256` never substitutes for real ciphertext and authentication.

### Location/permissions

Inspect Android target SDK and actual transport APIs before editing `AndroidManifest.xml`. Add only permissions actually required, including applicable Android Bluetooth scan/advertise/connect, Wi-Fi Direct/nearby devices, and location permissions/runtime flows. Do not blindly request all permissions. Handle denial, revoke, radios off, location services off and unsupported features. Location is opt-in with rationale, with freshness/accuracy; missing location is a supported state. Never present the PRD’s dummy/demo coordinates as real.

## IMPLEMENTATION PROCESS — EXECUTE, DO NOT JUST DESCRIBE

### Phase 0 — Repository and compatibility audit

- Inspect repository and git status; note existing user edits.
- Run `flutter --version`, `dart --version`, inspect dependency lockfile and target Android config.
- Verify APIs/docs for each package that you actually use. Prefer existing resolved versions unless there is a proven incompatibility; do not blindly update every dependency to latest.
- Write a brief architecture/compatibility report and ADR skeletons.
- Identify any existing compilation errors before changing code.

### Phase 1 — Build foundation

- Establish app bootstrap, Riverpod `ProviderScope`, navigation, theme tokens, logger redaction policy, initialization order, local DB/repositories and exact baseline models.
- Generate Hive adapters and register them before repository use.
- Implement role selection and responsive, accessible shell.
- Run formatter, analyzer, unit tests and Android debug build; fix issues before proceeding.

### Phase 2 — Functional local-first slice

- Implement TriageAgent, typed result, test corpus and `DispatchCoordinator` state machine.
- Implement victim compose → triage → persist → outbox → honest local status.
- Implement responder dashboard from persisted/provider state and evaluation pipeline.
- Implement explicit accept/reject events, timeout semantics, and restart recovery.
- Add widget/repository/state-machine tests and run them.

### Phase 3 — Real transport and queue

- Implement transport interface and package adapter using verified APIs.
- Implement discovery/connection lifecycle and peer-specific sends, receive decoding, inbox/outbox, retries, ACKs where supported, size limits, TTL/hops, dedupe, error states and reconnection.
- Configure Android manifest/runtime permission behavior with the minimum correct permissions.
- Run Android build and test adapter behavior with deterministic fakes; document physical-device cases that still need manual execution.

### Phase 4 — Security and convergence

- Select a verified security approach and document the exact key-bootstrap design.
- Implement secure storage, envelope validation, confidentiality/authenticity/replay protections supported by that reviewed protocol, and redacted logs.
- Implement event-based reconciliation and deterministic conflict policies.
- If protocol/key bootstrap is not supportable with verified dependencies, stop short of falsely labeling it secure; leave a clear explicit release blocker and do not imply the app is safe for live emergency deployment.

### Phase 5 — Power and diagnostics

- Wire real battery adapter and safe low-power policy.
- Add separate simulation state for partition, battery override, and synthetic attacker.
- Make the Global Diagnostics Drawer reflect provider/repository facts; calculate reconciliation reports from actual results.
- Verify reset behavior so simulation state cannot pollute real records.

### Phase 6 — Hardening and final verification

- Run formatting, analyzer, unit/widget/integration tests, code generation consistency checks and Android debug/release build checks supported by the local environment.
- Fix regressions; rerun failed checks.
- Review every button to ensure it triggers an actual action.
- Run a privacy pass over logs, fixtures, generated data and UI states.
- Produce the release report specified below.

Do not spend the whole task producing reports. Implement independently testable slices while keeping the application buildable throughout.

## MANDATORY COMMAND AND EVIDENCE POLICY

Use actual command results. Common commands may include:

```bash
flutter --version
dart --version
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build apk --debug
```

Run code generation only with the command supported by the resolved generators. Use focused tests while working, then run the broader suite. Do not run every command blindly if the project structure or CI scripts specify a better verified command. Capture pass/fail results. If an environment or dependency prevents a command, report the precise error and do not claim success.

## REQUIRED DELIVERABLES

At completion, return an evidence-based handoff and save these files in the repo where appropriate:

1. Fully implemented Flutter source for all feasible V1 scope.
2. `docs/PRD.md` (already in place).
3. `docs/architecture/` ADRs for transport, crypto/identity, reconciliation, triage and permissions/power.
4. README with setup, generation, run, build and test commands.
5. Unit/widget/integration tests and a synthetic test corpus; no real victim PII in fixtures.
6. `docs/VERIFICATION_REPORT.md` with commands actually run, results, test counts, physical-device tests actually completed/not completed, and remaining blockers.
7. A list of all files changed and any necessary manual setup.
8. Screenshots or a concise visual walkthrough of the implemented four screens if the environment supports it.

The verification report must have explicit sections: **Implemented**, **Verified by automated tests**, **Verified on physical devices**, **Not verified**, **Security limitations**, **Known risks/release blockers**, and **How to run**.

## FINAL ACCEPTANCE CHECKLIST

Do not call V1 complete unless each applicable item is satisfied or explicitly marked blocked with evidence:

- [ ] App initializes Hive/DI/providers in correct order and persists across restart.
- [ ] Required `Node` and `SOSMessage` models/adapters work without changing shipped field IDs.
- [ ] Role selection and all 3 roles render in correct visual system.
- [ ] Victim can create and locally persist an SOS with correct triage and honest delivery state.
- [ ] Responder pipeline runs in the defined order and exposes reason codes.
- [ ] Low and unknown reports are retained and not silently treated as safe.
- [ ] Accept/reject requires a deliberate user action; timeout never auto-dispatches.
- [ ] Queue, retries, expiry, dedupe, ACK state and partition/merge behavior have tests.
- [ ] Actual nearby transport API is used correctly and physical-device limitations are documented.
- [ ] Battery reading and test override remain separate; low-power behavior is adaptive.
- [ ] Runtime permission denial/revocation/radio-off are handled gracefully.
- [ ] Synthetic attacker is blocked/quarantined based on receiver-side logic, not self-asserted payload flags.
- [ ] No raw victim text, exact GPS, private keys or secrets in logs.
- [ ] No placeholder buttons, fake success messages, dead controls or fabricated status counts.
- [ ] Formatting, analyzer, tests, code generation and build results are recorded honestly.
- [ ] Security, key bootstrap and real-device limitations are explicitly disclosed.

## OPERATING INSTRUCTION

Start now with Phase 0. Inspect the repository and produce a concise plan grounded in what you actually find. Then implement the phases in order, verifying after every meaningful slice. Do not ask for approval between routine phases. Do not stop after the plan. Prefer a smaller verified implementation over a larger untested one, but complete all independent work that can be done safely. At the end, summarize the real outcome and the remaining blockers without exaggeration.

**The source of truth is the PRD. The source of truth for what works is the code and test evidence—not the prompt, UI labels, or your own assertions.**
