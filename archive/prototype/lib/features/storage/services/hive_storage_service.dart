import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/utils/app_logger.dart';
import '../models/sos_message.dart';
import '../models/mesh_node.dart';

class HiveStorageService {
  static const String sosBoxName = 'resq_sos_alerts';
  static const String nodesBoxName = 'resq_mesh_nodes';
  static const String outboxBoxName = 'resq_offline_outbox';
  static const String configBoxName = 'resq_config';

  static Future<void> init() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      AppLogger.info('Initializing Hive CE database at: ${appDir.path}');
      await Hive.initFlutter(appDir.path);

      await Hive.openBox<Map>(sosBoxName);
      await Hive.openBox<Map>(nodesBoxName);
      await Hive.openBox<Map>(outboxBoxName);
      await Hive.openBox<String>(configBoxName);

      AppLogger.info('Hive CE database boxes successfully initialized.');
    } catch (e, stack) {
      AppLogger.error('Failed to initialize Hive CE storage: $e', e, stack);
    }
  }

  // --- SOS Operations ---
  static Box<Map> get _sosBox => Hive.box<Map>(sosBoxName);

  static Future<void> saveSosMessage(SosMessage message) async {
    await _sosBox.put(message.id, message.toMap());
    AppLogger.info('Saved SOS Message: ${message.id} (Severity: ${message.severity})');
  }

  static List<SosMessage> getAllSosMessages() {
    return _sosBox.values
        .map((e) => SosMessage.fromMap(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  // --- Mesh Node Operations ---
  static Box<Map> get _nodesBox => Hive.box<Map>(nodesBoxName);

  static Future<void> upsertNode(MeshNode node) async {
    await _nodesBox.put(node.nodeId, node.toMap());
  }

  static List<MeshNode> getAllNodes() {
    return _nodesBox.values
        .map((e) => MeshNode.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  // --- Offline Outbox Operations (Store & Forward) ---
  // Bitchat spec: 24h TTL, max 8 delivery attempts
  static const Duration outboxTtl = Duration(hours: 24);
  static const int maxRetries = 8;
  static Box<Map> get _outboxBox => Hive.box<Map>(outboxBoxName);

  /// Queues a packet for later delivery with TTL and retry metadata
  static Future<void> queueOutgoingPacket(String id, Map<String, dynamic> packet) async {
    final envelope = {
      'packet': packet,
      'queuedAt': DateTime.now().millisecondsSinceEpoch,
      'retryCount': 0,
    };
    await _outboxBox.put(id, envelope);
    AppLogger.info('Queued outbox packet: $id');
  }

  /// Returns queued packets that are still within TTL and under retry budget.
  /// Auto-purges expired or exhausted entries.
  static List<Map<String, dynamic>> getQueuedPackets() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final validPackets = <Map<String, dynamic>>[];
    final keysToRemove = <dynamic>[];

    for (final key in _outboxBox.keys) {
      final raw = _outboxBox.get(key);
      if (raw == null) continue;
      final envelope = Map<String, dynamic>.from(raw);

      final queuedAt = envelope['queuedAt'] as int? ?? 0;
      final retryCount = envelope['retryCount'] as int? ?? 0;
      final age = Duration(milliseconds: now - queuedAt);

      if (age > outboxTtl || retryCount >= maxRetries) {
        keysToRemove.add(key);
        AppLogger.info('Purging stale outbox entry: $key (age: ${age.inMinutes}m, retries: $retryCount)');
        continue;
      }

      // Return the inner packet data for sending
      final packet = envelope['packet'];
      if (packet is Map) {
        validPackets.add(Map<String, dynamic>.from(packet));
      }
    }

    // Purge expired entries
    for (final key in keysToRemove) {
      _outboxBox.delete(key);
    }

    return validPackets;
  }

  /// Increments the retry counter for a queued packet
  static Future<void> incrementRetry(String id) async {
    final raw = _outboxBox.get(id);
    if (raw == null) return;
    final envelope = Map<String, dynamic>.from(raw);
    envelope['retryCount'] = ((envelope['retryCount'] as int?) ?? 0) + 1;
    await _outboxBox.put(id, envelope);
  }

  static Future<void> removeFromOutbox(String id) async {
    await _outboxBox.delete(id);
  }
}
