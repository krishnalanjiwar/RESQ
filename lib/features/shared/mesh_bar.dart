import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'widgets.dart';

/// Radio status strip with the explicit "turn mesh on" action, where the
/// permission request happens.
class MeshBar extends ConsumerWidget {
  const MeshBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(nodeVersionProvider);
    final node = ref.watch(nodeProvider);
    final device = ref.watch(deviceControllerProvider);
    final ctrl = ref.read(deviceControllerProvider.notifier);
    final peers = node.transport.connectedPeers.length;

    if (!device.meshOn) {
      return Boxed(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('MESH OFF', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            device.permissions != null && !device.permissions!.radioGranted
                ? '${device.permissions!.label}. Nearby-device access is needed to reach other phones without internet.'
                : 'Turn on to exchange messages with nearby phones over Bluetooth / Wi-Fi. No internet needed.',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          ActionButton(device.busy ? 'STARTING…' : 'TURN ON MESH', primary: true, onPressed: device.busy ? null : ctrl.enableMesh),
          if (device.permissions?.anyPermanentlyDenied ?? false)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ActionButton('OPEN SETTINGS', dense: true, onPressed: ctrl.openSettings),
            ),
        ]),
      );
    }
    return Boxed(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        Expanded(
          child: Text(
            'MESH ON · $peers PEER${peers == 1 ? '' : 'S'}'
            '${device.foregroundRunning ? '' : ' · BACKGROUND DISCOVERY NOT ACTIVE'}'
            '${node.powerPolicy.isSimulatedOverride ? ' · SIM BATTERY' : ''}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        TextButton(onPressed: ctrl.disableMesh, child: const Text('[ OFF ]')),
      ]),
    );
  }
}
