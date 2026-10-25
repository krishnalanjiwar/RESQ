import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import '../../../core/utils/id_generator.dart';
import '../services/mesh_service.dart';
import '../models/peer_device.dart';
import '../../../core/network/packet_protocol.dart';

/// Persistent Node ID — survives app restarts.
/// Generated once on first launch, stored in Hive 'resq_config' box.
final localNodeIdProvider = Provider<String>((ref) {
  final configBox = Hive.box<String>('resq_config');
  var nodeId = configBox.get('local_node_id');
  if (nodeId == null || nodeId.isEmpty) {
    nodeId = IdGenerator.generateNodeId();
    configBox.put('local_node_id', nodeId);
  }
  return nodeId;
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
