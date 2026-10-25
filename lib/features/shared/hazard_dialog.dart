import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models.dart';
import '../../ui/icons.dart';
import 'widgets.dart';

String _hazardIcon(HazardKind k) => switch (k) {
      HazardKind.flood => ResqIcons.water,
      HazardKind.fire => ResqIcons.flame,
      HazardKind.collapse => ResqIcons.building,
      HazardKind.other => ResqIcons.hazard,
    };

String _hazardLabel(HazardKind k) => switch (k) {
      HazardKind.flood => 'Flooding',
      HazardKind.fire => 'Fire',
      HazardKind.collapse => 'Collapsed building',
      HazardKind.other => 'Other danger',
    };

/// Reports a hazard at the user's current location. Requires a real GPS fix:
/// hazards are never placed at made-up coordinates.
Future<void> showHazardDialog(BuildContext context, WidgetRef ref) async {
  final kind = await showModalBottomSheet<HazardKind>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Text('Report a danger at your location', style: Theme.of(ctx).textTheme.titleMedium),
        ),
        for (final k in HazardKind.values)
          ListTile(
            leading: IconCircle(_hazardIcon(k), tone: Tone.danger, size: 36),
            title: Text(_hazardLabel(k)),
            onTap: () => Navigator.pop(ctx, k),
          ),
        const SizedBox(height: 8),
      ]),
    ),
  );
  if (kind == null || !context.mounted) return;

  final radius = await showModalBottomSheet<double>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Text('How large is the affected area?', style: Theme.of(ctx).textTheme.titleMedium),
        ),
        for (final (label, sub, metres) in const [
          ('Small', 'About 100 m around you', 100.0),
          ('Street or block', 'About 250 m around you', 250.0),
          ('Large area', 'About 500 m around you', 500.0),
        ])
          ListTile(title: Text(label), subtitle: Text(sub), onTap: () => Navigator.pop(ctx, metres)),
        const SizedBox(height: 8),
      ]),
    ),
  );
  if (radius == null || !context.mounted) return;

  final fix = await ref.read(deviceControllerProvider.notifier).refreshLocation();
  if (!context.mounted) return;
  if (fix == null) {
    notify(context, 'Not sent: your location is not available.');
    return;
  }
  // A poor GPS fix widens the zone: the hazard covers at least the fix's uncertainty.
  final effective = radius > fix.accuracyM ? radius : fix.accuracyM.clamp(radius, 2000).toDouble();
  await ref.read(nodeProvider).reportHazard(kind: kind, center: fix.point, radiusM: effective);
  if (context.mounted) notify(context, '${_hazardLabel(kind)} reported and shared with nearby phones.');
}
