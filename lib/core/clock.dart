/// Time source. Domain logic never calls `DateTime.now()` directly so the
/// simulator can run many nodes deterministically on a shared virtual clock.
abstract interface class Clock {
  int nowMs();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  int nowMs() => DateTime.now().millisecondsSinceEpoch;
}

/// Manually advanced clock used by the simulator and tests.
class ManualClock implements Clock {
  ManualClock([int? startMs]) : _now = startMs ?? DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;

  int _now;

  @override
  int nowMs() => _now;

  void advance(Duration d) => _now += d.inMilliseconds;
}
