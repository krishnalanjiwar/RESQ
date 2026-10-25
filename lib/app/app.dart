import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';
import '../features/diagnostics/diagnostics_screen.dart';
import '../features/responder/responder_screen.dart';
import '../features/role_selection/role_selection_screen.dart';
import '../features/victim/victim_screen.dart';
import 'providers.dart';
import 'theme.dart';

class ResqApp extends StatelessWidget {
  const ResqApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'RESQ',
        debugShowCheckedModeBanner: false,
        theme: ResqTheme.monochrome,
        home: const _RoleRouter(),
      );
}

/// Routes to the saved role's home screen (FR-001).
class _RoleRouter extends ConsumerWidget {
  const _RoleRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(nodeVersionProvider);
    ref.watch(deviceControllerProvider); // starts device timers
    final role = ref.watch(nodeProvider).role;
    return switch (role) {
      null => const RoleSelectionScreen(),
      NodeRole.victim => const VictimScreen(),
      NodeRole.responder => const ResponderScreen(),
      NodeRole.diagnostics => const DiagnosticsScreen(),
    };
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
        theme: ResqTheme.monochrome,
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('RESQ COULD NOT START', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
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
