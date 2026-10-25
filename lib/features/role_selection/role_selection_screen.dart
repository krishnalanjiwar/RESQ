import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../domain/models.dart';
import '../../ui/brand.dart';
import '../../ui/icons.dart';
import '../shared/widgets.dart';

/// Welcome screen, laid out like a product landing page: brand hero, value
/// points, then the role choice (FR-001). The role is saved and can be changed
/// later from the status drawer.
class RoleSelectionScreen extends ConsumerWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final node = ref.watch(nodeProvider);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: ResqTheme.maxContentWidth),
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
              const _Hero(),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Get started', style: t.labelLarge?.copyWith(color: cs.primary)),
                  const SizedBox(height: 4),
                  Text('How will you use RES-Q?', style: t.headlineSmall),
                  const SizedBox(height: 4),
                  Text('Choose a role. You can switch any time.', style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                ]),
              ),
              const SizedBox(height: 16),
              _RoleCard(
                icon: ResqIcons.warning,
                tone: Tone.danger,
                title: 'I need help',
                body: 'Send an SOS. It hops from phone to phone until it reaches someone who can help.',
                onTap: () => node.setRole(NodeRole.victim),
              ),
              const SizedBox(height: 12),
              _RoleCard(
                icon: ResqIcons.lifebuoy,
                tone: Tone.info,
                title: 'I can help',
                body: 'Get matched to people you are best placed to reach, and choose whether to go.',
                onTap: () => node.setRole(NodeRole.responder),
              ),
              const SizedBox(height: 12),
              _RoleCard(
                icon: ResqIcons.flask,
                tone: Tone.good,
                title: 'Test and train',
                body: 'Run a simulated city, try Red Team attacks and manage trust. This phone still relays messages.',
                onTap: () => node.setRole(NodeRole.diagnostics),
              ),
              const SizedBox(height: 28),
              const Callout(
                'RES-Q supports emergency services but does not replace them, and cannot guarantee that a message '
                'arrives or that help comes. Contact official services whenever you can.',
                tone: Tone.neutral,
              ),
              const SizedBox(height: 16),
              Text('Nearby-device permissions are only requested when you turn the mesh on.',
                  style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant), textAlign: TextAlign.center),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Brand.blue, Brand.blueDeep],
        ),
        boxShadow: [BoxShadow(color: Brand.blue.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(16)),
            child: const BrandMark(size: 46),
          ),
          const SizedBox(width: 14),
          // Scales down on narrow phones / large text instead of overflowing.
          const Flexible(
            child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Wordmark(fontSize: 30, onDark: true)),
          ),
        ]),
        const SizedBox(height: 22),
        Text('Emergency help,\neven when the network is down.',
            style: t.headlineSmall?.copyWith(color: Colors.white, height: 1.2)),
        const SizedBox(height: 8),
        Text('${Brand.tagline} No towers, no internet, no central server.',
            style: t.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.85))),
        const SizedBox(height: 18),
        const Wrap(spacing: 8, runSpacing: 8, children: [
          _HeroPill(icon: ResqIcons.mesh, label: 'Works offline'),
          _HeroPill(icon: ResqIcons.shieldCheck, label: 'Verified responders'),
          _HeroPill(icon: ResqIcons.lock, label: 'Private by design'),
        ]),
      ]),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.label});

  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          AppIcon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white)),
          ),
        ]),
      );
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.icon, required this.tone, required this.title, required this.body, required this.onTap});

  final String icon;
  final Tone tone;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            IconCircle(icon, tone: tone, size: 52),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: t.titleMedium),
                const SizedBox(height: 4),
                Text(body, style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              ]),
            ),
            const SizedBox(width: 8),
            AppIcon(ResqIcons.chevronRight, size: 20, color: cs.outline),
          ]),
        ),
      ),
    );
  }
}
