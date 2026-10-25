# ADR-005: Permissions, power policy and background operation

- **Status:** Accepted
- **Finalized in:** Phase 3 implementation; verification deferred by owner
- **Date:** 2026-10-25

## Decisions

### Permissions

The set is derived from Google Nearby Connections requirements, the same set `nearby_connections` merges:

| Permission | Why |
|---|---|
| BLUETOOTH, BLUETOOTH_ADMIN (max SDK 30) | Nearby on Android 11 and below |
| ACCESS_WIFI_STATE, CHANGE_WIFI_STATE | Wi-Fi upgrade of Nearby links |
| ACCESS_COARSE_LOCATION, ACCESS_FINE_LOCATION | Nearby discovery on Android 11 and below; opt-in SOS location |
| BLUETOOTH_SCAN / ADVERTISE / CONNECT | Android 12+ runtime Bluetooth |
| NEARBY_WIFI_DEVICES | Android 13+ Wi-Fi peers |
| FOREGROUND_SERVICE, FOREGROUND_SERVICE_CONNECTED_DEVICE | Android 14 typed foreground service |
| POST_NOTIFICATIONS | Foreground-service notification on Android 13+ |

Runtime permissions are requested only when the user taps **TURN ON MESH**, never at first launch. Each state has explicit UI text:
- denied → `NEARBY ACCESS NOT GRANTED`;
- permanently denied → `NEARBY ACCESS BLOCKED — OPEN SETTINGS`, with a settings button;
- location services off, or no fix → its own label.

### Background operation

A native `MeshForegroundService` (type `connectedDevice`) keeps the process, and so the Flutter engine and the mesh, alive with the screen off. If it fails to start (`ForegroundServiceStartNotAllowedException`, missing permission), the UI shows `BACKGROUND DISCOVERY NOT ACTIVE`.

### Power policy (`lib/domain/power/power_policy.dart`)

| Mode | Battery | Relaying | Beacons | Store-and-forward replay batch |
|---|---|---|---|---|
| NORMAL / UNKNOWN | above 20% or unreadable | Everything | 60 s | 200 frames |
| LOW | 20% and below | No others' beacons, no LOW-urgency SOS | 180 s | 50 frames |
| CRITICAL | 8% and below | Only CRITICAL/UNKNOWN SOS, events, revocations | 300 s | 50 frames |

In low and critical modes the radio also pauses discovery while connected and re-scans in short windows. **The receive path is never disabled.**

The diagnostics battery override is separate state, labelled `SIMULATED BATTERY OVERRIDE`. It never changes the real reading.

## Consequences

- **OEM behaviour is unmeasured.** Aggressive battery managers (Xiaomi, Oppo, Vivo and others) may still kill the service. Not yet measured on devices.
- **Battery savings are unquantified.** No savings percentage is claimed until profiled on real phones.
