import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'widgets.dart';

/// Radio status strip with the explicit "turn mesh on" action, where the
/// permission request happens. It reports the radio's real state: user intent
/// ("on") is never shown as a working radio if the radio isn't running.
class MeshBar extends ConsumerWidget {
  const MeshBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(nodeVersionProvider);
    final node = ref.watch(nodeProvider);
    final device = ref.watch(deviceControllerProvider);
    final ctrl = ref.read(deviceControllerProvider.notifier);
    final peers = node.transport.connectedPeers.length;

    final problems = <String>[
      if (device.bluetoothOff) 'BLUETOOTH IS OFF — turn it on to reach nearby phones',
      if (device.locationServicesOff) 'LOCATION SERVICES OFF — discovery may fail on older Android',
      if (node.clockWarning)
        'THIS PHONE\'S CLOCK DIFFERS FROM NEARBY PHONES BY ${node.clockOffset!.inMinutes.abs()} MIN — set the correct time',
      ...?device.permissions?.warnings,
    ];

    Widget problemList() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final p in problems) Text('⚠ $p', style: const TextStyle(fontSize: 11)),
        ]);

    if (!device.meshOn) {
      return Boxed(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('MESH OFF', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            device.permissions != null && !device.permissions!.radioGranted
                ? '${device.permissions!.label}. Bluetooth access is needed to reach other phones without internet.'
                : 'Turn on to exchange messages with nearby phones over Bluetooth / Wi-Fi. No internet needed.',
            style: const TextStyle(fontSize: 12),
          ),
          if (problems.isNotEmpty) ...[const SizedBox(height: 4), problemList()],
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

    final radioUp = node.transportRunning;
    final headline = radioUp
        ? 'MESH ON · $peers PEER${peers == 1 ? '' : 'S'}'
        : 'MESH ON — RADIO NOT RUNNING (${node.transportDetail})';
    return Boxed(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      thick: !radioUp || problems.isNotEmpty,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Text(
              '$headline'
              '${device.foregroundRunning ? '' : ' · BACKGROUND DISCOVERY NOT ACTIVE'}'
              '${node.powerPolicy.isSimulatedOverride ? ' · SIM BATTERY' : ''}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          if (!radioUp) TextButton(onPressed: ctrl.enableMesh, child: const Text('[ RETRY ]')),
          TextButton(onPressed: ctrl.disableMesh, child: const Text('[ OFF ]')),
        ]),
        if (problems.isNotEmpty) problemList(),
      ]),
    );
  }
}
