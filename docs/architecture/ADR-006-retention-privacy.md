# ADR-006: Data retention, local storage and log redaction

- **Status:** Accepted (revised 2026-10-25 after the bug-fix pass)
- **Date:** 2026-10-25

## Decisions

- **Storage model.** Local storage is Hive CE with versioned JSON records (`envelopes_v2`, `meta_v2`) and no code generation. State is rebuilt by replaying verified envelopes, and corrupted or expired records are deleted at startup instead of crashing it.
- **Encryption at rest.** Both boxes are AES-encrypted with a random 32-byte key held in OS secure storage (Android Keystore). Unencrypted `*_v1` boxes from 0.8.0 builds are deleted on first start.
- **Recovery instead of bricking.** If the Keystore can't decrypt its data (for example after a restore or an OS reset), the unreadable keys are wiped and new ones generated. Local data starts fresh, and the status drawer says so. If the encrypted boxes can't be opened, they're recreated.
- **No backups.** `allowBackup=false`, plus data-extraction rules that exclude everything from cloud backup and device transfer. Keys and SOS data never leave the phone through backups.
- **Retention follows message lifetimes:**

  | Message type | Lifetime |
  |---|---|
  | SOS and events | 24 h |
  | Heartbeats | 15 min |
  | Hazards | 6 h |
  | Beacons | 5 min (memory only, never persisted) |
  | Credentials, revocations, vouches | 30 days |

  Expired records are pruned on every tick.
- **Penalties persist for 24 h.** Forged credentials, signature failures and flooding links stay penalised across restarts.
- **Deletion.** *Delete local report data* (Diagnostics › DEVICE) wipes stored SOS, events, hazards and settings, plus the in-memory caches (duplicate filter, beacons, penalties, offer state), so the phone can resync cleanly. Identity keys are kept.
- **Log redaction.** The event log keeps codes and redacted details only: no SOS text, no exact coordinates, no keys. Identity keys appear as prefixes or fingerprints.
- **Simulation isolation.** Simulated nodes use separate in-memory stores and never touch the device database.

## Consequences

- **Rooted phones.** Data is readable only with the Keystore-held key. A rooted device with Keystore access can still read it.
- **Recovery loses data.** Recovering from an unreadable Keystore discards local history; the new identity starts with no reputation.
