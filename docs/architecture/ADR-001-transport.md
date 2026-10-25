# ADR-001: Peer-to-peer transport

- **Status:** Accepted (provisional, pending the two-phone spike)
- **Finalized in:** Phase 3 implementation; verification deferred by owner
- **Date:** 2026-10-25

## Context

RESQ must exchange messages phone-to-phone with no internet. Multi-hop forwarding is done by RESQ itself (`MeshAgent` logic in `ResqNode`), not by the transport. The transport sits behind `MeshTransport` (`lib/mesh/transport.dart`) so that domain logic doesn't depend on any one plugin.

## Options considered

| | `nearby_connections` 4.3.0 | `flutter_nearby_connections_plus` 1.2.2 |
|---|---|---|
| Payloads | Raw bytes | Strings only |
| Lifecycle | Explicit request/accept/result | Hidden "invite peer" |
| Native build | Declares `namespace` (works with AGP 8) | AGP 3.5 classpath, Kotlin 1.7.10, no `namespace` |
| Play Services | play-services-nearby 19.2.0 | 18.5.0 |
| Manifest | Nearby permission set only | Adds INTERNET, a foreground service, and a *required* Wi-Fi Direct hardware feature |

Raw BLE GATT (the Bitchat approach) was rejected for the MVP on effort.

Both packages' APIs were read from their resolved sources in the pub cache.

## Decision

**`nearby_connections` 4.3.0**, using Strategy `P2P_CLUSTER` (M-to-N links), wrapped by `NearbyTransport` (`lib/mesh/nearby_transport.dart`).

- **Callbacks:** the plugin keeps one global set of callbacks, so one shared handler serves every connection.
- **Dial collisions:** a name tie-break means only the lexicographically smaller name dials.
- **Peer cap:** at most 6 connected peers.
- **Low-power discovery:** in low power, discovery pauses while connected and re-runs in a 20 s window every 2 minutes.
- **Frame limit:** 16 KiB, under Nearby's 32 KiB BYTES cap.

**Provisional:** the two-phone spike (`spikes/transport_spike`, both packages behind one UI) was written but not run, because the owner deferred all testing. If `nearby_connections` fails on the test phones, only `NearbyTransport` changes.

## Consequences

- **Android only.** iOS would need Multipeer and can't interoperate with Nearby. iOS is out of scope.
- **Single-hop range.** Each hop covers tens of metres (BLE) up to about 100 m+ (Wi-Fi upgrade). Range comes from multi-hop relaying plus store-and-forward replay on every new connection.
- **Background limits.** Background operation depends on the foreground service (ADR-005). OEM battery savers may still stop it, and the UI then shows `BACKGROUND DISCOVERY NOT ACTIVE`.
- **Toolchain.** The project stays on AGP 8.11.1 / Gradle 8.14.3, because stale plugins tend to break on AGP 9.
