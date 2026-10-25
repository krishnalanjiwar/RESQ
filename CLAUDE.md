# RESQ — project rules for AI agents

## Phase gate (mandatory)

The MVP is built in phases defined in [docs/MVP_PHASES.md](docs/MVP_PHASES.md).

- **Never start a phase without the owner's explicit written approval naming that phase**, e.g. `APPROVED: Phase 3`. Silence, a past approval, or a general "continue" is not approval.
- "Starting" includes any code, dependency, config, asset, or build change belonging to that phase.
- At the end of a phase: stop, write the phase report (template in §9 of the plan), provide the APK path, and wait.
- If a blocker changes scope, a decision, or a problem-statement criterion, stop and ask.
- This rule overrides "don't ask for approval between phases" in `docs/agent/BUILD_PROMPT.md`.

**Owner override (2026-10-25):** the owner approved implementing Phases 1–8 in one pass with all testing deferred. Verification of each phase is still gated: verify a phase only when the owner approves it, and never mark a phase Done without evidence.

Check the phase status tracker in `docs/MVP_PHASES.md` before doing any implementation work.

## Engineering guardrails

Follow §3 of `docs/MVP_PHASES.md`. The PRD in `docs/PRD.md` is the source for detailed safety, honesty and security rules.
