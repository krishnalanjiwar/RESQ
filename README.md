<p align="center">
  <img src="assets/brand/resq_icon_192.png" width="96" alt="RES-Q logo: a location pin broadcasting radio waves">
</p>

<h1 align="center">RES-Q</h1>
<p align="center"><b>Emergency help, even when the network is down.</b><br>Help travels phone to phone: no towers, no internet, no central server.</p>

---

RES-Q is an offline-first, decentralized emergency response system for disaster zones where cellular networks and power are down.

> **Status:** Implemented and verified by automated tests (static analysis clean, 71 tests passing). Physical-device testing is pending. Read [docs/VERIFICATION_REPORT.md](docs/VERIFICATION_REPORT.md) before trusting any claim. Plan and gates: [docs/MVP_PHASES.md](docs/MVP_PHASES.md).

RES-Q is an auxiliary coordination tool. It does not replace emergency services and cannot guarantee delivery or rescue.

**Brand:** the mark is a location pin with a coral beacon, broadcasting radio waves: *my location, shared with nearby phones*. Brand source is in `lib/ui/brand.dart`; icons are rendered by `scripts/brand/render_icons.py`.

## What it does

- **Every phone is a relay.** Signed messages hop between phones over Bluetooth / Wi-Fi (Google Nearby Connections), with store-and-forward when phones meet. There is no server and no internet.
- **Victims** send a short SOS in any language (English, Hinglish, Hindi). Deterministic rules triage it, and anything unclear goes to human review, never to "low".
- **Responders** describe what they can do in free text ("boat hai", "can do dialysis"). Each responder phone runs the same matcher and gets a targeted offer with a one-line justification and the five-stage chain: **Claim Verification → Hazard Avoidance → Trust Scoring → Battery/Routing Cost → Safe Dispatch**. Only a human ACCEPT moves anyone.
- **Trust without a server.** Credentials are signed by authority keys that are pinned in person by fingerprint. Sybil collapse, forged-credential quarantine and flood control protect the mesh, and SOS details are sealed to verified responders.
- **Network splits.** Disconnected islands resolve emergencies independently. When they reconnect, a deterministic event merge sends duplicates a stand-down, never cancels a responder already on scene, and reopens orphaned requests.
- **Red Team Hour.** Diagnostics runs a simulated city of real RESQ nodes, with live attacks and measured outcomes.

## Docs

| Doc | Purpose |
| :--- | :--- |
| [docs/MVP_PHASES.md](docs/MVP_PHASES.md) | Phased plan, gates, problem-statement traceability |
| [docs/IMPLEMENTATION_REPORT.md](docs/IMPLEMENTATION_REPORT.md) | What was built, mapped to each criterion |
| [docs/VERIFICATION_REPORT.md](docs/VERIFICATION_REPORT.md) | What has actually been verified |
| [docs/architecture/](docs/architecture/) | ADR-001…006 |
| [docs/DEMO_SCRIPT.md](docs/DEMO_SCRIPT.md) | Judge demo walkthrough |
| [docs/PRD.md](docs/PRD.md) | Safety, honesty and security rules |

---

## Build and install (Android)

Requirements: Flutter stable (3.47+), JDK 17, Android SDK (platform-tools, a current platform and build-tools), and a physical Android phone with USB debugging enabled.

```powershell
flutter doctor                       # Android toolchain must be OK
powershell -ExecutionPolicy Bypass -File scripts\build_apk.ps1
adb install -r dist\resq-<version>-debug.apk
```

`scripts/build_apk.ps1` runs `pub get`, `analyze`, `test` and `build apk`, then copies the APK(s) to `dist/` and prints SHA-256 checksums. Every phase gate uses this script.

Release build (signed with your own key):

```powershell
powershell -ExecutionPolicy Bypass -File scripts\create_release_keystore.ps1   # once; back up the .jks
powershell -ExecutionPolicy Bypass -File scripts\build_apk.ps1 -Release -SplitPerAbi
```

## Repository layout

| Path | Contents |
| :--- | :--- |
| `lib/` | The app |
| `test/` | Automated tests |
| `docs/` | Plan, PRD, architecture, ADRs and phase reports |
| `spikes/` | Throwaway experiments, e.g. the Phase 0 transport spike. Not part of the app |
| `archive/prototype/` | The original pre-MVP prototype, kept for reference only and excluded from the build |
| `tools/` | Reference and tooling submodules (below) |

---

## Toolkits & Architecture References

This repository includes submodules under [`tools/`](tools/) providing development orchestration and mesh networking references:

| Submodule | Source | Purpose |
| :--- | :--- | :--- |
| **Get Shit Done (GSD)** | [`tools/get-shit-done`](https://github.com/gsd-build/get-shit-done) | Context engineering, spec-driven development (SDD) & subagent execution harness |
| **Everything Claude Code** | [`tools/everything-claude-code`](https://github.com/WorldFlowAI/everything-claude-code) | Agent personas, TDD guidelines, security auditing rules & lifecycle hooks |
| **Bitchat** | [`tools/bitchat`](https://github.com/permissionlesstech/bitchat) | Reference architecture for BLE mesh networking, Noise E2EE, PTT voice bursts & store-and-forward |

---

## Cloning With Submodules

To clone this repository along with all referenced toolkits:

```bash
git clone --recurse-submodules https://github.com/krishnalanjiwar/RESQ.git
```

If already cloned:

```bash
git submodule update --init --recursive
```
