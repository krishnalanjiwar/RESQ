import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../ui/icons.dart';
import 'widgets.dart';

/// Mesh status card: one switch to turn the mesh on (where permissions are
/// requested), the radio's real state, and anything that blocks it.
class MeshBar extends ConsumerWidget {
  const MeshBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(nodeVersionProvider);
    final node = ref.watch(nodeProvider);
    final device = ref.watch(deviceControllerProvider);
    final ctrl = ref.read(deviceControllerProvider.notifier);
    final t = Theme.of(context).textTheme;
    final peers = node.transport.connectedPeers.length;
    final radioUp = device.meshOn && node.transportRunning;

    final problems = <String>[
      if (device.bluetoothOff) 'Bluetooth is off. Turn it on to reach nearby phones.',
      if (device.locationServicesOff) 'Location services are off. Discovery may fail on older Android.',
      if (node.clockWarning)
        'This phone\'s clock differs from nearby phones by ${node.clockOffset!.inMinutes.abs()} min. Set the correct time.',
      if (device.meshOn && !node.transportRunning) 'The radio is not running: ${node.transportDetail}.',
      if (device.meshOn && !device.foregroundRunning) 'Background relay is not active. Keep RES-Q open.',
      ...?device.permissions?.warnings,
    ];

    final String title;
    final String subtitle;
    final Tone tone;
    if (!device.meshOn) {
      title = 'Mesh is off';
      subtitle = device.permissions != null && !device.permissions!.radioGranted
          ? 'Bluetooth access is needed to reach nearby phones without internet.'
          : 'Turn on to reach nearby phones over Bluetooth and Wi-Fi. No internet needed.';
      tone = Tone.neutral;
    } else if (!radioUp) {
      title = 'Radio not running';
      subtitle = 'Mesh is switched on but the radio has not started.';
      tone = Tone.danger;
    } else {
      title = peers == 0 ? 'Searching for nearby phones' : 'Connected to $peers nearby phone${peers == 1 ? '' : 's'}';
      subtitle = peers == 0 ? 'Messages are saved and sent when a phone comes in range.' : 'Messages hop phone to phone.';
      tone = peers == 0 ? Tone.warn : Tone.good;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            IconCircle(device.meshOn ? ResqIcons.mesh : ResqIcons.meshOff, tone: tone),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle, style: t.bodySmall),
              ]),
            ),
            if (device.busy)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
              )
            else
              Switch(
                value: device.meshOn,
                onChanged: (on) => on ? ctrl.enableMesh() : ctrl.disableMesh(),
              ),
          ]),
          if (problems.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final p in problems)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InfoRow(ResqIcons.warning, p, tone: Tone.danger),
              ),
          ],
          if (device.meshOn && !node.transportRunning || (device.permissions?.anyPermanentlyDenied ?? false))
            Padding(
              padding: const EdgeInsets.only(top: 8, right: 8),
              child: Wrap(spacing: 8, children: [
                if (device.meshOn && !node.transportRunning)
                  FilledButton.tonalIcon(
                    onPressed: ctrl.enableMesh,
                    icon: AppIcon(ResqIcons.refresh, size: 18),
                    label: const Text('Retry'),
                  ),
                if (device.permissions?.anyPermanentlyDenied ?? false)
                  OutlinedButton(onPressed: ctrl.openSettings, child: const Text('Open settings')),
              ]),
            ),
        ]),
      ),
    );
  }
}
