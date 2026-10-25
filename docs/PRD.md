# SAFE-NET v1.0 — Master Product Requirements Document

**Product:** SAFE-NET — The Human-Powered Emergency Network  
**Document type:** Product, engineering, safety, and acceptance specification  
**Version:** 1.0.0  
**Status:** Implementation baseline / release candidate specification  
**Primary client:** Flutter mobile app; Android-first implementation  
**Connectivity model:** Local-first, peer-to-peer, no mandatory cloud backend  
**AI/ML policy:** No ML/LLM inference in the operational decision path  
**Visual reference:** `reference_product_brief.png` (the attached “The Human-Powered Emergency Network” brief)

---

## 0. Read this first: product promise and boundaries

SAFE-NET is an **offline-first emergency coordination application** that lets a person create a structured distress report, lets nearby peers propagate it over available local links, and lets suitable responders review and voluntarily accept or reject it. It must preserve reports locally through disconnections, represent uncertainty honestly, protect sensitive information, and expose diagnostic simulations for testing adversarial conditions.

“Production-ready V1” means professional engineering quality, deterministic behavior, security-conscious implementation, recoverable local data, real-device testing, accessibility, observability without leaking sensitive data, and a reproducible build. It **does not** mean this application is certified, clinically validated, guaranteed to deliver an SOS, capable of verifying a person's physical identity from a device ID, or safe to deploy as the sole emergency-response channel. Real-life deployment remains gated on security review, field trials, threat-model review, protocol validation, and relevant emergency/medical stakeholder approval.

### Non-negotiable safety statements

1. SAFE-NET is an auxiliary coordination tool, not a replacement for local emergency services or established rescue procedures.
2. No app should tell a victim that help is on the way unless a responder acceptance event has been received and validated. Acceptance still does not mean the responder physically departed or arrived.
3. A local write, a successful radio send, a peer acknowledgement, an acceptance, an en-route report, and an arrival report are distinct facts. Never conflate them.
4. Unknown or ambiguous distress reports must not be silently downgraded to harmless/LOW priority solely because a keyword rule did not match.
5. No safety-critical decision may trust `trustScore`, `isSpoofed`, role, capability, GPS, battery, or timestamp fields merely because an incoming message claims them.
6. No timer may automatically accept or dispatch a responder. A timeout is a timeout, not consent.
7. A JSON string saying `"encryption":"E2E_AES_256"` is not encryption. Do not display or log “encrypted” unless cryptographic protection is actually active and verified for the message path in question.
8. Demo data, simulated GPS, forced battery levels, injected attackers, and simulated partitions must be visibly marked as simulation and must never be confused with real observations.
9. The application must never claim guaranteed delivery, flawless triage, complete Sybil prevention, or zero latency.
10. If the platform or available dependencies cannot provide a security or delivery guarantee, show the limitation, preserve recoverable state, and fail safely rather than fabricating success.

---

## 1. Product vision

### 1.1 Problem

During a flood, tower outage, or other disaster, capable nearby citizens may be stranded within kilometers of people who need help. Centralized dispatch systems can become unavailable; internet access, trusted identities, accurate GPS, responder availability, and battery power may all be uncertain. A practical application must coordinate using available device-to-device links without assuming a central server is reachable.

### 1.2 Product vision

Build a local-first, human-supervised, multi-agent coordination client that:

- lets victims submit a short plain-language request;
- deterministically derives a preliminary urgency and need recommendation from the text;
- stores reports durably on-device;
- discovers and communicates with nearby peers where supported;
- forwards reports with bounded retries and deduplication;
- displays responder suitability evidence and uncertainty;
- preserves independent decisions across temporary network partitions;
- resolves repeated and conflicting events deterministically;
- adapts discovery and forwarding as battery power falls;
- provides a diagnostics mode for adversarial and offline-state exercises; and
- follows the reference brief’s evaluation order: **Claim Verification → Hazard Avoidance → Trust Scoring → Battery/Routing Cost → Safe Dispatch**.

### 1.3 Intended users

**Victim / help seeker:** A person who needs assistance and can provide a short description and optional location.

**Responder:** A person who can consider local requests and who should only be matched to tasks consistent with their verified/declared capabilities, current availability, safety, and equipment.

**Diagnostics operator:** A developer, evaluator, trainer, or authorized tester who intentionally injects test messages and simulates radio partitions and battery constraints.

### 1.4 Design principles

- Offline-first, not “offline-looking.”
- Human decision, not autonomous dispatch.
- Deterministic rules, transparent explanations.
- Fail-safe under uncertainty; do not hide uncertainty.
- Data minimization and explicit retention.
- Bounded network work and energy use.
- Idempotent operations and recoverable state.
- Explicit distinction between simulated and observed conditions.
- No centralized authority required for routine local message forwarding; local identity bootstrap and capability trust still require an explicitly documented trust model.

---

## 2. Scope

### 2.1 V1 must include

1. Role selection: Victim, Responder, Diagnostics.
2. Black/white Nothing-style operational UI using Roboto Mono, square corners, no gradients, no rounded cards, and no color-only status communication.
3. Victim SOS composition and locally durable submission.
4. Pure Dart rule-based triage, with compiled regexes and deterministic output.
5. Local Hive persistence, generated adapters, repository boundaries, and schema/version handling.
6. Device battery monitoring and energy-aware discovery/forwarding policy.
7. Peer discovery and peer messaging through the selected nearby-connections library, behind a transport interface.
8. Explicit application-level forwarding, acknowledgement, deduplication, expiry, retry limits, and delivery-state reporting.
9. A documented security protocol and key/identity enrollment decision. No custom cryptography claimed to be secure without review.
10. A responder evaluation pipeline in the order established by the reference image.
11. Manual Accept / Reject controls for eligible requests; no auto-accept.
12. Simulated diagnostics: attack injection, network partition toggle, battery drain override, and visible simulation status.
13. A global diagnostics/status drawer accessible from every primary screen.
14. Graceful permission denial, unsupported transport, radio-off, restart, app interruption, and local storage failure behavior.
15. Automated unit, repository, widget, protocol, and state-machine tests, plus a documented physical-device test plan.
16. Build/run instructions, architecture decision records (ADRs), known limitations, and an honest verification report.

### 2.2 Not in V1 unless the existing repository already provides it and it can be verified

- A centralized cloud dispatch backend.
- A guaranteed citywide or unlimited-range mesh.
- Satellite connectivity or SMS fallback.
- Medical diagnosis or clinical recommendations.
- Automatically verified professional credentials.
- Automatic routing through live maps or live hazard feeds without a defined data source.
- Autonomous responder movement or autonomous dispatch.
- Guaranteed background operation across every OEM's power-management policy.
- Full iOS release readiness without equivalent permission, lifecycle, transport, and real-device validation.
- Claims of certified disaster-grade reliability.

### 2.3 Platform baseline

Implement Android first because the requested manifest, Bluetooth, Wi-Fi Direct, and location requirements are Android-specific. Keep Dart/domain layers platform-neutral where sensible. Do not claim iOS support merely because a dependency lists iOS. Confirm plugin support, entitlements, runtime permissions, and real-device behavior before including iOS in release scope.

---

## 3. Visual/product reference requirements

Use `reference_product_brief.png` as the primary reference for product intent, vocabulary, content hierarchy, adversarial cases, and evaluation order.

### 3.1 Reference content that must shape the product

- True responder availability and physical capability vs stale claims.
- Trustworthiness of distress calls vs decoys.
- Dynamic hazard zones and safe routing.
- Actual battery life and device-to-device topology.
- Triage urgency across competing, unverified victims.
- Adversarial resilience against Sybil attacks, location spoofing, and malicious decoys.
- Zero-shot capability matching for open-vocabulary and code-mixed claims, implemented in V1 by transparent deterministic rules rather than ML.
- Privacy when forwarding through untrusted relay nodes.
- Distributed triage and the bystander effect.
- Human-in-the-loop acceptance based on clear, plain-language explanations.
- Partition/merge reconciliation and a Red Team Hour test flow.

### 3.2 Visual hierarchy

The image uses charcoal texture, amber/yellow headings, magenta accents, and white body text. The explicit operational UI directive for this app takes precedence: **pure black `#000000`, pure white `#FFFFFF`, Roboto Mono, square corners, no gradients, no rounded corners, and no decorative floral background in operational screens**. Keep the reference image as a product/content reference, not as a literal screen background. If a marketing/splash treatment uses accents, it must not bleed into operational emergency views.

### 3.3 Design tokens

- Background: `#000000`.
- Foreground / primary text: `#FFFFFF`.
- Secondary text: white with reduced opacity where accessible.
- Borders/dividers: white or neutral gray, with sufficient contrast.
- Critical alert: communicate with explicit text/icon/border and accessible semantics; a warning may use red only in Diagnostics if that is kept as an explicitly approved exception, but do not rely on color alone.
- Typography: Roboto Mono throughout app content; verify a suitable packaged/system font and include assets only if licensing and build setup are correct.
- Geometry: 0 radius; no rounded cards or pill buttons.
- Motion: restrained glyph/dot-matrix pulses via `flutter_animate`; respect platform reduced-motion/accessibility settings; never animate away critical content.
- Touch targets: meet platform accessibility guidance; keep primary emergency actions large and clearly labeled.

---

## 4. Primary user journeys

### 4.1 First launch and role selection

1. Show SAFE-NET identity and a short plain-language explanation that it is an auxiliary tool and does not guarantee rescue.
2. Let the user choose `[ VICTIM ]`, `[ RESPONDER ]`, or `[ DIAGNOSTICS ]`.
3. Persist the role locally. Allow role changes via settings/diagnostics with appropriate safeguards.
4. Explain nearby-device, location, and notification permission needs at the moment they become relevant. Never treat permission denial as an app crash.
5. Do not silently request all permissions at first launch. Request only those required for a user-visible feature.
6. Expose whether the app is running with real transport, limited transport, or simulation.

### 4.2 Victim creates an SOS

1. Show one primary action with a pulsing white glyph/circle, a plain-language text field, and a clear send action.
2. Allow a text report and an optional location. Validate length and reject empty input; keep the input bounded to reduce resource exhaustion.
3. Read battery level through the platform adapter. If unavailable, represent it as unknown rather than inventing a value.
4. Get location only after permission and user-visible rationale; represent source, timestamp, and accuracy in the extended metadata. Do not label dummy coordinates as real.
5. Run TriageAgent synchronously with bounded input and deterministic rules.
6. Generate a unique SOS ID; create the `SOSMessage`; persist it locally before telling the user it is saved.
7. Add an outbox entry. When a usable peer is available, encrypt/authenticate according to the approved protocol and attempt bounded forwarding.
8. Show precise states: **SAVED LOCALLY**, **WAITING FOR PEER**, **SENT TO PEER**, **ACKNOWLEDGED BY PEER**, **RESPONDER ACCEPTED**, **EXPIRED**, or **DELIVERY ERROR** as applicable. The UI must not imply network delivery after only a local write.
9. If an acceptance event is validated, display **RESPONDER ACCEPTED — EN ROUTE NOT CONFIRMED** unless a separate en-route event exists.
10. Permit the user to view the request status and cancel/withdraw when policy allows. Preserve a safe audit trail while minimizing sensitive retention.

### 4.3 Responder receives and evaluates an SOS

For every new message, apply the sequence below in the domain layer and return a structured outcome. Widgets must not implement their own ad hoc version of the rules.

**Stage 0 — Transport/schema safety:** bound packet size, validate schema/version, decode safely, authenticate/decrypt as applicable, reject tampered payloads, check freshness and replay rules, deduplicate, and persist accepted incoming events.

**Stage 1 — Claim verification:** separate sender-asserted fields from local verification results. An incoming `isSpoofed` value or trust score is not authoritative. Unknown identities remain unknown/unverified and follow a conservative policy; avoid a default trust score that automatically makes unknown nodes trusted.

**Stage 2 — Hazard avoidance:** evaluate available, dated hazard and location evidence. If no hazard feed is available, say “hazard data unavailable”; do not imply a route is safe. Location is an estimate, not physical proof.

**Stage 3 — Triage and trust:** run deterministic triage and receiver-side trust evaluation. Critical/high requests may be surfaced for human consideration when their policy gates are met. LOW requests should not automatically divert scarce medical responders from higher-priority requests, but do not silently delete them. Ambiguous/unknown triage must show **NEEDS HUMAN REVIEW** or another conservative state, not be silently mapped to harmless LOW.

**Stage 4 — Capability and routing cost:** compare request needs to responder capabilities, the verification status of those capabilities, availability, approximate proximity only when location is permitted and sufficiently fresh, current device battery, connection quality, and known route constraints. Do not claim a responder is qualified from `role == 'Responder'` alone.

**Stage 5 — Human-in-the-loop decision:** show a stark, white-bordered card containing request ID, urgency, needs, report age, location and its confidence/freshness, battery if known, concise rule/trust rationale, verification state, and delivery freshness. Provide explicit `[ ACCEPT ]` / `[ REJECT ]` controls for eligible cases. Rejection may optionally capture a short reason. Acceptance must be atomic locally, persisted as an event, and then propagated. If a concurrent acceptance appears after a partition, show a conflict state and do not claim exclusive ownership until reconciliation policy resolves it.

**15-second timer:** treat it as a visual response window / timeout indicator only. It must never auto-accept, auto-reject, delete the request, or claim a dispatch occurred. It may mark an unattended item “UNANSWERED” and keep it queued for another responder according to local policy.

### 4.4 Responder low-priority handling

For a valid LOW request, display a non-destructive explanation such as: “LOW PRIORITY — current critical resources remain prioritized. This request is retained for review.” Do not show the medical Accept action if policy says it should be withheld from medical-only responders, but make the request available to appropriate general responders and preserve it until expiry or explicit closure. Do not imply that all low-urgency requests are safe or unimportant.

### 4.5 Diagnostics / Red Team Hour

The Diagnostics screen must have a persistent **SIMULATION MODE** label and the following actions:

- `[ INJECT SYBIL TEST ]`: create a clearly synthetic `SOSMessage` with a locally known test identity/outcome or forged incoming claim. Verify that receiver-side identity/trust checks, not the payload's self-report, block or quarantine it. Do not use this as proof that all real Sybil attacks are prevented.
- `[ TOGGLE NETWORK PARTITION ]`: simulate a transport partition. Stop simulated send/receive at the transport boundary; enqueue new outgoing events durably; permit local UI operations; then restore links and run the same delivery/deduplication/reconciliation logic used by real transport.
- `[ DRAIN BATTERY ]`: set a test-only PowerAgent override; the UI must show **SIMULATED BATTERY OVERRIDE** separately from the physical battery value. Never alter or falsify the actual reading.
- Provide `[ RESET SIMULATION ]`, test event history, and clear simulation state after explicit confirmation.
- Every diagnostics action must produce a visible outcome and a testable state change. No inert buttons.

### 4.6 Global diagnostics drawer

Accessible from all primary screens. Include:

- app version/build and protocol version;
- selected role;
- real vs simulated transport indicator;
- nearby peer count and last transport event, without exposing peer-sensitive data;
- battery level and low-power policy state;
- permission status with a route to OS settings where appropriate;
- durable outbox/inbox counts;
- partition simulation toggle;
- encryption/key readiness state (never display private keys);
- redacted event log;
- reconciliation summary and conflicts count.

When simulated partition is ON, display **OFFLINE: QUEUING LOCALLY**. When OFF, do not immediately claim “0 conflicts” as a constant; show an actual reconciliation result and only report zero conflicts if the run genuinely calculated zero conflicts. If reconciliation cannot complete, show the error/unknown state.

---

## 5. Functional requirements

IDs are normative and should be traceable to code/tests.

### Product and role requirements

- **FR-001:** App launches into role selection when no role is saved; otherwise resume the saved role with an accessible way to switch.
- **FR-002:** All primary flows work with no internet connection; cloud access is not required for local storage or local transport.
- **FR-003:** Permission denial, radio-off, unsupported hardware, and no-peer conditions produce useful states, not crashes.
- **FR-004:** Simulation state is always visually distinguishable from real observations.

### SOS and triage requirements

- **FR-010:** Victim can create a non-empty bounded plain-language request.
- **FR-011:** SOS data is persisted locally before being reported as saved.
- **FR-012:** Rule-based triage is deterministic and performs no network calls or ML/LLM inference.
- **FR-013:** Triage can represent multiple potential needs and unknown/ambiguous outcomes internally; the required `Map<String, String> analyze(String text)` API may remain as a compatibility facade.
- **FR-014:** The user sees a clear explanation of the rule-based recommendation and can correct the report where safe.
- **FR-015:** Battery/location data use real readings or explicit unknown/demo values; no false telemetry.

### Networking and offline requirements

- **FR-020:** Networking is behind an interface so domain logic is independent of one plugin.
- **FR-021:** Only connected/ready peers are sent data using APIs actually exposed by the dependency.
- **FR-022:** App-level forwarding implements message ID deduplication, bounded hops/TTL, size limits, retry policy, delivery acknowledgements, and peer-session lifecycle handling.
- **FR-023:** Outbound and inbound work survive process death/restart to the extent local storage remains available.
- **FR-024:** A local save is never presented as a remote delivery.
- **FR-025:** Transport failures never silently delete an undelivered request.
- **FR-026:** Simulated partitions exercise the real queue/deduplication/state reconciliation path.
- **FR-027:** Merge handling is idempotent and deterministic for duplicate events, stale updates, and competing acceptances; unresolved conflicts are explicit.

### Security and privacy requirements

- **FR-030:** Use a maintained cryptographic protocol/library suitable for the required platform and threat model. Do not invent a custom protocol from primitives without independent review.
- **FR-031:** Define how device identity keys are created, stored, rotated, enrolled, revoked, and trusted offline. No embedded shared secret in source code or assets.
- **FR-032:** The wire payload contains actual ciphertext/authentication data when encryption is claimed; a JSON marker alone is insufficient.
- **FR-033:** Authenticated message integrity, replay handling, sender/key identification, expiry, and payload schema validation are implemented to the degree specified by the selected protocol.
- **FR-034:** A relay cannot read sensitive report content when the claimed mode is end-to-end encryption. If routing metadata remains visible, document the leakage explicitly.
- **FR-035:** Sender-supplied `trustScore`, `isSpoofed`, role, and capability claims are never accepted as receiver-side verification results.
- **FR-036:** Logs, diagnostics, crash reports, and UI telemetry redact raw victim text, private keys, precise location, and identifiers not needed for troubleshooting.
- **FR-037:** Retention and deletion rules cover active requests, expired requests, caches, queues, and event logs.

### Responder and dispatch requirements

- **FR-040:** Evaluation stages run in the prescribed order and produce machine-testable reason codes.
- **FR-041:** Critical/high recommendations display a justified, human-readable card when the applicable validation gates pass.
- **FR-042:** Low/unknown reports are retained and routed according to policy; ambiguous reports are not silently treated as safe.
- **FR-043:** Only explicit user action can accept/reject a dispatch candidate.
- **FR-044:** Timeout never implies acceptance, rejection, departure, or arrival.
- **FR-045:** Local acceptance is persisted before a UI success state is shown, and propagation is reported independently.
- **FR-046:** Competing acceptance events caused by partitions are reconciled through documented policy; the UI distinguishes tentative/local acceptance from a reconciled assignment when necessary.

### Power and diagnostics requirements

- **FR-050:** PowerAgent observes actual battery state where supported and exposes a test override separately.
- **FR-051:** Low power reduces nonessential discovery/forwarding but retains the safest feasible request receive/accept path. If the platform cannot keep scanning active, make that limitation visible.
- **FR-052:** Diagnostics controls are functional, test-only where appropriate, labeled, and resettable.
- **FR-053:** Global drawer state reflects real provider values and actual reconciliation results rather than hardcoded text.

---

## 6. Triage rules and decision design

### 6.1 Required initial keyword families

Maintain the requested baseline patterns, case-insensitively and with suitable normalization/word boundaries where appropriate:

- Medical/critical terms: `insulin`, `blood`, `breathing`, `heart`, `dialysis`, `dawa`, `madad`.
- Rescue/high terms: `trapped`, `flood`, `water`, `fire`, `boat`, `pani`, `bachao`.
- Fallback: not automatically “safe”; use `UNKNOWN/NEEDS_REVIEW` when no supported rule or confidence is insufficient. If compatibility requires `LOW`, the application must accompany it with a separate uncertainty flag and must not use the fallback alone to suppress an SOS.

The original examples of exact output maps may be preserved in a compatibility method, but the primary domain result must be structured and extensible.

### 6.2 Recommended internal result

A typed `TriageResult` should support at least:

- urgency recommendation: `CRITICAL`, `HIGH`, `LOW`, `UNKNOWN`;
- zero or more need categories;
- matched rule identifiers;
- human-readable justification;
- ambiguity/unknown flag;
- parser/ruleset version;
- whether manual review is required.

The requested public method `Map<String, String> analyze(String text)` should remain available if consumers depend on it, but it must map from the typed result rather than being the only representation.

### 6.3 Initial deterministic rules

1. Normalize unicode/case and whitespace with bounded work.
2. Check critical medical keywords first.
3. Evaluate rescue/environmental keywords too, so a report can express both medical and rescue needs.
4. Do not attempt to diagnose a disease.
5. Do not assume keyword mention is an active need; if negation/context produces ambiguity, mark it for human review rather than trying to implement natural-language understanding with fragile ad hoc logic.
6. If no rule matches, use `UNKNOWN/NEEDS_REVIEW`, or a formally documented conservative equivalent. Never auto-delete or silently classify as harmless.
7. Compile regex patterns once; enforce max input length; benchmark on low-end target hardware. `<5 ms` is a measurable target for bounded local parsing, not a promise of flawless triage or total dispatch latency.

### 6.4 Test corpus requirements

Include positive, negative, overlapping, misspelled, empty, long, code-mixed and unrecognized examples such as:

- “Need insulin urgently.”
- “Dad needs dialysis and flood water is rising.”
- “Pani aa raha hai, bachao.”
- “Boat available; can help with rescue.” (capability claim, not automatically a victim SOS)
- “I do not need insulin now.”
- “Heart disease history, no current emergency.”
- “Please help.” (unknown/needs review)
- empty and whitespace-only input;
- input over maximum allowed length;
- messages containing every keyword family.

The exact triage output must be documented in table-driven tests; tests must protect against regressions.

---

## 7. Data model and persistence

### 7.1 Required baseline Hive models

Create the requested models in the project’s models directory (normally `lib/models/`) and generate Hive adapters with the generator compatible with the repository’s installed Hive CE version. Preserve field IDs once shipped. Include generated `part` declarations and verify adapter registration at startup.

**Node**

- `id: String`
- `role: String` — baseline values: `Victim`, `Responder`, `Diagnostic`
- `trustScore: int` — 0–100; any default is not evidence that a new peer is trusted
- `isBlacklisted: bool`

**SOSMessage**

- `id: String`
- `senderId: String`
- `rawText: String`
- `urgency: String` — baseline values: `CRITICAL`, `HIGH`, `LOW`; extend compatibly for `UNKNOWN` where needed
- `need: String` — baseline values: `Medical`, `Rescue`, `Supplies`; support multi-need in a compatible extension
- `status: String` — baseline values: `SEARCHING`, `ACCEPTED`, `QUEUED`; define additional terminal/conflict states only with an explicit migration strategy
- `justification: String`
- `isSpoofed: bool` — legacy/input field only; never authoritative verification
- `gpsCoord: String` — do not assume valid/precise/recent from the string alone
- `batteryLevel: int` — add an explicit unknown representation or companion metadata instead of falsely fabricating an integer

Implement exact required constructors/fields as compatible with the existing project constraints. Use explicit enum/string mapping and validation at serialization boundaries. Never reuse Hive field IDs or silently reinterpret existing fields.

### 7.2 Additional persistence records are required

Do not overload the two baseline models to store every protocol concern. Add versioned local records as justified, such as:

- `OutboxRecord`: message ID, delivery state, attempt count, next retry, last error category, expiry, and last peer acknowledgement.
- `InboundEvent`: event ID, parent message ID, event type, sender/key ID, protocol version, event revision/causality metadata, receipt time, verification result, and payload reference.
- `PeerRecord`: locally enrolled identity key fingerprints, last seen, local trust evidence, capability evidence/expiry, blacklist reason, and enrollment status. Never persist private keys in plain Hive storage.
- `TriageRecord`: parser/ruleset version, structured decision, matched rule IDs, ambiguity and review state.
- `SimulationState`: simulation-only overrides and reset-safe test events; do not mix it with actual battery/GPS data.
- `AppSettings`: role, retention settings, scanning preferences, and relevant feature configuration.

The final schema and migrations must be documented. Keep personal report content separate from indexes/metadata where that helps retention and encryption.

### 7.3 Persistence guarantees

- Initialize local storage and register adapters before first repository use.
- Use a single source of truth for domain state; UI must not create its own shadow copy.
- Persist the SOS before showing `SAVED LOCALLY`.
- Make repository writes and event application idempotent where practical.
- Handle corrupted records without crashing the whole app; quarantine/report safely and preserve unrelated valid data.
- Test app restart after local save, during queueing, after a peer send, and during concurrent acceptance.
- Do not claim Hive is encrypted by default. Sensitive local data requires a separate approved encryption/key-storage design.

---

## 8. Mesh protocol and networking architecture

### 8.1 Transport dependency

The requested `flutter_nearby_connections_plus` package provides peer discovery and message-oriented communication for Android/iOS. It must be hidden behind a `MeshTransport` interface. Verify the current installed version, API signatures, platform setup, lifecycle behavior, and real-device compatibility from the repository and package documentation. Do not assume it provides a generic connectionless broadcast or a complete multi-hop mesh automatically.

Transport adapters must implement the actual available operations: initialize, start/stop advertising, start/stop discovery, observe peers, connect/disconnect, send to an established peer, receive messages, surface errors, and dispose. Only include operations that the installed API truly supports.

### 8.2 Logical application-level mesh

Implement forwarding over peers that are currently connected and eligible:

1. Create/validate a canonical message envelope.
2. Apply the approved encryption/authentication workflow.
3. Persist the outbound envelope and delivery record before attempting send.
4. Send to the selected connected peers.
5. Track peer-specific acknowledgements or failures where supported.
6. Avoid forwarding to the inbound peer when unnecessary; deduplicate by message/event ID.
7. Enforce max payload size, max hop count/TTL, retry limit, backoff, expiry, and per-peer rate limits.
8. Preserve pending work when disconnected, app backgrounded, radio off, or transport initialization fails.
9. On reconnect, deliver through the same validation and deduplication paths.
10. Avoid an unbounded broadcast loop. Never retry indefinitely without bounded backoff/expiry.

### 8.3 Envelope and event model

Use a versioned, validated transport envelope containing the minimum information needed by the transport and security design. Depending on the selected protocol, it may include:

- protocol/schema version;
- unique event/message ID;
- sender key identifier;
- creation/expiry data with untrusted-clock handling;
- bounded hop/forwarding metadata;
- encrypted payload and authentication/signature data;
- nonce/algorithm/key identifier required by the chosen protocol;
- event type and causality/revision metadata for state changes.

Do not trust sender timestamps alone. Do not expose raw victim text or precise GPS in cleartext relays if the app claims that data is end-to-end encrypted. Any unavoidable visible routing metadata must be documented as a privacy trade-off.

### 8.4 Encryption and offline key bootstrap: release gate

The literal marker `"encryption":"E2E_AES_256"` may only be treated as a legacy descriptive field; it is not proof of encryption. The product must use an established, maintained cryptographic protocol/library compatible with Android and Dart. Do not design an improvised cipher/key-exchange protocol merely by composing primitives.

The implementation must document:

- threat model and assets;
- peer identity and public-key enrollment;
- how a victim can address eligible responders who were not previously directly connected;
- key rotation/revocation and lost-device handling;
- how keys are stored using OS-backed secure storage where available;
- whether the entire report body, location, and capability fields are encrypted to recipients;
- what metadata remains visible to relays;
- how signatures/authenticity and replay protection are handled;
- behavior when no trusted responder key material is available.

No central authority may be required for ordinary forwarding, but “no central authority” does not remove the need for a trust bootstrap. The v1 product must choose and document a feasible offline enrollment approach, such as a locally imported/signed responder roster or explicit QR-based trust enrollment. A common embedded group secret is prohibited. If the agent cannot find and verify a suitable established protocol implementation for the chosen platform, it must document that as a release blocker and not claim production E2E protection.

### 8.5 Partition simulation and reconciliation

`isPartitioned` is a local diagnostics simulation flag, not a representation of a globally shared network fact. Real connectivity is based on transport observations.

When simulated partition is ON:

- pause application-level send/receive at the test transport boundary;
- continue permitted local actions;
- persist outbox work durably;
- show `OFFLINE: QUEUING LOCALLY`;
- do not fake successful peer delivery.

When simulated partition is OFF:

- reconnect/resume transport when possible;
- replay pending work with the normal protocol;
- deduplicate before applying events;
- apply a deterministic merge/conflict policy;
- calculate and display the actual reconciliation result;
- never hardcode `0 conflicts`.

### 8.6 State reconciliation model

Represent status changes as events rather than trusting last-arrival-wins on a whole mutable object. Define allowed transitions and validation rules. At minimum, test duplicate SOS reports, duplicate acceptance events, old `SEARCHING` arriving after `ACCEPTED`, two competing acceptance events from isolated partitions, reject vs accept races, expired reports, key revocation, and events arriving in different orders. A conflict must be recorded and surfaced; the application must not quietly assert that one responder is exclusively assigned if the policy cannot establish that result.

---

## 9. Power, lifecycle, permissions, and location

### 9.1 PowerAgent

- Read actual battery information via `battery_plus` through an injectable adapter.
- Low-power state is true below the configured initial threshold of 20%; thresholds should be configurable and validated during profiling.
- On low battery, reduce nonessential scan frequency, idle work, and duplicate forwarding first. Do not disable every way to receive an emergency message without clearly surfacing that limitation.
- Keep real battery telemetry separate from diagnostics override state.
- Listen to battery state/level updates where supported and dispose subscriptions.
- Handle unsupported/read-failure cases gracefully.

### 9.2 Permissions

Inspect the actual Android target SDK and transport. Add only required manifest declarations and request dangerous permissions at runtime with an explanation. At minimum, evaluate:

- Android 12+ Bluetooth scan/advertise/connect permissions where the selected transport requires them;
- Android 13+ `NEARBY_WIFI_DEVICES` for applicable Wi-Fi APIs;
- `ACCESS_FINE_LOCATION` only where location collection or a platform API truly requires it, with appropriate legacy SDK handling;
- Wi-Fi/network state or change permissions only where the chosen transport/API requires them;
- notification/background execution permissions and restrictions only if the product actually implements those features.

Do not blindly paste every permission from a generic checklist. Keep manifest declarations consistent with runtime permission code and privacy policy. Location permission requires a clear user-facing explanation. Test deny, deny permanently, revocation in Settings, location services off, Bluetooth off, Wi-Fi off, and unsupported adapters.

### 9.3 Lifecycle

Handle app background/foreground, pause/resume, app process death, stream disposal, transport cleanup, and Android OEM battery restrictions. The app must state when background discovery is not running. Do not claim continuous background scanning unless it has been implemented and demonstrated on target devices.

### 9.4 GPS

- Request location only for a user-visible feature and permission grant.
- Store freshness and accuracy metadata with the coordinate.
- Let a user submit without precise GPS; mark location as unknown/unconfirmed.
- Never use demo coordinates as actual dispatch location.
- Do not infer physical safety or presence from GPS alone.

---

## 10. Riverpod and application architecture

Use a layered, testable architecture with no business logic in widgets.

### 10.1 Layers

- **Presentation:** screens, reusable monochrome widgets, accessibility semantics, navigation.
- **Application/orchestration:** use cases/controllers that coordinate triage, repository writes, mesh send, acceptance/rejection, simulation, and state reconciliation.
- **Domain:** models, state machines, TriageAgent, TrustAgent, HazardAgent, CapabilityAgent, RoutingAgent, PowerPolicy, DispatchCoordinator, protocol validation interfaces.
- **Data:** Hive repositories, serialization/adapters, transport adapter, secure-key provider, battery/location adapters, redacted diagnostics log.

### 10.2 Suggested structure

```text
lib/
  main.dart
  app/
    app.dart
    router.dart
    theme.dart
  core/
    result.dart
    errors.dart
    logging/
    protocol/
      envelope.dart
      codec.dart
      validation.dart
      deduplicator.dart
      reconciliation.dart
    security/
      crypto_service.dart
      identity_service.dart
      key_store.dart
  data/
    local/
      hive_database.dart
      repositories/
    mesh/
      mesh_transport.dart
      nearby_connections_transport.dart
    device/
      battery_adapter.dart
      location_adapter.dart
  domain/
    models/
    agents/
      triage_agent.dart
      trust_agent.dart
      hazard_agent.dart
      capability_agent.dart
      routing_agent.dart
      power_agent.dart
      mesh_agent.dart
    services/
      dispatch_coordinator.dart
      reconciliation_service.dart
  features/
    role_selection/
    victim/
    responder/
    diagnostics/
    settings/
  shared/
    widgets/
    accessibility/
```

Adapt paths to the existing repository rather than destroying or duplicating working structure.

### 10.3 Riverpod conventions

- Use providers for repositories, services, adapters, and derived state.
- Use notifier/controller-style providers for stateful workflows, following the installed Riverpod major version.
- Use provider overrides for deterministic tests and simulation adapters.
- Inject clocks, IDs, battery, location, transport, cryptography, and persistence so tests do not depend on physical devices.
- Make stream subscriptions lifecycle-safe and close them when providers are disposed.
- Avoid global mutable singletons beyond carefully initialized app bootstrap; avoid storing the same state independently in provider state and Hive.

---

## 11. UX copy and required states

Use direct wording. Never overstate certainty.

### Local-first statuses

- `SAVED LOCALLY — NOT YET SENT`
- `WAITING FOR A NEARBY PEER`
- `SENDING TO CONNECTED PEERS`
- `PEER ACKNOWLEDGED`
- `RESPONDER ACCEPTED — DEPARTURE NOT CONFIRMED`
- `OFFLINE: QUEUING LOCALLY`
- `DELIVERY DELAYED — REQUEST PRESERVED`
- `DELIVERY FAILED — REQUEST PRESERVED`
- `REQUEST EXPIRED`
- `STATUS CONFLICT — RECONCILIATION REQUIRED`

### Security/trust statuses

- `VERIFIED MESSAGE INTEGRITY` (only after verification succeeds)
- `UNVERIFIED PEER`
- `MESSAGE AUTHENTICATION FAILED`
- `POSSIBLE DUPLICATE — NOT REPROCESSED`
- `SUSPICIOUS CLAIM — QUARANTINED`
- `SIMULATION: SYNTHETIC ATTACK`

Avoid stating “Sybil attack detected” from a single untrusted boolean. Use that exact strong wording only for the injected diagnostic scenario or when the test result truly establishes the defined condition.

### Permission/power statuses

- `NEARBY ACCESS NOT GRANTED`
- `LOCATION NOT PROVIDED`
- `LOCATION MAY BE STALE`
- `LOW POWER — DISCOVERY REDUCED`
- `BACKGROUND DISCOVERY NOT ACTIVE`
- `BATTERY READING UNAVAILABLE`

---

## 12. Performance and reliability targets

All targets must be measured on a documented target device and build mode. Do not fabricate benchmark results.

- Triage: target p95 under 5 ms for the defined maximum input length on a named low-end physical device; benchmark with both typical and adversarial inputs.
- Cold start: record and set a reasonable target after measuring the actual app and device class.
- UI: no blocking disk/network operation on the UI isolate where it could cause jank; keep emergency actions responsive.
- Payload: enforce a documented maximum size and reject/handle oversized packets deterministically.
- Queue: outbox survives process restart and retries are bounded by attempts, backoff, and expiry.
- Forwarding: no infinite loops, duplicate amplification, or unbounded memory growth.
- Storage: schema changes/migrations are tested with seeded prior-version data.
- Battery: profile scanning/forwarding behavior on real devices; use adaptive policy rather than claim an unmeasured battery saving percentage.
- Security: malformed or unauthenticated messages must never crash the app or enter the accepted dispatch pipeline.

---

## 13. Observability and privacy

Implement structured, redacted logs with event categories and error codes. Never log raw SOS text, precise coordinates, private keys, cryptographic secrets, or unneeded stable identifiers. Logs should answer: what operation failed, on which subsystem, and whether user data was preserved—without exposing the data itself.

The Diagnostics view may show aggregate counts, protocol version, peer count, last error category, queue depth, and reconciliation outcomes. It must not expose private keys or unredacted distress messages by default.

Define retention for active, accepted, rejected, expired, and diagnostic records. Provide a way to remove local report data according to that policy. Avoid silent indefinite retention of victim messages and precise location.

---

## 14. Testing plan

### 14.1 Unit tests

- Triage rule mapping, overlap, unknown, negation, code-mixed text, input bounds, deterministic output, and latency benchmark harness.
- State machine valid and invalid transitions.
- Trust logic based on locally computed evidence rather than sender-asserted score/flag.
- Capability matching with missing, stale, or unverified claims.
- Power policy threshold and override separation.
- Retry/backoff/hop limit/expiry logic.
- Canonical encoding, version mismatch, size limits, and malformed input.
- Deduplication and replay protection for the selected protocol.
- Reconciliation under every relevant event ordering.

### 14.2 Repository/integration tests

- Hive initialization and adapter registration.
- Write/read of every model and generated adapter.
- Restart recovery of messages/outbox/inbox.
- Migrations from seeded prior schema.
- Local persistence failure behavior.
- Provider disposal and stream cancellation.
- End-to-end Victim submit → persist → queue → fake transport send → ack → Responder display → accept → persist event → fake transport propagate.
- Partition ON → persist queued event → restart → partition OFF → retry → deduplicate → reconcile.

### 14.3 Widget tests

- All four screens render in the pure-black monochrome theme.
- No placeholder/disabled buttons masquerade as implemented actions.
- SOS submission validation and local-save state.
- Accepted status copy distinguishes acceptance from en-route/arrival.
- Low/unknown triage is retained and not silently represented as safe.
- Timer never auto-accepts.
- Drawer reflects real providers and shows simulation state clearly.
- Permission-denied, no-peer, and low-power states remain actionable.
- Semantics labels, text scaling, and reduced-motion behavior.

### 14.4 Physical-device test matrix

Use at least two, preferably three, physical Android devices across relevant Android versions and OEMs. Test with internet disabled, Wi-Fi on/off, Bluetooth on/off, location services on/off, permission denial, device lock/background, low battery, app restart, device moved out of range, connection dropped during send, and peer reconnect. An emulator-only pass is insufficient for nearby-device transport validation.

### 14.5 Security tests

- Modify urgency, role, trust score, spoof flag, sender ID, timestamp, ciphertext, nonce, and signature.
- Replay a previously accepted packet.
- Send oversized/deeply nested/malformed JSON and unknown schema versions.
- Attempt to forward loops and duplicate floods.
- Verify private keys and report plaintext never appear in logs.
- Confirm relay behavior matches the documented confidentiality model.
- Confirm no security UI label is displayed when keys/encryption are not ready.

---

## 15. Release gates and definition of done

The app is not V1-complete until all applicable gates are satisfied and evidence is recorded.

### Gate A — Build quality

- `flutter pub get` succeeds using the lockfile/resolved dependency versions.
- Code generation succeeds using repository-compatible commands.
- `dart format` passes on changed Dart code.
- `flutter analyze` has no unresolved errors; all warnings are reviewed.
- Unit, widget, and integration tests pass, with test output recorded.
- Android debug build succeeds; release build is validated before release claims.

### Gate B — Functional completeness

- Four screens and global drawer have real working actions.
- No placeholder buttons or fake success messages.
- Local persistence and restart recovery work.
- Triaging and responder evaluation use one domain pipeline.
- Outbox/inbox, retries, deduplication, and partition simulation work with deterministic tests.
- Diagnostics scenarios assert outcomes instead of merely changing labels.

### Gate C — Transport reality

- Real peer discovery, connection, send, receive, and disconnect handling tested on physical devices.
- All library/API operations correspond to actual supported APIs.
- Offline/no-peer behavior communicates local queueing accurately.
- No claim of arbitrary-range broadcast or background availability without evidence.

### Gate D — Security and privacy

- Threat model and key/bootstrap ADR exist.
- Selected protocol/library and platform APIs are documented and dependency versions are verified.
- Message tampering, replay, deduplication, trust spoofing, and local storage concerns are tested.
- Key readiness and security status are visible to users/operators.
- If cryptography has not been independently reviewed or key bootstrap does not support the intended routing model, real-world emergency deployment remains blocked and the limitation is explicitly documented.

### Gate E — Human safety

- Timer cannot make dispatch decisions.
- Unknown/ambiguous messages are not silently downgraded.
- Acceptance does not imply departure/arrival.
- Location/hazard uncertainty is visible.
- Simulated readings/attacks cannot be confused with real observations.

### Gate F — Delivery artifact

Provide a final report containing:

- concise architecture summary;
- files created/modified;
- exact dependency versions selected and why;
- commands actually executed and their outcomes;
- tests executed and results;
- physical-device tests that were/weren’t possible;
- security limitations and unresolved release blockers;
- reproducible run/build instructions;
- screenshots or a short walkthrough of the four screens if available.

Never state that a check passed unless the command/test was run and its output supports the claim. Never label the application fully production-approved solely because it compiles.

---

## 16. Suggested decisions for the implementation agent

The agent should create short ADRs for high-impact decisions rather than hiding assumptions in code:

- **ADR-001:** Transport choice, package version, supported Android versions, and actual peer model.
- **ADR-002:** End-to-end encryption, identity bootstrap, key storage, and visible metadata.
- **ADR-003:** Event state machine and partition reconciliation/competing acceptance policy.
- **ADR-004:** Triage rules, unknown reports, and capability claim verification.
- **ADR-005:** Permission strategy, battery policy, app background limitations, and location handling.
- **ADR-006:** Data retention, local-at-rest protection, redaction, and diagnostics boundaries.

If a decision cannot be implemented safely based on available project/package support, do not invent facts. Implement the safe portions, capture the blocker, and state exactly what remains unverified.

---

## 17. Authoritative implementation references

The implementation agent must check the installed/resolved versions and consult the primary documentation, rather than copying version numbers blindly:

- Flutter nearby connections package: <https://pub.dev/packages/flutter_nearby_connections_plus>
- Hive CE Flutter: <https://pub.dev/packages/hive_ce_flutter>
- Riverpod: <https://pub.dev/packages/flutter_riverpod>
- Battery Plus: <https://pub.dev/packages/battery_plus>
- Flutter Animate: <https://pub.dev/packages/flutter_animate>
- Dart Cryptography: <https://pub.dev/packages/cryptography>
- Android Bluetooth permissions: <https://developer.android.com/develop/connectivity/bluetooth/bt-permissions>
- Android Wi-Fi permissions: <https://developer.android.com/develop/connectivity/wifi/wifi-permissions>
- Android Wi-Fi Direct: <https://developer.android.com/develop/connectivity/wifi/wifip2p>
- Google Antigravity official overview: <https://www.antigravity.google/docs/ide/overview/>

**End of PRD.** The separate `docs/agent/BUILD_PROMPT.md` turns this specification into an execution contract for the coding agent.
