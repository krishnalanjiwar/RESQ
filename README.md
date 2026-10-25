# RESQ

RESQ is an offline-first, decentralized emergency response and rescue communications system designed to operate in disaster zones and communication-denied environments where cellular networks and power grids are compromised.

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
