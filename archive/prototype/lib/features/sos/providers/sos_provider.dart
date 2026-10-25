import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/id_generator.dart';
import '../../storage/models/sos_message.dart';
import '../../storage/services/hive_storage_service.dart';
import '../../mesh/providers/mesh_provider.dart';

final sosListProvider = StateProvider<List<SosMessage>>((ref) {
  return HiveStorageService.getAllSosMessages();
});

class SosNotifier extends StateNotifier<bool> {
  final Ref _ref;

  SosNotifier(this._ref) : super(false);

  Future<void> sendSosBeacon({
    required String victimName,
    required String emergencyType,
    required String description,
    required String severity,
    double? latitude,
    double? longitude,
  }) async {
    state = true; // Broadcasting
    final meshService = _ref.read(meshServiceProvider);
    final nodeId = _ref.read(localNodeIdProvider);

    final sos = SosMessage(
      id: IdGenerator.generateMessageId(),
      senderId: nodeId,
      victimName: victimName.isEmpty ? 'Anonymous' : victimName,
      emergencyType: emergencyType,
      description: description,
      severity: severity,
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    await meshService.broadcastSos(sos);
    _ref.read(sosListProvider.notifier).state = HiveStorageService.getAllSosMessages();
    state = false;
  }
}

final sosNotifierProvider = StateNotifierProvider<SosNotifier, bool>((ref) {
  return SosNotifier(ref);
});
