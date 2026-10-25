# RESQ — Demo Script (about 8 minutes)

**Setup:** 2 Android phones with the APK installed, airplane mode ON with Bluetooth and Wi-Fi turned back ON. Phone A = VICTIM, phone B = RESPONDER. A third device or the projector shows phone B in Diagnostics later.

## 1. The problem (30 s)
"Cell towers are down. RESQ is a mesh: every phone is a relay. No server, no internet."

## 2. Real radio (2 min)
1. On both phones: choose a role, then **TURN ON MESH** → grant Nearby access. *(Permissions are asked only now.)*
2. Phone B › RESPONDER: type `staff nurse, boat hai` → **SAVE CAPABILITIES**. The parsed chips show MEDICAL + BOAT, *self-declared*.
3. Phone A › VICTIM: type `Need insulin for dad, ground floor flooded`. The live preview reads **CRITICAL · MEDICAL + WATER RESCUE**.
4. **SEND SOS.** Status: `SAVED LOCALLY` → `SENT TO CONNECTED PEERS` → `PEER ACKNOWLEDGED`. *(Each state is true, never inflated.)*
5. Phone B: an **OFFER** card shows the one-line justification and all five chain stages with scores. Tap **ACCEPT**.
6. Phone A: `RESPONDER ACCEPTED — DEPARTURE NOT CONFIRMED`. Phone B: **EN ROUTE** → **ON SCENE**.

## 3. Trust without a server (1.5 min)
1. Phone A: open the status drawer (☰ top right) › role **DIAGNOSTICS** › TRUST tab › **ACT AS DEMO AUTHORITY**.
2. Phone B: drawer › role **DIAGNOSTICS** › TRUST tab. The authority appears with a fingerprint. Compare it out loud → **PIN**. Then switch phone B back to **RESPONDER**.
3. Phone A: issue a credential to phone B after comparing B's fingerprint, then switch phone A back to **VICTIM** in the drawer.
4. Phone B › RESPONDER: **VERIFIED: MEDICAL (ADVANCED)**. Future SOS are now **sealed** to B: relays can't read them.

## 4. Red Team Hour (3 min) — Diagnostics › RED TEAM SIM
1. **BUILD SIMULATED CITY.** About 25 real RESQ nodes on a simulated radio (map: squares = victims, circles = responders).
2. **REPORT FLOOD ZONE**, then **SEED EMERGENCIES**, then **RUN**. Watch responders move toward victims; the medic is sent to the critical case.
3. **INJECT SYBIL TEST (40 NURSES)** → outcome card: flagged, 0 assignments to fakes.
4. **FORGED MEDICAL CREDENTIAL** → QUARANTINED.
5. **FLOODWATER LURE** → only boat-capable responders are offered the decoy SOS in the flood zone.
6. **BATTERY-DRAIN FLOOD** → the link is quarantined at the neighbours.
7. **PARTITION DOUBLE-DISPATCH**, then **HEAL PARTITION** → reconciliation: one responder stands down, and anyone already on scene is never cancelled.

## 5. Honesty slide (30 s)
Read from `docs/VERIFICATION_REPORT.md`:
- what has been verified;
- what hasn't;
- the security limitations.

RESQ is an auxiliary tool, not a replacement for emergency services.
