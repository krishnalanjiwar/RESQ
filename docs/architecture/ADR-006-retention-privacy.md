# ADR-006: Data retention, local storage and log redaction

- **Status:** Accepted
- **Date:** 2026-10-25

## Decisions

- **Storage model.** Local storage is Hive CE with versioned JSON records (`envelopes_v1`, `meta_v1`) and no code generation. State is rebuilt by replaying verified envelopes, and corrupted or expired records are deleted at startup instead of crashing it.
- **Retention follows message lifetimes:**

  | Message type | Lifetime |
  |---|---|
  | SOS and events | 24 h |
  | Hazards | 6 h |
  | Beacons | 5 min (memory only, never persisted) |
  | Credentials, revocations, vouches | 30 days |

  Expired records are pruned on every tick.
- **Deletion.** *Delete local report data* (Diagnostics › DEVICE) wipes stored SOS, events, hazards and settings. Identity keys are kept.
- **Own SOS copy.** A requester's full report is kept locally (`own_sos:<id>`) so they can read their own sealed SOS.
- **Log redaction.** The event log keeps codes and redacted details only: no SOS text, no exact coordinates, no keys. Identity keys appear as 8-character prefixes or fingerprints.
- **Simulation isolation.** Simulated nodes use separate in-memory stores and never touch the device database.

## Consequences

- **Hive is not encrypted at rest.** Relayed SOS that were shared openly, and the requester's own copy, are readable by anyone with filesystem access to the app sandbox (root, or a device backup). Encrypting Hive with a Keystore-held key is a follow-up.
- **Penalties aren't persisted.** Local penalties (quarantined identities) live in memory only and reset on restart.
