import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../ui/brand.dart';
import 'back_to_start.dart';
import 'status_drawer.dart';
import 'widgets.dart';

/// Standard RES-Q page: large collapsing header (title + supporting line),
/// brand mark, status action, and content capped to a comfortable reading
/// width on tablets — the layout grammar of a professional product site.
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
          actions: const [
            Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: BrandMark(size: 28)),
            StatusButton(),
            SizedBox(width: 4),
          ],
        ),
        SliverToBoxAdapter(
          child: _Constrained(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(subtitle, style: t.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          sliver: SliverList.list(children: [for (final c in children) _Constrained(child: c)]),
        ),
      ]),
      ),
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
