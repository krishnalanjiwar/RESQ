import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../ui/icons.dart';

/// Semantic tones used across chips, banners and status icons. Meaning is
/// always carried by text and icon too, never by colour alone.
enum Tone { neutral, info, good, warn, danger }

extension ToneColors on Tone {
  (Color background, Color foreground) colors(ColorScheme cs) => switch (this) {
        Tone.neutral => (cs.surfaceContainerHighest, cs.onSurfaceVariant),
        Tone.info => (cs.primaryContainer, cs.onPrimaryContainer),
        Tone.good => (cs.tertiaryContainer, cs.onTertiaryContainer),
        Tone.warn => (cs.secondaryContainer, cs.onSecondaryContainer),
        Tone.danger => (cs.errorContainer, cs.onErrorContainer),
      };
}

Tone urgencyTone(Urgency u) => switch (u) {
      Urgency.critical => Tone.danger,
      Urgency.high => Tone.warn,
      Urgency.unknown => Tone.info,
      Urgency.low => Tone.neutral,
    };

String urgencyLabel(Urgency u) => switch (u) {
      Urgency.critical => 'Critical',
      Urgency.high => 'High',
      Urgency.unknown => 'Needs review',
      Urgency.low => 'Low',
    };

String needIcon(Need n) => switch (n) {
      Need.medical => ResqIcons.medical,
      Need.waterRescue => ResqIcons.water,
      Need.fire => ResqIcons.flame,
      Need.trapped => ResqIcons.building,
      Need.evacuation => ResqIcons.route,
      Need.supplies => ResqIcons.box,
      Need.shelter => ResqIcons.home,
    };

String needLabel(Need n) => switch (n) {
      Need.medical => 'Medical',
      Need.waterRescue => 'Water rescue',
      Need.fire => 'Fire',
      Need.trapped => 'Trapped',
      Need.evacuation => 'Evacuation',
      Need.supplies => 'Supplies',
      Need.shelter => 'Shelter',
    };

String capabilityIcon(Capability c) => switch (c) {
      Capability.medicalAdvanced || Capability.medicalBasic => ResqIcons.medical,
      Capability.boat || Capability.waterRescue || Capability.swimmer => ResqIcons.water,
      Capability.fire => ResqIcons.flame,
      Capability.searchRescue => ResqIcons.building,
      Capability.vehicle => ResqIcons.route,
      Capability.carry => ResqIcons.group,
      Capability.supplies => ResqIcons.box,
      Capability.shelter => ResqIcons.home,
      Capability.general => ResqIcons.lifebuoy,
    };

String capabilityLabel(Capability c) => switch (c) {
      Capability.medicalAdvanced => 'Doctor / nurse',
      Capability.medicalBasic => 'First aid',
      Capability.boat => 'Boat',
      Capability.waterRescue => 'Water rescue',
      Capability.swimmer => 'Swimmer',
      Capability.fire => 'Firefighting',
      Capability.searchRescue => 'Search & rescue',
      Capability.vehicle => 'Vehicle',
      Capability.carry => 'Lifting / stretcher',
      Capability.supplies => 'Supplies',
      Capability.shelter => 'Shelter',
      Capability.general => 'General help',
    };

/// Small tonal pill with an optional icon.
class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.tone = Tone.neutral, this.icon});

  final String label;
  final Tone tone;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = tone.colors(Theme.of(context).colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[AppIcon(icon!, size: 14, color: fg), const SizedBox(width: 6)],
        Flexible(
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

class UrgencyChip extends StatelessWidget {
  const UrgencyChip(this.urgency, {super.key});

  final Urgency urgency;

  @override
  Widget build(BuildContext context) => StatusChip(
        urgencyLabel(urgency),
        tone: urgencyTone(urgency),
        icon: urgency == Urgency.critical ? ResqIcons.warning : null,
      );
}

/// Round tonal container holding an icon.
class IconCircle extends StatelessWidget {
  const IconCircle(this.icon, {super.key, this.tone = Tone.info, this.size = 40});

  final String icon;
  final Tone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = tone.colors(Theme.of(context).colorScheme);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: AppIcon(icon, size: size * 0.5, color: fg),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
        child: Row(children: [
          Expanded(
            child: Text(title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          ),
          ?trailing,
        ]),
      );
}

/// Icon + text line used for facts on cards.
class InfoRow extends StatelessWidget {
  const InfoRow(this.icon, this.text, {super.key, this.tone, this.mono = false});

  final String icon;
  final String text;
  final Tone? tone;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = tone == null ? cs.onSurfaceVariant : tone!.colors(cs).$2;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 1), child: AppIcon(icon, size: 18, color: color)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tone == null ? cs.onSurface : color,
                    fontFamily: mono ? 'RobotoMono' : null,
                  )),
        ),
      ]),
    );
  }
}

/// Tonal callout for warnings and notes.
class Callout extends StatelessWidget {
  const Callout(this.text, {super.key, this.tone = Tone.warn, this.icon, this.title});

  final String text;
  final String? title;
  final Tone tone;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = tone.colors(Theme.of(context).colorScheme);
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AppIcon(icon ?? (tone == Tone.danger || tone == Tone.warn ? ResqIcons.warning : ResqIcons.info), size: 20, color: fg),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (title != null) Text(title!, style: t.titleSmall?.copyWith(color: fg, fontWeight: FontWeight.w600)),
            Text(text, style: t.bodyMedium?.copyWith(color: fg)),
          ]),
        ),
      ]),
    );
  }
}

/// One stage of the evaluation chain: name, score bar and reasons.
class ScoreRow extends StatelessWidget {
  const ScoreRow({super.key, required this.index, required this.name, required this.value, required this.passed, required this.detail, this.showBar = true});

  final int index;
  final String name;
  final double value;
  final bool passed;
  final String detail;
  final bool showBar;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text('$index', style: t.labelMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.w700)),
          const SizedBox(width: 10),
          Expanded(child: Text(name, style: t.labelLarge)),
          if (!passed)
            StatusChip('Blocked', tone: Tone.danger, icon: ResqIcons.close)
          else if (showBar)
            Text('${(v * 100).round()}%', style: t.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
        ]),
        if (showBar && passed)
          Padding(
            padding: const EdgeInsets.only(left: 20, top: 6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: v, minHeight: 6, backgroundColor: cs.surfaceContainerHighest),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(left: 20, top: 4),
          child: Text(detail, style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ),
      ]),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.body});

  final String icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(children: [
          IconCircle(icon, tone: Tone.neutral, size: 48),
          const SizedBox(height: 12),
          Text(title, style: t.titleSmall, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(body, style: t.bodySmall, textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

/// Persistent label for simulated content; simulation is never shown as reality.
class SimulationBanner extends StatelessWidget {
  const SimulationBanner(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Callout(text, title: 'Simulation', tone: Tone.good, icon: ResqIcons.flask);
}

String ago(int ms, int nowMs) {
  final s = ((nowMs - ms) / 1000).round();
  if (s < 30) return 'just now';
  if (s < 90) return '1 min ago';
  if (s < 3600) return '${(s / 60).round()} min ago';
  final h = (s / 3600).floor();
  return h == 1 ? '1 hour ago' : '$h hours ago';
}

Future<bool> confirm(BuildContext context, String title, String body, {String yes = 'Confirm', bool destructive = false}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: destructive ? FilledButton.styleFrom(backgroundColor: cs.error, foregroundColor: cs.onError) : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(yes),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

void notify(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// App bar action that opens the status drawer.
class StatusButton extends StatelessWidget {
  const StatusButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Status',
        icon: AppIcon(ResqIcons.status, semanticLabel: 'Status'),
        onPressed: () => Scaffold.of(context).openEndDrawer(),
      );
}
