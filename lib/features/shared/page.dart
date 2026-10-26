import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../ui/brand.dart';
import '../../ui/icons.dart';
import '../../ui/motion.dart';
import 'back_to_start.dart';
import 'status_drawer.dart';
import 'widgets.dart';

/// Standard RES-Q role page: large collapsing header with Back and Home,
/// the four-colour accent line, and content that settles in with a short
/// staggered animation. Width is capped for tablets.
class ResqPage extends StatelessWidget {
  const ResqPage({super.key, required this.title, required this.subtitle, required this.children});

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return BackToStartScope(
      builder: (context, scaffoldKey) => Scaffold(
        key: scaffoldKey,
        endDrawer: const StatusDrawer(),
        body: CustomScrollView(slivers: [
          SliverAppBar.large(
            leading: const BackToStartButton(),
            title: Text(title),
            actions: const [HomeButton(), StatusButton(), SizedBox(width: 4)],
            bottom: const PreferredSize(preferredSize: Size.fromHeight(3), child: RainbowBar(height: 3)),
          ),
          SliverToBoxAdapter(
            child: _Constrained(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                child: Text(subtitle, style: t.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            sliver: SliverList.list(children: [
              for (var i = 0; i < children.length; i++) _Constrained(child: FadeSlideIn(index: i, child: children[i])),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// A page opened on top of a role page or the dashboard (e.g. the medical
/// card). Back closes just this page; Home goes all the way to the dashboard.
class SubPage extends StatelessWidget {
  const SubPage({super.key, required this.title, required this.children, this.subtitle});

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const AppIcon(ResqIcons.arrowBack, semanticLabel: 'Back'),
          onPressed: () {
            Sfx.tap();
            Navigator.of(context).maybePop();
          },
        ),
        title: Text(title),
        actions: const [HomeButton(), SizedBox(width: 4)],
        bottom: const PreferredSize(preferredSize: Size.fromHeight(3), child: RainbowBar(height: 3)),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), children: [
        if (subtitle != null)
          _Constrained(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
              child: Text(subtitle!, style: t.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
            ),
          ),
        for (var i = 0; i < children.length; i++) _Constrained(child: FadeSlideIn(index: i, child: children[i])),
      ]),
    );
  }
}

class _Constrained extends StatelessWidget {
  const _Constrained({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: ResqTheme.maxContentWidth), child: child),
      );
}
