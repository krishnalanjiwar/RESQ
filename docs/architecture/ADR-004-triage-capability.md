# ADR-004: Triage, zero-shot capability matching and the evaluation chain

- **Status:** Accepted (D3 option (a); the embedding stretch was not implemented)
- **Finalized in:** Phases 2 and 5 implementation; verification deferred by owner
- **Date:** 2026-10-25

## Decision

### Triage (`lib/domain/triage/`)

Pure-Dart, deterministic and bounded: input is capped at 600 characters, with no ML and no network. Ruleset version `triage-2026.10.1`.

**Text handling:**
- Normalisation: lowercase, strip punctuation, collapse whitespace, map spelling variants (`paani` → `pani`, `cannot` → `cant`, …).
- Phrase rules run in a fixed order. Specific phrases consume their tokens first, so "drinking water" is supplies, not flood.
- Fuzzy matching applies only to Latin words of 6+ characters (edit distance 1, or 2 for 9+ characters), so "water" never matches "later".
- Languages: English, Hinglish (transliterated Hindi) and Devanagari keywords.
- Negation (`no`, `not`, `nahi`, …) within two tokens of a match removes that match and forces NEEDS REVIEW.

**Combination rules raise urgency to CRITICAL:**
- trapped + injured, water or fire;
- vulnerable person + water.

**Outcomes that are never downgraded:**
- Unmatched or ambiguous text, including bare "please help" or "bachao", is `UNKNOWN` + `NEEDS HUMAN REVIEW`, and is weighted above LOW.
- Text that reads like an offer of help ("boat available, can help") is flagged as a capability offer.

**Receiver side:** each receiver recomputes triage from the text whenever it can read it. The sender's urgency label is a claim.

The original brief's `Map<String,String> analyze(text)` API is available as `analyzeLegacy`, mapped from the typed result.

### Zero-shot capability matching

`CapabilityParser` maps open-vocabulary, code-mixed claims ("has a boat", "can do dialysis", "tairna aata hai", "tractor hai") onto a 12-capability ontology. Unrecognised text becomes `GENERAL HELP` and is flagged for human judgement.

A need→capability fit table drives matching. A hazard→capability table drives the hazard gate.

### Evaluation chain (`lib/domain/chain/`), in the problem statement's order

1. **Claim Verification:** `P(real)` × `P(location)`.
   - `P(real)` comes from reporter trust, independent corroboration (other reporters within 600 m and 45 min), repeated-report penalties, and Sybil indicators.
   - `P(location)` comes from accuracy and staleness, the check (h+1)×300 m against the observer's own position for fresh messages, and the velocity between reports.
   - Below 0.35 the SOS is flagged `SUSPECTED DECOY`, and it is kept.
2. **Hazard Avoidance:** `P(safe)` from signed hazard reports.
   - Reports are merged per independent reporter and decay with a 1 h half-life.
   - If the target is inside a zone of 60%+ confidence and the responder lacks the matching capability, the responder is **not eligible**. A path crossing a zone is penalised.
   - With no reports, the stage says `NO_HAZARD_REPORTS_KNOWN (not a safety guarantee)`.
3. **Trust Scoring:** receiver-computed capability trust (ADR-002): 0.95 verified, up to 0.8 vouched, 0.35 self-declared, scaled by Sybil and identity-age factors.
4. **Battery / Routing Cost:** distance, responder battery (a claim), mesh hops, and presence staleness.
5. **Safe Dispatch:**
   - score = U(urgency) × P(claim) × P(safe) × T × capability-fit / cost;
   - gates: quarantine, hazard, availability, already engaged, presence expired;
   - **human acceptance is always required.**

### Distributed dispatch (`lib/domain/dispatch/matcher.dart`)

Every device runs the same deterministic matcher over its own view:

- SOS are processed in order of urgency × P(claim).
- **Scarcity weighting:** spending a capability an SOS doesn't need is penalised in proportion to that capability's demand/supply ratio. This is how the only medic goes to the critical case.
- One primary responder per SOS gets a targeted offer (against the bystander effect).
- **Offer window** (60 s on devices, 25 s in the simulator): when it lapses, the offer moves to the next candidate. A timeout never accepts, rejects or dispatches.
- **Justification:** a deterministic one-liner from the chain outputs, for example *"CRITICAL medical + water rescue · 1.2 km NE · you are the only medical-capable in range · victim inside flood zone — you are equipped · 2 nearby report(s) corroborate"*.

## Consequences

- **Lexicon limits.** Rules can't cover everything. Coverage gaps fall to NEEDS REVIEW, never to "safe".
- **The probabilities are heuristic scores,** deterministic and explainable, not calibrated probabilities. Calibration needs field data.
- **The <5 ms triage target is unmeasured.** A test bounds a 30 KB input to under 500 ms, but the p95 has not been measured on a device.
