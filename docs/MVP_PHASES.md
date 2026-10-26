# RESQ MVP — Phased Delivery Plan

**Problem statement:** Theme 1 · Problem 3 — *The Human-Powered Emergency Network*
**Deliverable:** an installable Android application (`.apk`) that runs a decentralized, on-device, multi-agent mesh protocol.
**Plan status:** DRAFT — waiting for approval to start Phase 0
**Created:** 2026-10-25
**Related docs:** `docs/PRD.md` (engineering guardrails), `docs/ARCHITECTURE.md`

---

## 0. Phase gate rule — read before anything else

1. **No phase may start without explicit written approval from the project owner.** The approval must name the phase, e.g. `APPROVED: Phase 2`.
2. "Starting a phase" means any code, dependency, configuration, asset, or build change belonging to that phase. Read-only investigation happens only when the owner asks for it.
3. Approval is valid for **one phase only**. Approval of Phase N never implies approval of Phase N+1. Neither do silence, a past approval, or a general "continue".
4. At the end of every phase the implementer **stops**, writes the Phase Report (template in §9), attaches the APK, and waits.
5. If a phase hits a blocker that changes scope, a decision, or a PS criterion, the implementer stops mid-phase and asks. It never silently re-scopes.
6. This rule overrides any instruction elsewhere that says "don't ask for approval between phases", including the `docs/agent/BUILD_PROMPT.md` rule 11 and its "Operating instruction".

### Owner override — 2026-10-25

The owner instructed: *"don't test it now, just implement the phases all first."* This **approves implementing Phases 1–8 in one pass**, with every build, test run and device check **deferred**.

No phase counts as ✅ Done until its exit criteria are verified. The per-phase gate applies again to the **verification** of each phase: the owner approves verifying Phase N, and the phase report records the real results.

### Phase status tracker

| Phase | Title | Status | Approved on | Completed on | APK |
|---|---|---|---|---|---|
| 0 | Foundation, decisions & first APK | ✅ Automated checks passed (2-phone spike pending, owner-deferred) | 2026-10-25 | 2026-10-25 | `dist/resq-0.0.0-b1-debug.apk` |
| 1 | Protocol core & multi-node simulator | 🛠 Implemented — verification deferred | 2026-10-25 | — | — |
| 2 | Victim/Responder flows, triage & capability parsing | 🛠 Implemented — verification deferred | 2026-10-25 | — | — |
| 3 | Real P2P radio mesh on devices | 🛠 Implemented — verification deferred | 2026-10-25 | — | — |
| 4 | Identity, trust anchors, Sybil defense & privacy | 🛠 Implemented — verification deferred | 2026-10-25 | — | — |
| 5 | Probabilistic evaluation chain & distributed dispatch | 🛠 Implemented — verification deferred | 2026-10-25 | — | — |
| 6 | Partition reconciliation | 🛠 Implemented — verification deferred | 2026-10-25 | — | — |
| 7 | Red Team Hour & diagnostics | 🛠 Implemented — verification deferred | 2026-10-25 | — | — |
| 8 | Hardening, release APK & demo | 🛠 Implemented — verification deferred | 2026-10-25 | — | — |
| 9.1 | Tap-to-open Google Maps, ~~brutalist dashboard~~ (reverted to the Google-style dashboard in 0.13.1 at the owner's request), SOS quick picks + SOS without text, automatic GPS arrival alerts to both sides | 🛠 Implemented — automated checks pass; on-device check pending | 2026-10-26 (owner: "do it asap") | — | `dist/resq-0.13.0-b7-*` |
| 9 | Critical-time UX: dashboard + Home/Back, ringing alerts, medical card, SOS-A–D severity, responder profession, Google-style UI | 🛠 Implemented — automated checks pass; on-device check pending | 2026-10-26 (owner: "now complete it… build the APK now") | — | `dist/resq-0.12.0-b6-*` |

Status values: `🔒 Locked` → `⏸ Awaiting approval` → `▶ In progress` → `🛠 Implemented — verification deferred` → `✅ Done` (or `⛔ Blocked`).

---

## 1. What the MVP must prove — PS criteria traceability

Every criterion below must have **observable evidence**: an automated test, a device test, or a visible app behavior. Phase reports must update the Evidence column.

| ID | PS criterion | How the MVP proves it | Built in | Evidence |
|---|---|---|---|---|
| C1 | Fully decentralized, P2P radio only, no central server | No backend; devices exchange messages over Nearby (BLE/Wi-Fi) with multi-hop forwarding; works in airplane mode + BT/Wi-Fi on | 1, 3 | — |
| C2 | Accept fragmented, untrusted, constrained input ("Need insulin for dad, ground floor flooded", drifting GPS, 12% battery) | That exact message is a named test case through the whole pipeline. GPS carries accuracy/freshness. Battery is a claim plus a local reading | 2, 5 | — |
| C3 | Sybil resistance ("one node pretending to be 40 nurses") | Identities seen over one physical radio link are collapsed and capped. Credentials need an offline trust-anchor signature. Uncredentialed claims carry low trust | 4, 7 | — |
| C4 | Location spoofing | Location plausibility from hop-count × radio range vs. the relays' own positions, velocity checks and witness corroboration. Output is P(location plausible) | 5, 7 | — |
| C5 | Malicious decoy emergencies | P(real) from independent-node corroboration, sender trust, identity age and content consistency. Decoys are flagged, never silently dropped | 5, 7 | — |
| C6 | Zero-shot capability matching for open-vocabulary, code-mixed claims ("has a boat", "can do dialysis") | Capability ontology + Hinglish/code-mixed lexicon + normalization + fuzzy matching. Unrecognized text routes to NEEDS REVIEW (see decision D3) | 2 | — |
| C7 | Privacy under surveillance through untrusted relays | Relays see only a minimal routing header. Text, precise location and health data are sealed to responder public keys with an established library | 4 | — |
| C8 | Distributed triage and opportunity cost (the only medic isn't sent to a minor case) | Deterministic, scarcity-weighted matcher runs identically on every device over its local view | 5 | — |
| C9 | Bystander effect | Targeted offers to specific best-match responders, not "everyone look at this". An offer window rolls over to the next candidate | 5 | — |
| C10 | Human-in-the-loop acceptance with one-line justifications | Every offer shows one plain-language line built from the chain outputs. Only an explicit ACCEPT moves anyone | 5 | — |
| C11 | Partition islands; on merge, clean up double-dispatch and orphaned victims without cancelling a responder already at the door | Event-log merge (Lamport clocks). Precedence ON_SCENE > EN_ROUTE > ACCEPTED. On-scene responders are never cancelled. Heartbeat loss reopens orphans | 6 | — |
| C12 | Red Team Hour: forged medical credentials, network battery drain, luring responders into rising floodwater | A diagnostics attack injector for each attack, a defense for each, and an automated test plus an on-device demo for each | 7 (defenses in 3–5) | — |
| C13 | Probabilistic evaluation chain, in order: Claim Verification → Hazard Avoidance → Trust Scoring → Battery/Routing Cost → Safe Dispatch | One domain pipeline. Each stage outputs a probability/score + reason codes, shown per candidate in the UI | 5 | — |
| C14 | Actual battery life and device-to-device topology | Real battery telemetry, a battery-aware relay policy, a live neighbor/topology view, and per-peer rate limits | 3, 5 | — |
| C15 | Application platform | `flutter build apk` succeeds and installs at every phase gate. A signed release APK in Phase 8 | all, 8 | — |

---

## 2. Design positions — how the MVP answers each hard problem

These are the default answers. Changing one is a decision for the owner (see §4).

### 2.1 Identity and Sybil defense (C3, C12 forged credentials)
- Every install generates an Ed25519 identity keypair. Identities are cheap, so **a keypair alone earns no trust**.
- Trust comes from evidence the receiver can check itself:
  1. **Credentials** signed by an *offline trust anchor*. The anchor is a hospital, NDRF, or NGO key provisioned before the disaster and issued to responders by QR. At runtime the network needs no central server; the trust anchor is a pre-loaded public key.
  2. **In-person vouching** (QR handshake), counted with diminishing weight.
  3. **Physical-link evidence.** Many identities arriving through the same radio endpoint are collapsed into one physical node and capped. "40 nurses" behind one endpoint becomes 1 node with 0 valid credentials.
  4. **Identity age and behavior**, such as rate-limit violations and contradictory claims.
- **Known limit:** link-level collapse only works for direct neighbors. Sybil identities several hops away are handled by credential checks. This is documented, not hidden.

### 2.2 Location spoofing and drift (C2, C4)
- GPS is a claim with accuracy and timestamp, never proof.
- Plausibility checks:
  - Is the claimed location reachable given hop count × max radio range from relays that know their own position?
  - Is the implied velocity between successive reports physically possible?
  - Do nearby witnesses corroborate it?
- Output: `P_location ∈ [0,1]` + reason codes. Drifting GPS lowers confidence; it does not reject the SOS.

### 2.3 Decoys and hazard zones (C5, C12 floodwater lure)
- **Decoys:** `P_real` combines independent-physical-node corroboration, sender trust, identity age and consistency. Low-`P_real` reports are marked SUSPECTED DECOY and kept for review. They are never auto-deleted, because a real victim with no corroboration must not vanish.
- **Hazards:** signed hazard reports (flooded street, rising water, collapsed building) propagate over the mesh as circles or polygons. Each has corroboration and a time decay.
- **Hazard check:** the responder → victim straight-line path is tested for intersection with high-confidence hazards. If the victim sits inside a flood hazard, only responders with matching capability (boat, swimmer) get the offer, and the offer card shows the hazard.
- **Known limit:** no offline road maps in the MVP, so routing is straight-line.

### 2.4 Privacy under surveillance (C7)
- **Cleartext routing header** (relays need it): message ID, type, TTL/hops, coarse geohash (about 5 km cell), and urgency class. This leak is documented.
- **Sealed body:** text, precise location and health details are encrypted per recipient to the public keys of credentialed responders, using an established construction (libsodium sealed box or equivalent; library verified in Phase 0). No hand-rolled crypto and no shared group secret.
- **Signatures** give integrity; nonces and IDs give replay protection.
- **When the victim knows no responder keys:** behavior is set by decision D5.

### 2.5 Probabilistic evaluation chain (C13)
Every stage is a pure function that outputs a score in [0,1] plus reason codes. It is computed deterministically, so every device holding the same view gets the same result.

```
Claim Verification  → P_claim   (P_real × P_location)
Hazard Avoidance    → P_safe    (path/target vs hazard zones, responder capability)
Trust Scoring       → T         (credentials, vouches, link evidence, age, behavior)
Battery/Routing     → C_cost    (responder battery, hop distance, link quality, distance)
Safe Dispatch       → score = U(urgency) × P_claim × P_safe × T / C_cost  → gated → offer
```

Hard gates sit on top of the score. Examples: `P_safe` below the threshold means no offer to unequipped responders; a credential the role requires is missing means no offer for that role. The UI shows every stage for every candidate.

### 2.6 Distributed triage, opportunity cost and the bystander effect (C8, C9, C10)
- Every responder device runs the **same deterministic matcher** over its local view of open SOS events and responder beacons.
- **Scarcity weighting:** a responder with a rare skill (the only medic) is reserved for the highest-urgency SOS that needs that skill.
- The matcher produces **targeted offers** to the best one or two candidates, not a broadcast to all. That counters the bystander effect.
- **Offer window** (default 60 s, configurable): if nobody acts, the offer moves to the next candidate. **A timeout never accepts, rejects, or dispatches.**
- **One-line justification** from a template over the chain outputs, for example: *"Critical insulin need 1.2 km NE; you are the only verified nurse within 3 km; path avoids 1 flood zone; 2 independent nodes confirm."*
- **ACCEPT** broadcasts a signed claim event, and other candidates are told to stand down. Responders then report progress: EN_ROUTE → ON_SCENE → RESOLVED.

### 2.7 Partition reconciliation (C11)
- **Event log:** each SOS has an append-only, signed event log with Lamport clocks. Merging is a set union of events, followed by deterministic resolution.
- **Double-dispatch:** precedence ON_SCENE > EN_ROUTE > ACCEPTED, with ties broken by (lamport, nodeId). The losers get **STAND DOWN — another responder is on scene / closer in progress**.
- **Never cancel at the door:** a responder already ON_SCENE is never told to stand down. If two responders are both on scene, both stay and a conflict is shown.
- **Orphans:** if the assigned responder's heartbeat is missing for T minutes, the SOS reopens to SEARCHING and goes back into matching.

### 2.8 Battery and network-drain defense (C12, C14)
- **Local battery** comes from real telemetry. **Peer battery** is a claim carried in beacons.
- **Relay policy:** below 20%, relay only CRITICAL traffic and your own traffic, and scan less often. The essential receive path is never fully disabled without a visible warning.
- **Per-peer limits:** a token-bucket rate limit, a payload size cap, a TTL cap and a duplicate-flood cutoff. A drain attacker's impact is bounded and the attacker is quarantined.

---

## 3. Engineering guidelines — apply to every phase

Condensed from the PRD. Breaking one fails the phase gate.

1. **Never fake a state.** Saved locally, sent to peer, peer acknowledged, responder accepted, en route and on scene are distinct states, and the UI never shows one as another.
2. **No fake functionality.** No no-op buttons, hard-coded RSSI or battery values, "0 conflicts" constants, or "AI engine active" labels. Simulation is always visibly labeled **SIMULATION**.
3. **Verify every package API** against the resolved version in `pubspec.lock` before using it. Record the versions in the phase report.
4. **No business logic in widgets.** Domain logic is pure Dart and unit-testable. Use Riverpod 3 `Notifier`/`AsyncNotifier`, not the legacy `StateNotifier`/`StateProvider`.
5. **Trust nothing that arrives over the wire.** Sender-supplied trust, role, credential, GPS, battery and timestamp fields are claims.
6. **No timer ever dispatches, accepts or rejects.**
7. **Unknown or ambiguous reports are never downgraded to "safe".** They go to NEEDS REVIEW.
8. **No hand-rolled cryptography.** Never display "encrypted" unless real ciphertext is on the wire.
9. **Logs never contain** raw victim text, precise location or keys.
10. **The APK must build at every gate.** `flutter analyze` must report 0 errors, `flutter test` must be green, and `flutter build apk --debug` must succeed. The APK must install on a physical phone, and its path and version go in the report.
11. **Version per phase:** `versionName 0.<phase>.0`, with `versionCode` incremented.
12. **Small commits on a feature branch** per phase, if the owner allows commits. No pushes or releases without owner approval.

---

## 4. Decisions the owner must make (inside Phase 0)

Phase 0 cannot close until each of these is answered or explicitly deferred.

| ID | Decision | Options | Recommendation |
|---|---|---|---|
| D1 | Product name and package ID | RESQ / SAFE-NET; `com.<team>.resq` | Keep **RESQ**. Replace the `com.resq.resq` placeholder with a team-owned package ID |
| D2 | Transport package | `flutter_nearby_connections_plus` (fork, last release ~15 months ago) vs `nearby_connections` vs other | Decide from a **2-phone spike** in Phase 0, not from docs |
| D3 | Zero-shot capability/triage approach | (a) Rules + code-mixed lexicon + fuzzy matching only; (b) (a) + small on-device multilingual embedding model for unmatched text | **(a) for MVP, (b) as a stretch in Phase 2** if APK size and latency allow. Embeddings only rank; they never decide alone |
| D4 | Trust anchor model | Pre-provisioned authority keys (hospital/NDRF/NGO) issued by QR, vs pure web-of-trust | **Authority keys + bounded vouching**. Demo with 1–2 mock authorities labeled as such |
| D5 | SOS when no responder keys are known | Send the sealed body only (unreadable until keys known) / let the victim choose "share openly" / always open | **Victim choice, defaulting to share openly for CRITICAL**: reachability beats secrecy for a dying victim. The choice is shown clearly |
| D6 | Existing `lib/` prototype | Delete / archive / adapt | **Delete.** It doesn't compile and conflicts with the PRD. Salvage only the Android manifest notes |
| D7 | Desktop/web platform folders | Keep / remove | **Remove.** The product is Android-only |
| D8 | Team size, deadline and number of physical Android phones | — | Needed to size phases and choose the §7 cut line. **At least 3 phones** are required for the multi-hop and partition device tests |
| D9 | Commits | Implementer may commit per phase on a branch / owner commits | Commit per phase on `mvp/phase-N` |

---

### Owner answers (2026-10-25)

| ID | Answer |
|---|---|
| D1 | Name **RESQ**; package ID **`com.darubaaz.resq`** |
| D2 | **Provisional: `nearby_connections` 4.3.0** (spike written, not run — owner deferred testing). See ADR-001 |
| D3 | **Provisional: (a) rules + code-mixed lexicon + fuzzy matching**; embedding stretch not implemented |
| D4 | **Provisional: authority keys (provisioned or pinned in person) + bounded vouching** |
| D5 | **Provisional: victim chooses; default share openly when no verified responder keys are known** |
| D6 | **Archive** the prototype to `archive/prototype/` (excluded from the build) |
| D7 | **Remove** the desktop/web folders. `ios/` is kept but out of scope |
| D8 | **2 physical phones.** Team size and deadline not yet given. **Impact:** the A–B–C three-phone relay (Phase 3) and the island split (Phase 6) can't be fully proven on devices. Multi-hop and partitions will be proven in the simulator, and on devices only as direct 2-phone links and a 2-phone split/rejoin. C1 and C11 device evidence stays partial unless a third phone is found |
| D9 | **Owner commits.** The implementer makes no commits; work is left uncommitted on `mvp/phase-N` branches |

## 5. Phases

Each phase lists **Goal, PS criteria, Scope, Deliverables, Exit criteria**. The last bullet of every phase is the APK requirement and the gate.

---

### Phase 0 — Foundation, decisions and first APK
**Goal:** a clean, compiling repo; a verified toolchain; decisions D1–D9 recorded; a radio spike proving two phones can exchange bytes.
**PS criteria:** C15 (and groundwork for C1)

**Scope**
- Install and verify the toolchain: Flutter stable, Android SDK and platform tools, **JDK 17** (the machine has JDK 23, which current Android Gradle tooling may reject).
- Repo hygiene:
  - move the agent docs to `docs/`;
  - remove the broken prototype (D6) and the desktop/web folders (D7);
  - fix `pubspec.yaml` (no missing asset folders, no unused AI packages);
  - commit `pubspec.lock`;
  - replace the default test.
- Set the Android config: package ID (D1), `minSdk` chosen from the transport needs, and keep `targetSdk` current.
- Build a skeleton app: Riverpod 3 bootstrap, monochrome theme (black/white, Roboto Mono, square corners) and a placeholder role screen marked "PHASE 0 SKELETON".
- **Transport spike:** a throwaway app on 2 physical phones exchanging a message with both candidate packages. Record pass/fail per package (D2).
- ADR skeletons: ADR-001 transport, ADR-002 crypto/identity, ADR-003 reconciliation, ADR-004 triage, ADR-005 power/permissions.

**Deliverables:** clean repo, decisions table filled in, spike report, ADR skeletons, `scripts/build_apk.ps1`.

**Exit criteria**
- `flutter doctor` shows Android toolchain OK.
- `flutter analyze` reports 0 errors; `flutter test` passes.
- `flutter build apk --debug` succeeds, and the APK installs and launches on a physical phone.
- Spike shows bytes exchanged phone-to-phone with the chosen package.
- 🔒 **Stop. Phase report + APK. Phase 1 needs `APPROVED: Phase 1`.**

---

### Phase 1 — Protocol core and multi-node simulator (pure Dart)
**Goal:** the mesh protocol exists and is provably correct before it touches a radio.
**PS criteria:** C1, groundwork for C3, C7, C11 and C12

**Scope**
- Versioned envelope (header + body), canonical encoding and schema validation.
- Message limits: payload cap, TTL/hop cap, message IDs, dedupe cache (bounded, persisted), expiry.
- Ed25519 identity generation and signing/verification, using the library chosen in Phase 0.
- `MeshTransport` interface. `MeshAgent` handles forwarding, split horizon, per-peer token-bucket rate limits, ACKs and bounded retries with backoff.
- Event log per SOS with Lamport clocks. Only the data structure in this phase; merge policy comes in Phase 6.
- **In-memory simulator:** N virtual nodes running the *real* `MeshAgent` code over a simulated radio graph, with controllable topology, link loss and partitions. It is the test harness now and the Red Team / demo engine later.
- Hive CE storage with generated adapters: inbox, outbox, event log, peers, settings.

**Deliverables:** `lib/core/protocol/*`, `lib/data/mesh/*`, `lib/sim/*`, protocol test suite.

**Exit criteria**
- A 20-node simulated chain/grid delivers a message end to end.
- Message count stays bounded: no amplification beyond the TTL/dedupe bound. Asserted in a test.
- Tampered, oversized, replayed and malformed envelopes are rejected (tests).
- The outbox survives a simulated restart (test).
- APK builds and installs; the skeleton UI is unchanged.
- 🔒 **Stop. Phase report + APK. Phase 2 needs `APPROVED: Phase 2`.**

---

### Phase 2 — Victim/Responder flows, triage and capability parsing (local-only)
**Goal:** a person can create an SOS and a responder can build a profile, with honest local states. The text understanding asked for in the PS works offline.
**PS criteria:** C2, C6, groundwork for C8 and C10

**Scope**
- Role selection (Victim / Responder / Diagnostics), persisted.
- **Victim screen:**
  - pulsing SOS glyph, bounded text input, optional location (accuracy and freshness shown), real battery reading;
  - honest statuses: `SAVED LOCALLY — NOT YET SENT`, `WAITING FOR A NEARBY PEER`.
- **Responder profile:** free-text capability claims ("has a boat", "nurse", "can do dialysis", "boat hai") parsed into an ontology. Shown as **self-declared, unverified** until Phase 4 credentials.
- **Triage engine:**
  - urgency CRITICAL / HIGH / LOW / UNKNOWN, multiple needs, rule IDs and a justification;
  - negation and ambiguity send the report to NEEDS REVIEW;
  - code-mixed lexicon (insulin, dawa, madad, pani, bachao, …), Unicode/case normalization, fuzzy matching for misspellings.
- **Capability matcher:** need ↔ capability ontology, e.g. insulin → medical/diabetes; flooded → water rescue/boat.
- D3 stretch: on-device embedding fallback, only if approved.
- Test corpus: the PS example "Need insulin for dad, ground floor flooded" → CRITICAL, needs {Medical, Water rescue}. Plus the PRD §6.4 cases and new-disaster phrasing.

**Deliverables:** four screens wired to local state (Diagnostics minimal), triage + capability modules, table-driven tests.

**Exit criteria**
- The PS example produces the expected structured output (test).
- Unknown text produces NEEDS REVIEW, never LOW (test).
- Capability parsing passes the code-mixed corpus at the agreed accuracy (target set in the phase report).
- Triage latency is measured on a physical phone and reported (no claim without a measurement).
- APK: a full local victim → saved, and responder → profile flow on device.
- 🔒 **Stop. Phase report + APK. Phase 3 needs `APPROVED: Phase 3`.**

---

### Phase 3 — Real P2P radio mesh on devices
**Goal:** SOS messages travel phone → phone → phone with no internet.
**PS criteria:** C1, C14, groundwork for the C12 battery-drain defense

**Scope**
- Transport adapter over the package chosen in D2, behind `MeshTransport`: advertise, discover, connect, send, receive, disconnect, error handling.
- **Android foreground service** (correct `foregroundServiceType` for Android 14+), so relaying continues with the screen locked. Where the OS still stops it, the UI says so.
- Permissions: the minimum correct set for the chosen transport and target SDK, requested at the moment they are needed. Denied, revoked, BT-off, Wi-Fi-off and location-off each get a clear state.
- **Responder beacons:** periodic signed beacon carrying capabilities, battery claim, coarse location and availability.
- **Battery-aware relay policy** from §2.8, based on real `battery_plus` telemetry.
- Live topology view: neighbors, link state, last seen. Real values only.
- Victim statuses progress honestly: `SENT TO PEER` → `PEER ACKNOWLEDGED`.

**Deliverables:** transport adapter, foreground service, permission flow, topology screen, device test log.

**Exit criteria (physical devices)**
- **3 phones in airplane mode (BT/Wi-Fi on), arranged A — B — C** so that A and C are out of range: an SOS from A reaches C via B. Video or log as evidence.
- Relay keeps working with B's screen locked (or the documented OS limitation is shown in the UI).
- A battery-drain flood from one peer is rate-limited (simulator test + device log).
- APK installed on all test phones.
- 🔒 **Stop. Phase report + APK. Phase 4 needs `APPROVED: Phase 4`.**

---

### Phase 4 — Identity, trust anchors, Sybil defense and privacy
**Goal:** trust is computed by the receiver from verifiable evidence, and sensitive data is unreadable to relays.
**PS criteria:** C3, C7, the C12 forged-credential defense

**Scope**
- **Trust anchors (D4):** a mock authority app/screen (labeled DEMO AUTHORITY) issues signed responder credentials by QR. Responders import them, and receivers verify the signature against the anchor keys.
- **Credential model:** role (nurse, doctor, boat operator, …), expiry, revocation list propagated over the mesh.
- **Sybil defenses (§2.1):** physical-link collapse and cap, bounded vouching, identity age, behavior penalties. Output: trust score `T` + reasons.
- **Encryption (§2.4):** sealed per-recipient body using the library verified in Phase 0, minimal cleartext header, D5 fallback behavior. Keys are stored in the Android Keystore through secure storage, never in plain Hive.
- Security status in the UI: `VERIFIED CREDENTIAL`, `UNVERIFIED PEER`, `ENCRYPTED TO 3 RESPONDERS` / `SHARED OPENLY (no responder keys known)`.
- Write ADR-002 in full: threat model, key lifecycle, visible metadata, limits.

**Deliverables:** identity/credential/trust modules, QR enrollment, encryption integration, ADR-002.

**Exit criteria**
- A forged credential (wrong signer, expired, revoked) is rejected (tests + device).
- 40 identities behind one simulated endpoint collapse to one physical node, and their nurse claims carry no credential weight (simulator test).
- A relay phone cannot read the sealed body. Shown with a relay-side debug dump of ciphertext only, with no plaintext in its logs.
- APK: an enrolled responder on device shows a verified badge, and an unenrolled one shows unverified.
- 🔒 **Stop. Phase report + APK. Phase 5 needs `APPROVED: Phase 5`.**

---

### Phase 5 — Probabilistic evaluation chain and distributed dispatch
**Goal:** the right responder gets a convincing, targeted offer, and only a human decision moves anyone.
**PS criteria:** C4, C5, C8, C9, C10, C13, C14, the C12 floodwater-lure defense

**Scope**
- One domain pipeline in strict order (§2.5): **Claim Verification → Hazard Avoidance → Trust Scoring → Battery/Routing Cost → Safe Dispatch**. Every stage returns a score + reason codes.
- Claim verification: location plausibility (§2.2), decoy likelihood (§2.3).
- Hazard reports: create, sign, propagate, corroborate, decay. Path/target hazard check and capability gating.
- **Deterministic scarcity-weighted matcher** (§2.6): targeted offers, offer window rollover, stand-down on accept.
- **Responder offer card:**
  - urgency, needs, report age, location confidence, hazard warnings;
  - every chain stage score, the **one-line justification**;
  - `[ ACCEPT ]` / `[ REJECT ]`.
- Responder progress: `EN_ROUTE` → `ON_SCENE` → `RESOLVED`, plus heartbeats.
- **Victim statuses:** `RESPONDER ACCEPTED — DEPARTURE NOT CONFIRMED`, then `EN ROUTE`, then `ON SCENE`.

**Deliverables:** pipeline + matcher + hazard modules, offer card, justification generator, scenario tests.

**Exit criteria (scenario tests in the simulator, then on devices)**
- **Opportunity cost:** 1 medic, 1 minor SOS, 1 critical SOS → the medic is offered the critical one; the minor one goes to a general responder.
- **Bystander:** with 10 responders, at most the top 1–2 get the offer. An ignored offer rolls over after the window, with no auto-accept.
- **Floodwater lure:** an SOS inside a high-confidence flood zone is offered only to boat-capable responders, with the hazard shown.
- **Spoofed location:** a claim 5 km from a 1-hop relay gets low `P_location` and is flagged.
- **The PS example, end to end:** insulin, flooded ground floor, drifting GPS, 12% battery. It produces a correct offer with a justification on a responder phone.
- Every chain stage is visible in the UI for each candidate.
- APK on 3 phones: victim → relay → responder accept loop works.
- 🔒 **Stop. Phase report + APK. Phase 6 needs `APPROVED: Phase 6`.**

---

### Phase 6 — Partition reconciliation
**Goal:** disconnected islands resolve the same emergency independently and converge safely when they reconnect.
**PS criteria:** C11

**Scope**
- Merge policy over the signed event logs (§2.7): set union, deterministic precedence, never cancel ON_SCENE, conflict state when two responders are both on scene.
- Orphan detection by heartbeat timeout → reopen → re-match.
- **Sync on reconnect:** exchange event-ID summaries, pull the missing events, validate, dedupe, apply.
- UI:
  - `STAND DOWN — another responder is on scene`;
  - `STATUS CONFLICT — RECONCILIATION REQUIRED`;
  - a reconciliation report with real counts.
- Partition control in the simulator, plus a real partition (separate phones physically).

**Deliverables:** reconciliation service, sync protocol, conflict UI, ordering test suite.

**Exit criteria**
- Convergence: every ordering of a fixed event set produces the same final state (property test).
- **Double-dispatch:** two islands each accept the same SOS → after the merge, exactly one keeps it. The ON_SCENE one always wins and is never cancelled.
- **Orphan:** the assigned responder goes silent → the SOS reopens after T and is re-offered.
- **Device test:** 3–4 phones split into two islands, both accept, rejoin → reconciliation shown on screen.
- The reconciliation report shows counts calculated from the merge, never a constant.
- 🔒 **Stop. Phase report + APK. Phase 7 needs `APPROVED: Phase 7`.**

---

### Phase 7 — Red Team Hour and diagnostics
**Goal:** every attack named in the PS can be injected live, and the defenses visibly hold.
**PS criteria:** C3, C4, C5, C12 (full), C14

**Scope**
- **Diagnostics screen** with a persistent **SIMULATION MODE** banner. Every attack is a real injected message going through the real pipeline:
  - `[ INJECT SYBIL: 40 NURSES ]`
  - `[ FORGED MEDICAL CREDENTIAL ]`
  - `[ SPOOFED LOCATION ]`
  - `[ DECOY EMERGENCY ]`
  - `[ FLOODWATER LURE ]`
  - `[ BATTERY-DRAIN FLOOD ]`
  - `[ TOGGLE PARTITION ]`
  - `[ RESET SIMULATION ]`
- Each attack shows its outcome: blocked / quarantined / flagged, the reason codes and the affected counts.
- **Simulator visualizer:** a virtual-node mesh graph (labeled SIMULATION) running the real protocol, so judges can watch 30–50 nodes, partitions and attacks on one phone.
- Simulated battery override, kept separate from the real battery display.
- Global status drawer on all screens: role, transport (real/sim), peer count, battery (real and override), permissions, queue counts, key readiness, redacted event log, reconciliation summary.

**Deliverables:** diagnostics screen, attack injectors, visualizer, drawer, Red Team test suite.

**Exit criteria**
- Each attack has (a) an automated test asserting the defense and (b) a visible on-device outcome.
- Simulation data never pollutes real records (test: inject → reset → real data unchanged).
- Red Team rehearsal script written and run once on devices.
- 🔒 **Stop. Phase report + APK. Phase 8 needs `APPROVED: Phase 8`.**

---

### Phase 8 — Hardening, release APK and demo
**Goal:** a signed, installable release APK and a rehearsed demo backed by honest evidence.
**PS criteria:** C15 (final), re-verification of all others

**Scope**
- Release signing with a team keystore. The keystore and passwords stay out of git.
- R8/ProGuard rules for the plugins; `--split-per-abi` builds plus one universal APK.
- Size check.
- Permission review against the actual APIs used.
- Privacy pass over logs, fixtures and UI.
- Accessibility pass: text scaling, semantics, reduced motion.
- Performance: cold start, triage p95, and relay battery profile on a low-end phone.
- `docs/VERIFICATION_REPORT.md` with these sections: Implemented, Verified by automated tests, Verified on physical devices, Not verified, Security limitations, Known risks/release blockers, How to run.
- README: setup, build, install (`adb install`), demo script.
- Demo script: victim SOS → multi-hop → targeted offer with justification → accept → partition → merge → Red Team attacks.

**Exit criteria**
- `flutter build apk --release` succeeds. The signed APK installs on a **clean** phone that never had a debug build, and passes the full demo.
- Every C1–C15 row in §1 has filled-in evidence, or is explicitly marked not verified with a reason.
- 🔒 **Stop. Final report. The MVP is complete only when the owner signs off.**

---

## 6. Phase dependency map

```
P0 ──► P1 ──► P2 ──► P3 ──► P4 ──► P5 ──► P6 ──► P7 ──► P8
              (local)  (radio)  (trust)  (chain)  (merge)  (red team)
```

The order is strict because each gate needs the previous phase approved and done. P2 could technically run alongside P1, but under the gate rule it runs only after P1 approval, unless the owner explicitly approves both together in writing.

## 7. Cut line if time runs short

If D8 shows a tight deadline, the minimum demo that still touches every PS criterion is:
- P0–P3 in full.
- P4 with credentials, Sybil link-collapse and sealed body. Skip revocation.
- P5 in full. This is the core of the PS.
- P6 with double-dispatch + never-cancel-on-scene. Orphan reopen may be simulator-only.
- P7 with Sybil, forged credential, floodwater lure, battery drain and partition. Decoy and spoof may be simulator-only.
- P8 with a signed release APK + demo. Reduced performance profiling.

Anything cut is listed in the verification report as **Not verified**, never hidden.

## 8. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| The Nearby package is stale or buggy on newer Android | Radio phase slips | Phase 0 two-phone spike before committing; transport behind an interface |
| Background relaying killed by OEM battery savers | Locked phones stop relaying | Foreground service + documented limitation + battery-optimization exemption prompt |
| Few physical phones | Can't prove multi-hop or partition | Need at least 3 phones (D8). The simulator covers scale but never replaces device proof |
| Crypto library or Flutter plugin incompatibility | Privacy criterion at risk | Library verified in Phase 0. Fallback is signing-only with a visible "NOT ENCRYPTED" status |
| Code-mixed text coverage is weak for novel disasters | Zero-shot criterion judged weak | Expandable lexicon + fuzzy matching + NEEDS REVIEW. D3 embedding stretch |
| No Flutter SDK on the dev machine today | Phase 0 blocked until installed | First task of Phase 0 |

## 9. Phase report template (required at every gate)

```markdown
# Phase N Report — <title>
Date:
Branch / commit:
APK: <path>, versionName 0.N.0, versionCode X, size Y MB, installed on: <devices + Android versions>

## Done
## PS criteria advanced (update §1 Evidence column)
## Commands run and results
- flutter analyze: …
- flutter test: N passed / M failed
- flutter build apk --debug: …
## Device tests performed
## Not done / not verified (and why)
## Decisions taken (ADR links) / decisions needed from owner
## Known issues and risks
## Request
Awaiting `APPROVED: Phase N+1`. No Phase N+1 work has started.
```
