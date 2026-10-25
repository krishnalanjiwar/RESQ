import 'dart:collection';

/// Bounded "seen" set for message-id deduplication with expiry.
class SeenCache {
  SeenCache({this.capacity = 8000});

  final int capacity;
  final LinkedHashMap<String, int> _expiryById = LinkedHashMap();

  bool contains(String id) => _expiryById.containsKey(id);

  /// Returns false if [id] was already present.
  bool add(String id, int expiresAtMs) {
    if (_expiryById.containsKey(id)) return false;
    _expiryById[id] = expiresAtMs;
    while (_expiryById.length > capacity) {
      _expiryById.remove(_expiryById.keys.first);
    }
    return true;
  }

  void prune(int nowMs) => _expiryById.removeWhere((_, exp) => exp <= nowMs);

  void clear() => _expiryById.clear();

  int get length => _expiryById.length;
}

/// Classic token bucket.
class TokenBucket {
  TokenBucket({required this.capacity, required this.refillPerSecond, required int nowMs})
      : _tokens = capacity.toDouble(),
        _lastMs = nowMs;

  final int capacity;
  final double refillPerSecond;
  double _tokens;
  int _lastMs;

  bool tryTake(int nowMs) {
    final elapsed = (nowMs - _lastMs).clamp(0, 1 << 31) / 1000.0;
    _tokens = (_tokens + elapsed * refillPerSecond).clamp(0, capacity.toDouble());
    _lastMs = nowMs;
    if (_tokens < 1) return false;
    _tokens -= 1;
    return true;
  }
}

/// Per-key token buckets with strike counting and temporary quarantine.
class FloodGuard {
  FloodGuard({
    required this.capacity,
    required this.refillPerSecond,
    required this.strikesBeforeQuarantine,
    required this.quarantine,
  });

  final int capacity;
  final double refillPerSecond;
  final int strikesBeforeQuarantine;
  final Duration quarantine;

  final Map<String, TokenBucket> _buckets = {};
  final Map<String, int> _strikes = {};
  final Map<String, int> _quarantinedUntil = {};

  bool isQuarantined(String key, int nowMs) => (_quarantinedUntil[key] ?? 0) > nowMs;

  /// Returns null if allowed, otherwise a reason code. Sets [newlyQuarantined]
  /// via the return value 'QUARANTINED_NOW' the moment the threshold is crossed.
  String? check(String key, int nowMs) {
    if (isQuarantined(key, nowMs)) return 'QUARANTINED';
    final bucket = _buckets.putIfAbsent(
      key,
      () => TokenBucket(capacity: capacity, refillPerSecond: refillPerSecond, nowMs: nowMs),
    );
    if (bucket.tryTake(nowMs)) return null;
    final strikes = (_strikes[key] ?? 0) + 1;
    _strikes[key] = strikes;
    if (strikes >= strikesBeforeQuarantine) {
      _quarantinedUntil[key] = nowMs + quarantine.inMilliseconds;
      _strikes[key] = 0;
      return 'QUARANTINED_NOW';
    }
    return 'RATE_LIMITED';
  }

  Set<String> quarantinedKeys(int nowMs) =>
      {for (final e in _quarantinedUntil.entries) if (e.value > nowMs) e.key};

  void forget(String key) {
    _buckets.remove(key);
    _strikes.remove(key);
  }
}

/// Sliding-window counter for per-origin relay limits.
class WindowCounter {
  WindowCounter(this.window);

  final Duration window;
  final Map<String, Queue<int>> _events = {};

  /// Records an event for [key] and returns the count inside the window.
  int hit(String key, int nowMs) {
    final q = _events.putIfAbsent(key, Queue.new);
    q.addLast(nowMs);
    while (q.isNotEmpty && q.first <= nowMs - window.inMilliseconds) {
      q.removeFirst();
    }
    return q.length;
  }
}
