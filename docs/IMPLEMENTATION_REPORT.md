# RESQ — Implementation Report, Phases 1–8

**Date:** 2026-10-25
**Status:** **IMPLEMENTED — NOT VERIFIED.** The owner instructed: implement every phase first, and test only with their permission. No build, analyzer run, test run or device check has been done on the Phase 1–8 code. One static analysis pass ran partway through, covering the core layers only; it found 4 minor issues and no errors, and they were fixed. Everything written after that point is unanalysed.

---

## 1. Architecture in one paragraph

Every phone runs one **`ResqNode`** (`lib/node/resq_node.dart`), and the simulator runs dozens of the same class.

- **Inputs:** signed envelopes (`lib/protocol/envelope.dart`) arriving through a `MeshTransport`: real Nearby Connections (`lib/mesh/nearby_transport.dart`) or a simulated radio (`lib/mesh/sim_transport.dart`).
- **Ingest pipeline, per frame:** link flood guard → strict schema/size/TTL validation → dedupe → Ed25519 signature check → per-type validation → apply to event-sourced knowledge → ACK → battery-aware, rate-limited relay → persist to Hive.
- **Decisions:** pure-Dart agents over a read-only `WorldView`: triage, capability parsing, trust, the five-stage evaluation chain, the scarcity-weighted matcher, the reconciler and the power policy.
- **Presentation:** the Riverpod UI renders node state only.

## 2. Problem-statement traceability

| ID | PS criterion | Where it is implemented | Proof prepared (not yet run) |
|---|---|---|---|
| C1 | Decentralized, P2P only | `nearby_transport.dart`, multi-hop relay + store-and-forward replay in `resq_node.dart` (`_onFrame`, `_onPeerConnected`) | `red_team_test.dart` (multi-hop in sim); device test pending |
| C2 | Fragmented, untrusted, constrained input | `triage_agent.dart`; GPS accuracy/age in `LocationFix`; battery claims; the PS example seeded in `Simulator.seedEmergencies` (±120 m, 12% battery) | `triage_test.dart` first case |
| C3 | Sybil resistance | `trust_agent.dart`: link collapse (≥3 identities per link), co-location cluster, credential-gated trust | `Simulator.attackSybil`, `red_team_test.dart` |
| C4 | Location spoofing | `claim_verifier.dart`: (h+1)×300 m plausibility, velocity | `Simulator.attackSpoofedLocation` |
| C5 | Decoy emergencies | `claim_verifier.dart`: corroboration, reporter trust, repeated reports → SUSPECTED DECOY (kept, flagged) | `Simulator.attackFloodLure` (decoy flags) |
| C6 | Zero-shot, code-mixed capability matching | `capability_parser.dart` + `capabilityFit` table in `models.dart` | `triage_test.dart` capability group |
| C7 | Privacy through untrusted relays | `sealed_box.dart` (age-style multi-recipient), minimal cleartext header; D5 choice in `submitSos` | `protocol_test.dart` sealed-box test |
| C8 | Distributed triage, opportunity cost | `matcher.dart` scarcity weighting | `matcher_test.dart` "only medic → critical" |
| C9 | Bystander effect | One primary offer per SOS; offer-window rollover in `ResqNode.tick` | `matcher_test.dart` bystander + rollover |
| C10 | One-line HITL justification | `Justifier` in `evaluation_chain.dart`; `_OfferCard` with explicit ACCEPT/DECLINE | Simulated humans in `Simulator._simulatedHumans` |
| C11 | Partition merge: double dispatch, orphans, never cancel at the door | `reconciler.dart`, Lamport events, heartbeats | `reconciler_test.dart`, `Simulator.partitionDoubleDispatchScenario` |
| C12 | Red Team Hour: forged credentials, battery drain, flood lure | `ResqNode._applyBeacon` (forgery → quarantine), `FloodGuard`, hazard gate | `Simulator.attack*`, Diagnostics › RED TEAM SIM |
| C13 | Probabilistic chain, in order | `EvaluationChain.evaluate` (5 stages) | `matcher_test.dart` stage-order test |
| C14 | Battery and topology | `power_policy.dart`, real `battery_plus`, topology in Diagnostics › DEVICE and the sim map | — |
| C15 | Installable APK | Manifest, foreground service, release signing, R8, `scripts/build_apk.ps1` | Build pending owner approval |

## 3. Phase-by-phase summary

| Phase | Delivered |
|---|---|
| 1 Protocol + simulator | Envelope, canonical JSON, limits, dedupe, token buckets, Ed25519 identities, Hive store with replay, in-memory radio, `Simulator` |
| 2 Flows + triage | Role selection; Victim screen (pulse glyph, live triage preview, opt-in location, privacy choice, honest statuses, cancel); responder capability profile; triage + capability parser |
| 3 Real radio | `NearbyTransport`; Kotlin `MeshForegroundService`; Nearby permission set; permission flow on TURN ON MESH; signed beacons; battery-aware relay |
| 4 Trust + privacy | Authority mode (DEMO), in-person fingerprint pinning, credential issue/revoke, vouching, forgery quarantine, Sybil heuristics, sealed SOS bodies, keys in Keystore-backed storage |
| 5 Chain + dispatch | Five-stage chain, hazard reports/zones, matcher, offer cards with per-stage scores, progress EN ROUTE → ON SCENE → RESOLVED, heartbeats |
| 6 Reconciliation | Deterministic fold, stand-down, never-cancel-on-scene, orphan reopen, computed reconciliation report, partition scenario |
| 7 Red Team + diagnostics | Simulator tab with live map, Sybil / forged-credential / spoofed-location / flood-lure / battery-drain attacks with measured outcomes, battery override, partition toggle, reset; global status drawer |
| 8 Hardening | Release signing from `key.properties`, keystore script, R8 rules, split-per-ABI builds, ADR-001…006, verification report, demo script, README |

## 4. Deviations from the plan

- **The transport spike was not run (D2 is provisional).** `NearbyTransport` uses `nearby_connections` on the strength of API and build-compatibility evidence only.
- **Hive with versioned JSON instead of generated adapters.** This avoids a code-generation step and keeps migrations explicit (ADR-006).
- **The QR camera flow is replaced by fingerprint comparison over a direct radio link.** This avoids a camera/ML dependency; in-person confirmation is still required.
- **Red Team attacks run only in the simulator.** The real device is never polluted with attack data, which satisfies the "simulation isolation" rule.

## 5. Known risks before testing

- **Compile errors are possible.** All code since the core-layer analysis is unanalysed. `flutter analyze` is the first step of verification.
- **Simulator speed.** It runs on the UI isolate. With about 25 nodes doing pure-Dart Ed25519, steps may take hundreds of milliseconds.
- **Nearby on the actual test phones is unproven** (OEM differences, connection limits).
- **Untuned heuristics.** Thresholds (decoy 0.35, hazard gate 0.6, radio range 300 m) are reasoned defaults, not tuned values.
