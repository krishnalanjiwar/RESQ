import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';
import '../features/diagnostics/diagnostics_screen.dart';
import '../features/responder/responder_screen.dart';
import '../features/role_selection/role_selection_screen.dart';
import '../features/victim/victim_screen.dart';
import 'providers.dart';
import '../ui/brand.dart';
import 'theme.dart';

class ResqApp extends StatelessWidget {
  const ResqApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'RES-Q',
        debugShowCheckedModeBanner: false,
        theme: ResqTheme.light,
        darkTheme: ResqTheme.dark,
        // Clean white Google-style look on every phone, by design.
        themeMode: ThemeMode.light,
        home: const _RoleRouter(),
      );
}

/// Routes to the saved role's home screen (FR-001).
class _RoleRouter extends ConsumerWidget {
  const _RoleRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(nodeVersionProvider);
    ref.watch(deviceControllerProvider);
    final role = ref.watch(nodeProvider).role;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: Tween(begin: 0.98, end: 1.0).animate(animation), child: child),
      ),
      child: KeyedSubtree(
        key: ValueKey(role),
        child: switch (role) {
          null => const RoleSelectionScreen(),
          NodeRole.victim => const VictimScreen(),
          NodeRole.responder => const ResponderScreen(),
          NodeRole.diagnostics => const DiagnosticsScreen(),
        },
      ),
    );
  }
}

/// Shown when startup fails: an actionable error instead of a silent claim
/// that the mesh is running.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ResqTheme.light,
        darkTheme: ResqTheme.dark,
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const BrandLockup(markSize: 40),
                const SizedBox(height: 24),
                const Text('RES-Q could not start', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Text(message),
                const SizedBox(height: 12),
                const Text(
                  'The mesh is NOT running. Restart the app. If this repeats, free storage space or reinstall. '
                  'Use official emergency channels if you need help now.',
                ),
              ]),
            ),
          ),
        ),
      );
}
