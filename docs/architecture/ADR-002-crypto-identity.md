# ADR-002: Identity, credentials and end-to-end encryption

- **Status:** Accepted for MVP. **Release blocker for real deployment: independent cryptographic review not done.**
- **Finalized in:** Phase 4 implementation; verification deferred by owner
- **Date:** 2026-10-25

## Threat model (MVP)

| Attacker | Capability | Defence |
|---|---|---|
| Passive eavesdropper / relay | Reads every frame it carries | Sensitive body sealed to responder keys; only a minimal routing header in clear |
| Active injector | Sends arbitrary frames | Ed25519 signature on every envelope; strict schema/size/TTL validation; dedupe |
| Sybil ("40 nurses") | Generates unlimited keypairs | Keys earn no trust; capability trust requires a credential from a pinned anchor; link-level identity collapse; co-location clustering |
| Credential forger | Claims an authority signed them | Credential signature verified against the issuer key; issuer must be a pinned or provisioned anchor; forgery quarantines the identity |
| Flooder / battery drainer | High frame rate | Per-link token bucket with quarantine; per-origin relay limits; junk rejected before signature work |
| Location spoofer | Lies about GPS | Treated as a claim; hop-count plausibility and velocity checks (Stage 1) |

## Decisions

### Library

`package:cryptography` 2.9.0 (pure Dart, maintained), API verified from the resolved source:

- Ed25519 signatures;
- X25519 key agreement;
- HKDF-SHA256;
- XChaCha20-Poly1305 AEAD.

### Identity

- **Keys:** an Ed25519 signing key (the identity) plus an X25519 encryption key, both generated from 32-byte seeds.
- **Storage:** the seeds live only in OS-backed secure storage (`flutter_secure_storage`, which uses the Android Keystore), never in Hive.
- **Fingerprint:** humans compare `XXXX-XXXX-XXXX-XXXX`, the first 8 bytes of SHA-256 over a domain-separated key.

### Trust bootstrap (D4)

There is no central server at runtime. Trust anchors are authority public keys, which can be:

1. provisioned in `assets/trust_anchors.json` at build time (empty by default), or
2. pinned in person after comparing fingerprints (Diagnostics › TRUST).

The demo uses a phone in clearly labelled **DEMO AUTHORITY** mode. There is no embedded shared secret anywhere.

### Credentials

- **Contents:** `{cid, subject, roles, iat, exp, issuer, issuerName}`, signed by the issuer.
- **Delivery:** sent to the subject over the mesh and then embedded in the subject's beacons, so receivers can verify immediately.
- **Status:** computed by the receiver as `verified`, `unknownIssuer`, `expired`, `revoked` or `forged`. A forgery quarantines the presenting identity.
- **Revocation:** signed by the issuer and flooded. Only revocations from anchors are honoured.

### Vouching

Signed `vouch` messages. At most 3 distinct, non-penalised vouchers count. A vouch raises capability trust, but never to the verified level.

### Encryption (D5)

**Construction:** follows the **age v1 X25519 recipient design**:

- a random 32-byte file key encrypts the payload once (XChaCha20-Poly1305, with the message id as AAD);
- for each recipient, an ephemeral X25519 agreement plus HKDF derives a wrap key that encrypts the file key.

**Recipient privacy:** stanzas don't name recipients (trial decryption), so relays learn only the recipient count.

**Recipients:** up to 8 verified responders, nearest first.

**If no verified responder keys are known,** the victim chooses:
- *share openly* (the default, because reachability beats secrecy for a dying victim), or
- *coarse only*: urgency, need categories and the ~5 km cell.

**What relays see in clear:** message id, type, sender key, timestamps, TTL/hop, the ~5 km geohash, the urgency class and the need categories. This leak is deliberate so relays can prioritise under battery pressure.

## Consequences / limitations

- **Composition not reviewed.** The construction composes established primitives in a documented, well-known pattern, but the RESQ composition has **not** been independently reviewed. Do not claim production E2E security until it is.
- **No forward secrecy.** Sealed messages carry none: a compromised responder key reveals past SOS sealed to it.
- **Signatures prove keys, not people.** A valid signature proves control of a key. It doesn't prove a real-world identity, qualifications, truthful content or a true location.
- **Pure-Dart speed.** Ed25519 in pure Dart is slower than native; `cryptography_flutter` can be added later.
