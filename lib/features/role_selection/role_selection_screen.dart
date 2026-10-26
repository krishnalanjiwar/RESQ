import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../domain/models.dart';
import '../../ui/brand.dart';
import '../../ui/icons.dart';
import '../../ui/motion.dart';
import '../medical/medical_card_screen.dart';
import '../shared/widgets.dart';

/// Main dashboard: logo hero, anything that needs attention right now, then
/// one big obvious action per need. Every other page has a Home button back
/// here. The chosen role is saved; Android back on this screen exits.
class RoleSelectionScreen extends ConsumerWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(nodeVersionProvider);
    final node = ref.watch(nodeProvider);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final activeSos = node.mySos.where((m) => m.state.isOpen || m.state.isActive).toList();
    final helping = node.myEngagements.where((e) => e.state.isActive && !e.standDown).toList();
    final card = node.medicalCard;

    void go(NodeRole role) {
      Sfx.tap();
      unawaited(node.setRole(role));
    }

    final items = <Widget>[
      const _Hero(),
      if (activeSos.isNotEmpty)
        _AttentionBanner(
          color: Brand.gRed,
          icon: ResqIcons.send,
          title: activeSos.length == 1 ? 'Your SOS is active' : '${activeSos.length} SOS requests active',
          body: activeSos.first.state.phase.label,
          onTap: () => go(NodeRole.victim),
        ),
      if (helping.isNotEmpty)
        _AttentionBanner(
          color: Brand.gBlue,
          icon: ResqIcons.lifebuoy,
          title: 'You are helping ${helping.length == 1 ? 'someone' : '${helping.length} people'}',
          body: 'Open to update your progress',
          onTap: () => go(NodeRole.responder),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
        child: Text('How will you use RES-Q?', style: t.titleLarge),
      ),
      _SosTile(onTap: () => go(NodeRole.victim)),
      _ActionTile(
        color: Brand.gBlue,
        icon: ResqIcons.lifebuoy,
        title: 'I can help',
        body: 'Get matched to people you are best placed to reach, and choose whether to go.',
        onTap: () => go(NodeRole.responder),
      ),
      _ActionTile(
        color: Brand.gGreen,
        icon: ResqIcons.medical,
        title: 'Medical card',
        body: card == null
            ? 'Add blood group, allergies and medicines. Shared only with the volunteer who comes.'
            : 'Ready${card.bloodGroup.isEmpty ? '' : ' · Blood ${card.bloodGroup}'} — shared only with who accepts your SOS.',
        trailing: card == null ? null : const StatusChip('Saved', tone: Tone.good, icon: ResqIcons.check),
        onTap: () => openMedicalCard(context),
      ),
      _ActionTile(
        color: Brand.gYellow,
        icon: ResqIcons.flask,
        title: 'Test and train',
        body: 'Run a simulated city and Red Team drills. This phone still relays messages.',
        onTap: () => go(NodeRole.diagnostics),
      ),
      const Callout(
        'RES-Q supports emergency services but does not replace them, and cannot guarantee that a message '
        'arrives or that help comes. Contact official services whenever you can.',
        tone: Tone.neutral,
      ),
      Text('Nearby-device permissions are only requested when you turn the mesh on.',
          style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant), textAlign: TextAlign.center),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          const RainbowBar(height: 4),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: ResqTheme.maxContentWidth),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => FadeSlideIn(index: i, child: items[i]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Logo hero: the mark with soft four-colour signal rings, the wordmark and
/// the promise in one line.
class _Hero extends StatefulWidget {
  const _Hero();

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> with SingleTickerProviderStateMixin {
  late final AnimationController _rings = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!MediaQuery.of(context).disableAnimations && !_rings.isAnimating) unawaited(_rings.repeat());
  }

  @override
  void dispose() {
    _rings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Column(children: [
        SizedBox(
          width: 150,
          height: 150,
          child: AnimatedBuilder(
            animation: _rings,
            builder: (_, child) => Stack(alignment: Alignment.center, children: [
              for (var i = 0; i < Brand.rainbow.length; i++)
                Builder(builder: (_) {
                  final v = (_rings.value + i / Brand.rainbow.length) % 1.0;
                  return Container(
                    width: 84 + 66 * v,
                    height: 84 + 66 * v,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Brand.rainbow[i].withValues(alpha: 0.45 * (1 - v)), width: 2),
                    ),
                  );
                }),
              child!,
            ]),
            child: const BrandMark(size: 84),
          ),
        ),
        const SizedBox(height: 6),
        const FittedBox(fit: BoxFit.scaleDown, child: Wordmark(fontSize: 40, rainbow: true)),
        const SizedBox(height: 8),
        Text('Emergency help, even when the network is down.',
            textAlign: TextAlign.center, style: t.titleMedium?.copyWith(color: cs.onSurface)),
        const SizedBox(height: 4),
        Text(Brand.tagline, textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: 14),
        const Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
          _HeroPill(icon: ResqIcons.mesh, label: 'Works offline', color: Brand.gBlue),
          _HeroPill(icon: ResqIcons.shieldCheck, label: 'Verified responders', color: Brand.gGreen),
          _HeroPill(icon: ResqIcons.lock, label: 'Private by design', color: Brand.gRed),
        ]),
      ]),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.label, required this.color});

  final String icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          AppIcon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w600)),
          ),
        ]),
      );
}

/// The one action that matters most in a crisis: big, red, unmistakable.
class _SosTile extends StatelessWidget {
  const _SosTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Pressable(
      child: Material(
        color: Brand.gRed,
        borderRadius: BorderRadius.circular(22),
        elevation: 2,
        shadowColor: Brand.gRed.withValues(alpha: 0.5),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                child: const Center(child: AppIcon(ResqIcons.warning, size: 28, color: Colors.white)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('I need help', style: t.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('Send an SOS. It hops phone to phone until it reaches someone who can help.',
                      style: t.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.92))),
                ]),
              ),
              const AppIcon(ResqIcons.chevronRight, size: 22, color: Colors.white),
            ]),
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.color,
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
    this.trailing,
  });

  final Color color;
  final String icon;
  final String title;
  final String body;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Pressable(
      child: Card(
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(width: 5, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 16, 12, 16),
                  child: Row(children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                      child: Center(child: AppIcon(icon, size: 24, color: color)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(title, style: t.titleMedium),
                        const SizedBox(height: 3),
                        Text(body, style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                        if (trailing != null) ...[const SizedBox(height: 8), trailing!],
                      ]),
                    ),
                    const SizedBox(width: 6),
                    AppIcon(ResqIcons.chevronRight, size: 20, color: cs.outline),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Something that needs the user now (an active SOS, a person they are helping).
class _AttentionBanner extends StatelessWidget {
  const _AttentionBanner({required this.color, required this.icon, required this.title, required this.body, required this.onTap});

  final Color color;
  final String icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Pressable(
      child: PulseGlow(
        color: color,
        radius: 16,
        child: Material(
          color: color.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: color.withValues(alpha: 0.5), width: 1.5),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                AppIcon(icon, size: 22, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: t.titleSmall?.copyWith(color: color, fontWeight: FontWeight.w700)),
                    Text(body, style: t.bodySmall),
                  ]),
                ),
                Text('Open', style: t.labelLarge?.copyWith(color: color)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
