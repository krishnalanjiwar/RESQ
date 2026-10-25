import 'dart:collection';

enum LogCategory { mesh, security, trust, dispatch, reconcile, power, storage, sim, system }

/// One diagnostic event. Never carries raw victim text, exact coordinates or keys:
/// callers pass short codes plus redacted details only.
class LogEntry {
  const LogEntry(this.atMs, this.category, this.code, this.detail);

  final int atMs;
  final LogCategory category;
  final String code;
  final String detail;
}

/// Bounded in-memory ring buffer feeding the diagnostics drawer.
class EventLog {
  EventLog({this.capacity = 300});

  final int capacity;
  final Queue<LogEntry> _entries = Queue();
  final Map<String, int> _counts = {};

  void add(int atMs, LogCategory category, String code, [String detail = '']) {
    _entries.addFirst(LogEntry(atMs, category, code, detail));
    while (_entries.length > capacity) {
      _entries.removeLast();
    }
    _counts[code] = (_counts[code] ?? 0) + 1;
  }

  List<LogEntry> get entries => List.unmodifiable(_entries);

  int count(String code) => _counts[code] ?? 0;

  Map<String, int> get counts => Map.unmodifiable(_counts);

  void clear() {
    _entries.clear();
    _counts.clear();
  }
}

/// Short, non-reversible label for an identity key, safe for logs.
String shortKey(String key) => key.length <= 8 ? key : key.substring(0, 8);
