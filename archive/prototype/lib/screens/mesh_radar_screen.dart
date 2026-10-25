import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/constants/app_colors.dart';
import '../features/mesh/providers/mesh_provider.dart';
import '../features/mesh/models/peer_device.dart';

class MeshRadarScreen extends ConsumerWidget {
  const MeshRadarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peersAsync = ref.watch(meshPeersProvider);
    final localNodeId = ref.watch(localNodeIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('P2P MESH TOPOLOGY'),
      ),
      body: Column(
        children: [
          // Visual Animated Radar Banner
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            color: AppColors.surface,
            width: double.infinity,
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.meshRelay.withOpacity(0.4),
                          width: 2,
                        ),
                      ),
                    )
                        .animate(onPlay: (c) => c.repeat())
                        .scale(begin: const Offset(0.5, 0.5), end: const Offset(1.5, 1.5), duration: 2000.ms)
                        .fade(begin: 1.0, end: 0.0),
                    Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.meshRelay,
                      ),
                      child: const Icon(Icons.router, color: Colors.white, size: 28),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Local Node: $localNodeId',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Google Nearby Connections P2P Cluster Mesh',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'ACTIVE RADIO NEIGHBORS',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'AUTO-RELAY ACTIVE',
                  style: TextStyle(
                    color: AppColors.successGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: peersAsync.when(
              data: (peers) {
                if (peers.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.wifi_find, color: AppColors.textMuted, size: 48),
                          SizedBox(height: 12),
                          Text(
                            'Scanning for Nearby Devices...',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Make sure other rescue phones or victim beacons have Bluetooth and Location enabled.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: peers.length,
                  itemBuilder: (context, index) {
                    final peer = peers[index];
                    final isConnected = peer.state == PeerConnectionState.connected;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isConnected
                              ? AppColors.successGreen.withOpacity(0.2)
                              : AppColors.warningOrange.withOpacity(0.2),
                          child: Icon(
                            isConnected ? Icons.link : Icons.link_off,
                            color: isConnected ? AppColors.successGreen : AppColors.warningOrange,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          peer.endpointName.isNotEmpty ? peer.endpointName : peer.endpointId,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text(
                          'Endpoint: ${peer.endpointId} • Signal: ${peer.rssi} dBm',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isConnected
                                ? AppColors.successGreen.withOpacity(0.15)
                                : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isConnected ? AppColors.successGreen : AppColors.surfaceLight,
                            ),
                          ),
                          child: Text(
                            peer.state.name.toUpperCase(),
                            style: TextStyle(
                              color: isConnected ? AppColors.successGreen : AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Mesh Error: $err')),
            ),
          ),
        ],
      ),
    );
  }
}
