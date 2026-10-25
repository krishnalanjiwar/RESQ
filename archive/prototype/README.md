# Archived pre-MVP prototype

This is the original RESQ prototype from commit `8866fdc`, archived in Phase 0 (decision D6, 2026-10-25).

It is **not part of the build** and is excluded from analysis. It never compiled. Known problems:
- It used a nearby-connections API that doesn't exist.
- It used Riverpod 3 legacy providers without the legacy import.
- `Border.side` doesn't exist.
- Its test referenced a `MyApp` class that doesn't exist.

It also conflicts with the PRD: clinical triage advice, an "AI engine" label with no model, and fake signal strength.

Keep it only as a reference. Do not import from it.
