import 'package:flutter_test/flutter_test.dart';
import 'package:resq/domain/models.dart';
import 'package:resq/domain/reconcile/reconciler.dart';
import 'package:resq/domain/world.dart';

const _now = 1700000000000;

SosRecord _sos() => SosRecord(
      id: 'a' * 32,
      origin: 'victim',
      claimedAtMs: _now - 60000,
      receivedAtMs: _now - 60000,
      hopAtReceipt: 1,
      urgency: Urgency.critical,
      needs: {Need.medical},
      sealed: false,
      readable: true,
    );

int _n = 0;
SosEventRecord _e(String actor, SosEventKind kind, int lamport, {int agoMs = 1000}) => SosEventRecord(
      id: (_n++).toString().padLeft(32, '0'),
      sosId: 'a' * 32,
      actor: actor,
      kind: kind,
      lamport: lamport,
      claimedAtMs: _now - agoMs,
      receivedAtMs: _now - agoMs,
    );

void main() {
  const r = Reconciler();

  test('double dispatch after partition: earliest acceptance keeps it, other stands down', () {
    final s = r.fold(_sos(), [_e('east', SosEventKind.accepted, 5), _e('west', SosEventKind.accepted, 3)], _now, expired: false);
    expect(s.primary, 'west');
    expect(s.standDown, {'east'});
    expect(s.conflicts.first, startsWith('DOUBLE_DISPATCH'));
  });

  test('responder already on scene is never told to stand down', () {
    final s = r.fold(_sos(), [
      _e('early', SosEventKind.accepted, 1),
      _e('late', SosEventKind.accepted, 9),
      _e('late', SosEventKind.onScene, 10),
    ], _now, expired: false);
    expect(s.primary, 'late');
    expect(s.standDown, {'early'});
    expect(s.standDown.contains('late'), isFalse);
  });

  test('two on scene: both kept, conflict reported', () {
    final s = r.fold(_sos(), [
      _e('a', SosEventKind.onScene, 2),
      _e('b', SosEventKind.onScene, 3),
    ], _now, expired: false);
    expect(s.standDown, isEmpty);
    expect(s.conflicts, contains('MULTIPLE_ON_SCENE'));
  });

  test('orphaned assignment reopens the SOS; on-scene silence never does', () {
    final orphan = r.fold(_sos(), [_e('gone', SosEventKind.accepted, 1, agoMs: 20 * 60000)], _now, expired: false);
    expect(orphan.phase, SosPhase.searching);
    expect(orphan.reopened, isTrue);
    final quietOnScene = r.fold(_sos(), [_e('busy', SosEventKind.onScene, 1, agoMs: 20 * 60000)], _now, expired: false);
    expect(quietOnScene.phase, SosPhase.onScene);
  });

  test('stale SEARCHING-era events after ACCEPTED do not regress state; order-independent', () {
    final events = [
      _e('x', SosEventKind.accepted, 1),
      _e('x', SosEventKind.enRoute, 2),
      _e('y', SosEventKind.declined, 3),
      _e('z', SosEventKind.accepted, 4),
    ];
    final a = r.fold(_sos(), events, _now, expired: false);
    final b = r.fold(_sos(), events.reversed.toList(), _now, expired: false);
    expect(a.phase, SosPhase.enRoute);
    expect(a.primary, b.primary);
    expect(a.standDown, b.standDown);
  });

  test('only the requester can cancel', () {
    final s = r.fold(_sos(), [_e('stranger', SosEventKind.cancelled, 1)], _now, expired: false);
    expect(s.phase, SosPhase.searching);
    final c = r.fold(_sos(), [_e('victim', SosEventKind.cancelled, 1)], _now, expired: false);
    expect(c.phase, SosPhase.cancelled);
  });

  test('report counts come from computed states', () {
    final states = [
      r.fold(_sos(), [_e('p', SosEventKind.accepted, 1), _e('q', SosEventKind.accepted, 2)], _now, expired: false),
      r.fold(_sos(), const [], _now, expired: false),
    ];
    final rep = r.report(states, _now);
    expect(rep.doubleDispatches, 1);
    expect(rep.standDownsIssued, 1);
    expect(rep.sosCount, 2);
  });
}
