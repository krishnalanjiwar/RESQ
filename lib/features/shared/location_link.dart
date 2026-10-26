import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../core/geo.dart';
import '../../device/maps.dart';
import '../../domain/models.dart';
import '../../ui/icons.dart';
import '../../ui/motion.dart';
import 'widgets.dart';

/// Tappable coordinates: opens the exact spot in Google Maps. If no map app
/// can open it, the coordinates are copied so they can be pasted anywhere.
class LocationLink extends StatelessWidget {
  const LocationLink(this.fix, {super.key, this.label = 'SOS location', this.title, this.from});

  final LocationFix fix;
  final String label;
  final String? title;

  /// When known, shows the distance from here.
  final GeoPoint? from;

  Future<void> _open(BuildContext context) async {
    Sfx.tap();
    final ok = await MapLauncher.open(fix.point, label: label);
    if (ok || !context.mounted) return;
    await Clipboard.setData(ClipboardData(text: fix.point.toString()));
    if (context.mounted) notify(context, 'No map app found. Coordinates copied.');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final distance = from == null ? null : formatDistance(from!.distanceTo(fix.point));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Pressable(
        child: Material(
          color: cs.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _open(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(children: [
                AppIcon(ResqIcons.location, size: 20, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (title != null) Text(title!, style: t.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
                    Text(fix.point.toString(),
                        style: t.bodyMedium?.copyWith(fontFamily: ResqTheme.monoFamily, color: cs.primary, fontWeight: FontWeight.w600)),
                    Text(
                      '±${fix.accuracyM.round()} m${distance == null ? '' : ' · $distance away'} · Open in Google Maps',
                      style: t.bodySmall,
                    ),
                  ]),
                ),
                AppIcon(ResqIcons.external, size: 18, color: cs.primary, semanticLabel: 'Open in Google Maps'),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
