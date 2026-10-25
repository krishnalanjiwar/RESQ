import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';

/// One persisted, already-verified envelope plus local receipt metadata.
class StoredEnvelope {
  const StoredEnvelope({required this.json, required this.receivedAtMs, this.via, this.hopAtReceipt = 0});

  final String json;
  final int receivedAtMs;
  final String? via;
  final int hopAtReceipt;

  String encode() => jsonEncode({'w': json, 'r': receivedAtMs, 'via': via, 'h': hopAtReceipt});

  static StoredEnvelope? decode(String raw) {
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return StoredEnvelope(
        json: m['w'] as String,
        receivedAtMs: m['r'] as int,
        via: m['via'] as String?,
        hopAtReceipt: (m['h'] as int?) ?? 0,
      );
    } on Object {
      return null; // corrupted record: skipped, never crashes startup
    }
  }
}

/// Local persistence. Node state is event-sourced: it is rebuilt at startup by
/// replaying stored envelopes, so storage holds signed facts, not mutable blobs.
/// Records are versioned JSON (no code generation, explicit migrations).
abstract interface class ResqStore {
  static const int schemaVersion = 1;

  Iterable<(String, StoredEnvelope)> envelopes();
  Future<void> putEnvelope(String id, StoredEnvelope env);
  Future<void> deleteEnvelope(String id);

  String? getMeta(String key);
  Future<void> putMeta(String key, String value);
  Future<void> deleteMeta(String key);

  /// Deletes all local report data (retention / user request).
  Future<void> wipe();
}

class HiveResqStore implements ResqStore {
  HiveResqStore._(this._envelopes, this._meta);

  final Box<String> _envelopes;
  final Box<String> _meta;

  static const String _envelopesBox = 'envelopes_v2';
  static const String _metaBox = 'meta_v2';

  /// Opens the encrypted boxes with a 32-byte [key] held in the Android
  /// Keystore. If the boxes can't be opened (key lost after reinstall or
  /// corrupted files) they are deleted and recreated: the app starts with
  /// empty local data instead of refusing to start.
  static Future<HiveResqStore> open(List<int> key) async {
    await Hive.initFlutter('resq');
    final cipher = HiveAesCipher(key);
    Future<Box<String>> openOrReset(String name) async {
      try {
        return await Hive.openBox<String>(name, encryptionCipher: cipher);
      } on Object {
        await Hive.deleteBoxFromDisk(name);
        return Hive.openBox<String>(name, encryptionCipher: cipher);
      }
    }

    // Unencrypted boxes from 0.8.0 builds are removed: their data must not stay readable on disk.
    for (final legacy in ['envelopes_v1', 'meta_v1']) {
      if (await Hive.boxExists(legacy)) await Hive.deleteBoxFromDisk(legacy);
    }
    final envelopes = await openOrReset(_envelopesBox);
    final meta = await openOrReset(_metaBox);
    if (meta.get('schema') == null) await meta.put('schema', '${ResqStore.schemaVersion}');
    return HiveResqStore._(envelopes, meta);
  }

  @override
  Iterable<(String, StoredEnvelope)> envelopes() sync* {
    for (final key in _envelopes.keys) {
      final raw = _envelopes.get(key);
      final env = raw == null ? null : StoredEnvelope.decode(raw);
      if (env != null) yield (key as String, env);
    }
  }

  @override
  Future<void> putEnvelope(String id, StoredEnvelope env) => _envelopes.put(id, env.encode());

  @override
  Future<void> deleteEnvelope(String id) => _envelopes.delete(id);

  @override
  String? getMeta(String key) => _meta.get(key);

  @override
  Future<void> putMeta(String key, String value) => _meta.put(key, value);

  @override
  Future<void> deleteMeta(String key) => _meta.delete(key);

  @override
  Future<void> wipe() async {
    await _envelopes.clear();
    final keep = {'schema': _meta.get('schema')};
    await _meta.clear();
    for (final e in keep.entries) {
      if (e.value != null) await _meta.put(e.key, e.value!);
    }
  }
}

/// Used by simulated nodes and tests. Simulation data never touches the device database.
class MemoryResqStore implements ResqStore {
  final Map<String, StoredEnvelope> _envelopes = {};
  final Map<String, String> _meta = {};

  @override
  Iterable<(String, StoredEnvelope)> envelopes() => _envelopes.entries.map((e) => (e.key, e.value));

  @override
  Future<void> putEnvelope(String id, StoredEnvelope env) async => _envelopes[id] = env;

  @override
  Future<void> deleteEnvelope(String id) async => _envelopes.remove(id);

  @override
  String? getMeta(String key) => _meta[key];

  @override
  Future<void> putMeta(String key, String value) async => _meta[key] = value;

  @override
  Future<void> deleteMeta(String key) async => _meta.remove(key);

  @override
  Future<void> wipe() async {
    _envelopes.clear();
    _meta.clear();
  }
}
