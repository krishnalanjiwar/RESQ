import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../domain/models.dart';
import 'widgets.dart';

/// Reports a hazard at the user's current location. Requires a real fix:
/// hazards are never placed at made-up coordinates.
Future<void> showHazardDialog(BuildContext context, WidgetRef ref) async {
  final kind = await showDialog<HazardKind>(
    context: context,
    builder: (ctx) => SimpleDialog(
      shape: const RoundedRectangleBorder(side: BorderSide(color: ResqTheme.white)),
      backgroundColor: ResqTheme.black,
      title: const Text('REPORT HAZARD AT MY LOCATION', style: TextStyle(fontSize: 14)),
      children: [
        for (final k in HazardKind.values)
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, k), child: Text('[ ${k.label} ]')),
      ],
    ),
  );
  if (kind == null || !context.mounted) return;
  final fix = await ref.read(deviceControllerProvider.notifier).refreshLocation();
  if (!context.mounted) return;
  if (fix == null) {
    notify(context, 'HAZARD NOT SENT — LOCATION NOT AVAILABLE');
    return;
  }
  await ref.read(nodeProvider).reportHazard(kind: kind, center: fix.point, radiusM: fix.accuracyM.clamp(100, 500).toDouble());
  if (context.mounted) notify(context, '${kind.label} HAZARD SAVED AND SHARED WITH CONNECTED PEERS');
}
