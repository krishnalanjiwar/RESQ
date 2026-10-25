# ADR-003: Event model and partition reconciliation

- **Status:** Accepted
- **Finalized in:** Phases 1 and 6 implementation; verification deferred by owner
- **Date:** 2026-10-25

## Decision

- **State is event-sourced.** Every state change on an SOS is a signed `event` envelope: `accepted`, `enRoute`, `onScene`, `resolved`, `declined`, `standDown`, `heartbeat` or `cancelled`. Each event carries a Lamport clock (`lam`), and nodes advance their clock on receipt.
- **Merging is a set union.** It happens automatically: on every new connection, each side replays its live messages and dedupe drops duplicates.
- **The fold is deterministic** (`lib/domain/reconcile/reconciler.dart`):
  - only the requester can cancel; a requester can't accept their own SOS;
  - responder progress rank: ON_SCENE (3) > EN_ROUTE (2) > ACCEPTED (1);
  - primary responder: highest progress, then earliest acceptance (Lamport), then key order;
  - **never cancel at the door:** a responder already ON_SCENE is never told to stand down, and `standDown` events are ignored once a responder is on scene. Two responders on scene are both kept and reported as `MULTIPLE_ON_SCENE`;
  - all other duplicates get `STAND DOWN — another responder has precedence`;
  - **orphans:** an ACCEPTED or EN_ROUTE responder silent for longer than the orphan timeout (10 min on devices, 2 min in the simulator) is released and the SOS reopens. A responder silent ON_SCENE is only flagged stale, never reopened.
- **Heartbeats:** the active responder sends heartbeat events every 2 minutes.
- **The reconciliation report is computed** from the folded states: double dispatches, stand-downs, multiple-on-scene and orphans. It is never a constant.

## Consequences

- **Same events, same answer.** Any two nodes holding the same events compute the same primary responder.
- **Exactly-once dispatch is impossible across partitions.** Reconciliation detects and resolves duplicates; it can't undo travel already done. The UI says so.
- **Orphan detection uses local receive time.** It doesn't trust sender clocks, so two nodes may disagree briefly about whether an assignment is orphaned.
