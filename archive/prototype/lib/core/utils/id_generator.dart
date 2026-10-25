import 'package:uuid/uuid.dart';

class IdGenerator {
  static const Uuid _uuid = Uuid();

  /// Generates a globally unique v4 ID for SOS messages and packets
  static String generateMessageId() {
    return 'msg_${_uuid.v4()}';
  }

  /// Generates a unique node ID for peer mesh identification
  static String generateNodeId() {
    return 'node_${_uuid.v4().substring(0, 8)}';
  }
}
