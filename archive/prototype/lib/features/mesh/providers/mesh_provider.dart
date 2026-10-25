import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/id_generator.dart';
import '../services/mesh_service.dart';
import '../models/peer_device.dart';
import '../../../core/network/packet_protocol.dart';

// Local Node ID
final localNodeIdProvider = Provider<String>((ref) {
  return IdGenerator.generateNodeId();
});

// Singleton MeshService
final meshServiceProvider = Provider<MeshService>((ref) {
  final nodeId = ref.watch(localNodeIdProvider);
  final service = MeshService(localNodeId: nodeId);
  service.startMesh();
  ref.onDispose(() => service.stopMesh());
  return service;
});

// Stream of discovered & connected peers
final meshPeersProvider = StreamProvider<List<PeerDevice>>((ref) {
  final service = ref.watch(meshServiceProvider);
  return service.peerStream;
});

// Stream of incoming mesh packets
final meshPacketsProvider = StreamProvider<MeshPacket>((ref) {
  final service = ref.watch(meshServiceProvider);
  return service.packetStream;
});
