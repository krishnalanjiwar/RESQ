import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../ui/icons.dart';
import 'widgets.dart';

/// Returns to the welcome screen. A responder holding an active assignment is
/// asked first, because leaving the role stops their availability broadcast.
Future<void> backToStart(BuildContext context, WidgetRef ref) async {
  final node = ref.read(nodeProvider);
  final holding = node.myEngagements.any((e) => e.isPrimary && e.state.isActive && !e.standDown);
  if (holding) {
    final ok = await confirm(
      context,
      'Leave the responder screen?',
      'You have an active assignment. The requester still counts on you. Your progress is kept, '
          'but nearby phones will stop seeing you as available.',
      yes: 'Leave',
    );
    if (!ok) return;
  }
  await node.clearRole();
}

/// App-bar back arrow (custom SVG) that returns to the welcome screen.
class BackToStartButton extends ConsumerWidget {
  const BackToStartButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
        tooltip: 'Back',
        icon: const AppIcon(ResqIcons.arrowBack, semanticLabel: 'Back'),
        onPressed: () => backToStart(context, ref),
      );
}

/// Makes the Android back gesture/button return to the welcome screen instead
/// of closing the app. If the status drawer is open, back only closes it.
///
/// [builder] receives the key to put on the page's Scaffold, so the scope can
/// see and close its drawer (a blocking PopScope stops the drawer from
/// handling back by itself).
class BackToStartScope extends ConsumerStatefulWidget {
  const BackToStartScope({super.key, required this.builder});

  final Widget Function(BuildContext context, GlobalKey<ScaffoldState> scaffoldKey) builder;

  @override
  ConsumerState<BackToStartScope> createState() => _BackToStartScopeState();
}

class _BackToStartScopeState extends ConsumerState<BackToStartScope> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          final scaffold = _scaffoldKey.currentState;
          if (scaffold != null && (scaffold.isEndDrawerOpen || scaffold.isDrawerOpen)) {
            scaffold.closeEndDrawer();
            scaffold.closeDrawer();
            return;
          }
          backToStart(context, ref);
        },
        child: widget.builder(context, _scaffoldKey),
      );
}
