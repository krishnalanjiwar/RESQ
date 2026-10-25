import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/constants/app_colors.dart';
import '../core/permissions/permission_service.dart';
import '../features/battery/providers/battery_provider.dart';
import '../features/mesh/providers/mesh_provider.dart';
import '../features/sos/providers/sos_provider.dart';
import '../features/sos/widgets/sos_pulse_button.dart';
import 'mesh_radar_screen.dart';
import 'ai_triage_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _showSosDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    String selectedType = 'Medical Emergency';
    String selectedSeverity = 'Immediate (Red)';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: AppColors.emergencyRed, size: 28),
                      const SizedBox(width: 8),
                      const Text(
                        'BROADCAST SOS BEACON',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Victim / Group Name (Optional)',
                      labelStyle: const TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.surfaceLight.withOpacity(0.4),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    dropdownColor: AppColors.surface,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Emergency Type',
                      labelStyle: const TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.surfaceLight.withOpacity(0.4),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Medical Emergency', child: Text('Medical Emergency')),
                      DropdownMenuItem(value: 'Trapped / Collapsed Structure', child: Text('Trapped / Collapsed')),
                      DropdownMenuItem(value: 'Flash Flood / Water Rescue', child: Text('Flash Flood')),
                      DropdownMenuItem(value: 'Wildfire', child: Text('Wildfire')),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedType = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Situation Details & Casualties',
                      labelStyle: const TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.surfaceLight.withOpacity(0.4),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emergencyRed,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: const Icon(Icons.wifi_tethering_rounded),
                    label: const Text('TRANSMIT TO OFFLINE MESH'),
                    onPressed: () {
                      ref.read(sosNotifierProvider.notifier).sendSosBeacon(
                            victimName: nameController.text,
                            emergencyType: selectedType,
                            description: descController.text,
                            severity: selectedSeverity,
                          );
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('SOS Beacon transmitted to P2P mesh network!'),
                          backgroundColor: AppColors.emergencyRed,
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localNodeId = ref.watch(localNodeIdProvider);
    final peersAsync = ref.watch(meshPeersProvider);
    final batteryAsync = ref.watch(batteryStatusProvider);
    final sosMessages = ref.watch(sosListProvider);
    final isBroadcasting = ref.watch(sosNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.emergencyRed.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.security, color: AppColors.emergencyRed, size: 22),
            ),
            const SizedBox(width: 10),
            const Text('RESQ MESH'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Request Mesh Permissions',
            icon: const Icon(Icons.bluetooth_searching, color: AppColors.infoBlue),
            onPressed: () async {
              final granted = await PermissionService.requestMeshPermissions();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(granted
                      ? 'Bluetooth & Mesh permissions granted!'
                      : 'Please grant all Bluetooth and Location permissions in Settings.'),
                  backgroundColor: granted ? AppColors.successGreen : AppColors.warningOrange,
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'View Mesh Radar',
            icon: const Icon(Icons.radar, color: AppColors.meshRelay),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MeshRadarScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Header Banner
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('NODE: $localNodeId',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.infoBlue,
                                  fontSize: 13)),
                          const SizedBox(height: 4),
                          peersAsync.when(
                            data: (peers) => Text(
                              '${peers.length} Peers Discovered / Connected',
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 12),
                            ),
                            loading: () => const Text('Scanning BLE radio...',
                                style: TextStyle(
                                    color: AppColors.textSecondary, fontSize: 12)),
                            error: (_, __) => const Text('Radio Idle',
                                style: TextStyle(
                                    color: AppColors.textSecondary, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                    // Battery & Routing Cost Indicator
                    batteryAsync.when(
                      data: (battery) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.side(
                            color: battery.level < 20
                                ? AppColors.batteryLow
                                : AppColors.successGreen,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              battery.level < 20
                                  ? Icons.battery_alert
                                  : Icons.battery_charging_full,
                              color: battery.level < 20
                                  ? AppColors.batteryLow
                                  : AppColors.successGreen,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${battery.level}% (Cost: ${battery.routingCost.toInt()}x)',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Pulsing Central SOS Button
            Center(
              child: SosPulseButton(
                isBroadcasting: isBroadcasting,
                onPressed: () => _showSosDialog(context, ref),
              ),
            ),
            const SizedBox(height: 28),

            // Navigation Action Cards
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AiTriageScreen()),
                      );
                    },
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: const [
                            Icon(Icons.psychology, color: AppColors.infoBlue, size: 36),
                            SizedBox(height: 8),
                            Text('On-Device AI',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14)),
                            SizedBox(height: 4),
                            Text('Offline Triage',
                                style: TextStyle(
                                    color: AppColors.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MeshRadarScreen()),
                      );
                    },
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: const [
                            Icon(Icons.radar, color: AppColors.meshRelay, size: 36),
                            SizedBox(height: 8),
                            Text('P2P Mesh Nodes',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14)),
                            SizedBox(height: 4),
                            Text('Radio Topology',
                                style: TextStyle(
                                    color: AppColors.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Emergency Log / Hive CE Stored Beacons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ACTIVE SOS BROADCASTS',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${sosMessages.length} LOGGED',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (sosMessages.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: const [
                      Icon(Icons.check_circle_outline,
                          color: AppColors.successGreen, size: 40),
                      SizedBox(height: 8),
                      Text('No Active Emergency Beacons',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary)),
                      SizedBox(height: 4),
                      Text(
                          'Your node is listening on BLE/Nearby mesh channels.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
              )
            else
              ...sosMessages.map((msg) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.emergencyRed.withOpacity(0.2),
                        child: const Icon(Icons.crisis_alert,
                            color: AppColors.emergencyRed, size: 20),
                      ),
                      title: Text('${msg.emergencyType} (${msg.victimName})',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(
                          '${msg.description.isNotEmpty ? msg.description : "No details provided"} • Hops: ${msg.hopCount}',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.emergencyRed.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          msg.severity.split(' ').first.toUpperCase(),
                          style: const TextStyle(
                              color: AppColors.emergencyRed,
                              fontWeight: FontWeight.bold,
                              fontSize: 10),
                        ),
                      ),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
