import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/utils/app_logger.dart';
import '../models/sos_message.dart';
import '../models/mesh_node.dart';

class HiveStorageService {
  static const String sosBoxName = 'resq_sos_alerts';
  static const String nodesBoxName = 'resq_mesh_nodes';
  static const String outboxBoxName = 'resq_offline_outbox';

  static Future<void> init() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      AppLogger.info('Initializing Hive CE database at: ${appDir.path}');
      await Hive.initFlutter(appDir.path);

      await Hive.openBox<Map>(sosBoxName);
      await Hive.openBox<Map>(nodesBoxName);
      await Hive.openBox<Map>(outboxBoxName);

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
  static Box<Map> get _outboxBox => Hive.box<Map>(outboxBoxName);

  static Future<void> queueOutgoingPacket(String id, Map<String, dynamic> packet) async {
    await _outboxBox.put(id, packet);
  }

  static List<Map<String, dynamic>> getQueuedPackets() {
    return _outboxBox.values
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static Future<void> removeFromOutbox(String id) async {
    await _outboxBox.delete(id);
  }
}
