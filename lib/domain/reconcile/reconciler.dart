import '../models.dart';
import '../world.dart';

enum SosPhase {
  searching('SEARCHING'),
  accepted('RESPONDER ACCEPTED — DEPARTURE NOT CONFIRMED'),
  enRoute('RESPONDER EN ROUTE'),
  onScene('RESPONDER ON SCENE'),
  resolved('RESOLVED'),
  cancelled('CANCELLED BY REQUESTER'),
  expired('REQUEST EXPIRED');

  const SosPhase(this.label);

  final String label;
}

class ResponderTrack {
  ResponderTrack(this.responder);

  final String responder;
  int progress = 0;
  int firstAcceptLamport = 1 << 30;
  int lastActivityMs = 0;
  int lastLamport = 0;
  bool withdrawn = false;
  bool declined = false;
}

class SosState {
  const SosState({
    required this.sosId,
    required this.phase,
    required this.primary,
    required this.tracks,
    required this.standDown,
    required this.orphaned,
    required this.conflicts,
    required this.reopened,
    required this.onSceneStale,
  });

  final String sosId;
  final SosPhase phase;
  final String? primary;
  final Map<String, ResponderTrack> tracks;

  /// Responders who should stand down: another responder has precedence.
  final Set<String> standDown;

  /// Responders who went silent before arriving; their claim was released.
  final Set<String> orphaned;
  final List<String> conflicts;

  /// True if the SOS returned to SEARCHING after an orphaned assignment.
  final bool reopened;
  final bool onSceneStale;

  Set<String> get declinedBy => {for (final t in tracks.values) if (t.declined) t.responder};

  bool get isOpen => phase == SosPhase.searching;

  bool get isActive => phase == SosPhase.accepted || phase == SosPhase.enRoute || phase == SosPhase.onScene;
}

class ReconciliationReport {
  const ReconciliationReport({
    required this.sosCount,
    required this.doubleDispatches,
    required this.standDownsIssued,
    required this.multipleOnScene,
    required this.orphansReopened,
    required this.computedAtMs,
  });

  final int sosCount;
  final int doubleDispatches;
  final int standDownsIssued;
  final int multipleOnScene;
  final int orphansReopened;
  final int computedAtMs;

  int get conflicts => doubleDispatches + multipleOnScene;
}

/// Folds each SOS's signed event log into a state. Merging partitions is just
/// the union of event sets followed by this deterministic fold, so every node
/// that holds the same events computes the same assignment.
///
/// Precedence: ON_SCENE > EN_ROUTE > ACCEPTED, then earliest acceptance
/// (Lamport), then key order. A responder already ON_SCENE is never told to
/// stand down; two on scene are both kept and reported as a conflict.
class Reconciler {
  const Reconciler({
    this.orphanTimeout = const Duration(minutes: 10),
    this.onSceneStaleTimeout = const Duration(minutes: 30),
  });

  final Duration orphanTimeout;
  final Duration onSceneStaleTimeout;

  SosState fold(SosRecord sos, List<SosEventRecord> events, int nowMs, {required bool expired}) {
    final ordered = [...events]..sort((a, b) {
        if (a.lamport != b.lamport) return a.lamport.compareTo(b.lamport);
        return a.id.compareTo(b.id);
      });
    final tracks = <String, ResponderTrack>{};
    var cancelled = false;
    var resolved = false;

    for (final e in ordered) {
      if (e.kind == SosEventKind.cancelled) {
        // Only the requester may cancel their own SOS.
        if (e.actor == sos.origin) cancelled = true;
        continue;
      }
      if (e.actor == sos.origin) continue; // requester can't accept their own SOS
      final t = tracks.putIfAbsent(e.actor, () => ResponderTrack(e.actor));
      if (e.receivedAtMs > t.lastActivityMs) t.lastActivityMs = e.receivedAtMs;
      t.lastLamport = e.lamport;
      switch (e.kind) {
        case SosEventKind.accepted || SosEventKind.enRoute || SosEventKind.onScene || SosEventKind.resolved:
          if (e.kind.progress > t.progress) t.progress = e.kind.progress;
          if (e.lamport < t.firstAcceptLamport) t.firstAcceptLamport = e.lamport;
          t.withdrawn = false;
          if (e.kind == SosEventKind.resolved) resolved = true;
        case SosEventKind.standDown:
          // Voluntary withdrawal; ignored once on scene (never cancel at the door).
          if (t.progress < SosEventKind.onScene.progress) t.withdrawn = true;
        case SosEventKind.declined:
          if (t.progress == 0) t.declined = true;
        case SosEventKind.heartbeat || SosEventKind.cancelled:
          break;
      }
    }

    final orphaned = <String>{};
    var stale = false;
    final active = <ResponderTrack>[];
    for (final t in tracks.values) {
      if (t.progress == 0 || t.withdrawn) continue;
      final silentMs = nowMs - t.lastActivityMs;
      if (t.progress < SosEventKind.onScene.progress && silentMs > orphanTimeout.inMilliseconds) {
        orphaned.add(t.responder);
        continue;
      }
      if (t.progress == SosEventKind.onScene.progress && silentMs > onSceneStaleTimeout.inMilliseconds) {
        stale = true;
      }
      active.add(t);
    }
    active.sort((a, b) {
      if (a.progress != b.progress) return b.progress.compareTo(a.progress);
      if (a.firstAcceptLamport != b.firstAcceptLamport) return a.firstAcceptLamport.compareTo(b.firstAcceptLamport);
      return a.responder.compareTo(b.responder);
    });

    final primary = active.isEmpty ? null : active.first;
    final standDown = <String>{};
    final conflicts = <String>[];
    if (active.length > 1) {
      conflicts.add('DOUBLE_DISPATCH(${active.length} responders)');
      for (final t in active.skip(1)) {
        if (t.progress == SosEventKind.onScene.progress && primary!.progress == SosEventKind.onScene.progress) {
          if (!conflicts.contains('MULTIPLE_ON_SCENE')) conflicts.add('MULTIPLE_ON_SCENE');
        } else {
          standDown.add(t.responder);
        }
      }
    }

    final SosPhase phase;
    if (cancelled) {
      phase = SosPhase.cancelled;
    } else if (resolved) {
      phase = SosPhase.resolved;
    } else if (primary != null) {
      phase = switch (primary.progress) {
        3 => SosPhase.onScene,
        2 => SosPhase.enRoute,
        _ => SosPhase.accepted,
      };
    } else if (expired) {
      phase = SosPhase.expired;
    } else {
      phase = SosPhase.searching;
    }

    return SosState(
      sosId: sos.id,
      phase: phase,
      primary: primary?.responder,
      tracks: tracks,
      standDown: standDown,
      orphaned: orphaned,
      conflicts: conflicts,
      reopened: phase == SosPhase.searching && orphaned.isNotEmpty,
      onSceneStale: stale,
    );
  }

  ReconciliationReport report(Iterable<SosState> states, int nowMs) {
    var doubles = 0, standDowns = 0, multi = 0, orphans = 0, count = 0;
    for (final s in states) {
      count++;
      if (s.conflicts.any((c) => c.startsWith('DOUBLE_DISPATCH'))) doubles++;
      if (s.conflicts.contains('MULTIPLE_ON_SCENE')) multi++;
      standDowns += s.standDown.length;
      orphans += s.orphaned.length;
    }
    return ReconciliationReport(
      sosCount: count,
      doubleDispatches: doubles,
      standDownsIssued: standDowns,
      multipleOnScene: multi,
      orphansReopened: orphans,
      computedAtMs: nowMs,
    );
  }
}
