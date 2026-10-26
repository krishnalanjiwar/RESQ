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

/// Main dashboard in a brutalist style: black, white and orange only, thick
/// borders, hard shadows, heavy type. One big obvious action per need, and
/// anything needing attention right now at the top. Every other page has a
/// Home button back here; Android back on this screen exits the app.
class RoleSelectionScreen extends ConsumerWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(nodeVersionProvider);
    final node = ref.watch(nodeProvider);
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
        _BrutalTile(
          fill: Brand.bOrange,
          icon: ResqIcons.send,
          title: activeSos.length == 1 ? 'Your SOS is active' : '${activeSos.length} SOS requests active',
          body: activeSos.first.state.phase.label,
          tag: 'OPEN',
          onTap: () => go(NodeRole.victim),
        ),
      if (helping.isNotEmpty)
        _BrutalTile(
          fill: Brand.bOrangeSoft,
          icon: ResqIcons.lifebuoy,
          title: 'You are helping ${helping.length == 1 ? 'someone' : '${helping.length} people'}',
          body: 'Open to update your progress.',
          tag: 'OPEN',
          onTap: () => go(NodeRole.responder),
        ),
      const _SectionTitle('How will you use RES-Q?'),
      _BrutalTile(
        fill: Brand.bOrange,
        big: true,
        icon: ResqIcons.warning,
        title: 'I need help',
        body: 'Send an SOS. It hops phone to phone until it reaches someone who can help.',
        onTap: () => go(NodeRole.victim),
      ),
      _BrutalTile(
        fill: Brand.bWhite,
        icon: ResqIcons.lifebuoy,
        title: 'I can help',
        body: 'Get matched to people you are best placed to reach, and choose whether to go.',
        onTap: () => go(NodeRole.responder),
      ),
      _BrutalTile(
        fill: Brand.bWhite,
        icon: ResqIcons.medical,
        title: 'Medical card',
        body: card == null
            ? 'Add blood group, allergies and medicines. Shared only with the volunteer who comes.'
            : 'Ready${card.bloodGroup.isEmpty ? '' : ' · Blood ${card.bloodGroup}'}. Shared only with who accepts your SOS.',
        tag: card == null ? null : 'SAVED',
        onTap: () => openMedicalCard(context),
      ),
      _BrutalTile(
        fill: Brand.bPaper,
        icon: ResqIcons.flask,
        title: 'Test and train',
        body: 'Run a simulated city and Red Team drills. This phone still relays messages.',
        onTap: () => go(NodeRole.diagnostics),
      ),
      const _Notice(),
    ];

    return Scaffold(
      backgroundColor: Brand.bWhite,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: ResqTheme.maxContentWidth),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 22, 32),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (_, i) => FadeSlideIn(index: i, child: items[i]),
            ),
          ),
        ),
      ),
    );
  }
}

const TextStyle _mono = TextStyle(fontFamily: ResqTheme.monoFamily, fontWeight: FontWeight.w700, letterSpacing: 1.2);

/// Black block with the logo, the wordmark and the promise.
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: const BoxDecoration(
        color: Brand.bBlack,
        border: Border.fromBorderSide(BorderSide(color: Brand.bBlack, width: 3)),
        boxShadow: [BoxShadow(color: Brand.bOrange, offset: Offset(6, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            decoration: const BoxDecoration(border: Border.fromBorderSide(BorderSide(color: Brand.bOrange, width: 3))),
            child: const BrandMark(size: 72, brutal: true),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Wordmark(fontSize: 44, onDark: true, accent: Brand.bOrange),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        Text('OFFLINE EMERGENCY MESH', style: _mono.copyWith(color: Brand.bOrange, fontSize: 12)),
        const SizedBox(height: 6),
        Text(
          'EMERGENCY HELP.\nNO NETWORK NEEDED.',
          style: t.headlineSmall?.copyWith(color: Brand.bWhite, fontWeight: FontWeight.w900, height: 1.1, letterSpacing: -0.5),
        ),
        const SizedBox(height: 8),
        Text(Brand.tagline, style: t.bodyMedium?.copyWith(color: Brand.bOrangeSoft)),
        const SizedBox(height: 14),
        const Wrap(spacing: 8, runSpacing: 8, children: [
          _Pill(icon: ResqIcons.mesh, label: 'Works offline'),
          _Pill(icon: ResqIcons.shieldCheck, label: 'Verified responders'),
          _Pill(icon: ResqIcons.lock, label: 'Private by design'),
        ]),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: const BoxDecoration(border: Border.fromBorderSide(BorderSide(color: Brand.bOrange, width: 2))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          AppIcon(icon, size: 14, color: Brand.bOrange),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label, overflow: TextOverflow.ellipsis, style: _mono.copyWith(color: Brand.bWhite, fontSize: 11)),
          ),
        ]),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(text,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: Brand.bBlack, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          const SizedBox(height: 6),
          Container(width: 64, height: 6, color: Brand.bOrange),
        ]),
      );
}

/// Brutalist action tile: flat fill, thick black border, hard black shadow
/// that collapses as the tile is pressed in.
class _BrutalTile extends StatefulWidget {
  const _BrutalTile({
    required this.fill,
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
    this.big = false,
    this.tag,
  });

  final Color fill;
  final String icon;
  final String title;
  final String body;
  final VoidCallback onTap;
  final bool big;
  final String? tag;

  @override
  State<_BrutalTile> createState() => _BrutalTileState();
}

class _BrutalTileState extends State<_BrutalTile> {
  static const double _shadow = 6;
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final onFill = widget.fill == Brand.bBlack ? Brand.bWhite : Brand.bBlack;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(_down ? _shadow : 0, _down ? _shadow : 0, 0),
          decoration: BoxDecoration(
            color: widget.fill,
            border: Border.all(color: Brand.bBlack, width: 3),
            boxShadow: [BoxShadow(color: Brand.bBlack, offset: _down ? Offset.zero : const Offset(_shadow, _shadow))],
          ),
          padding: EdgeInsets.all(widget.big ? 20 : 16),
          child: Row(children: [
            Container(
              width: widget.big ? 60 : 48,
              height: widget.big ? 60 : 48,
              decoration: BoxDecoration(
                color: widget.fill == Brand.bOrange ? Brand.bWhite : Brand.bOrange,
                border: Border.all(color: Brand.bBlack, width: 3),
              ),
              child: Center(child: AppIcon(widget.icon, size: widget.big ? 30 : 24, color: Brand.bBlack)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  widget.title,
                  style: (widget.big ? t.headlineSmall : t.titleLarge)
                      ?.copyWith(color: onFill, fontWeight: FontWeight.w900, letterSpacing: -0.4),
                ),
                const SizedBox(height: 4),
                Text(widget.body, style: t.bodyMedium?.copyWith(color: onFill)),
                if (widget.tag != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    color: Brand.bBlack,
                    child: Text(widget.tag!, style: _mono.copyWith(color: Brand.bOrange, fontSize: 11)),
                  ),
                ],
              ]),
            ),
            const SizedBox(width: 8),
            AppIcon(ResqIcons.chevronRight, size: 24, color: onFill),
          ]),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: Brand.bPaper,
        border: Border.fromBorderSide(BorderSide(color: Brand.bBlack, width: 2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('IMPORTANT', style: _mono.copyWith(color: Brand.bOrangeDeep, fontSize: 12)),
        const SizedBox(height: 6),
        Text(
          'RES-Q supports emergency services but does not replace them, and cannot guarantee that a message '
          'arrives or that help comes. Contact official services whenever you can.',
          style: t.bodySmall?.copyWith(color: Brand.bInk),
        ),
        const SizedBox(height: 6),
        Text('Nearby-device permissions are only requested when you turn the mesh on.',
            style: t.bodySmall?.copyWith(color: Brand.bInk)),
      ]),
    );
  }
}
