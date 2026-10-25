import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models.dart';
import '../shared/widgets.dart';

/// First launch: choose a role (FR-001). The choice is persisted and can be
/// changed from the status drawer.
class RoleSelectionScreen extends ConsumerWidget {
  const RoleSelectionScreen({super.key});

  static const Map<NodeRole, String> _explain = {
    NodeRole.victim: 'I need help. Send an SOS to nearby phones.',
    NodeRole.responder: 'I can help. Receive matched requests and decide whether to go.',
    NodeRole.diagnostics: 'Testing, training and Red Team simulations. Also relays like any node.',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final node = ref.watch(nodeProvider);
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(24), children: [
          const Text('RESQ', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w700)),
          const Text('OFFLINE PEER-TO-PEER EMERGENCY MESH', style: TextStyle(fontSize: 12, letterSpacing: 1.2)),
          const SizedBox(height: 24),
          const Boxed(
            child: Text(
              'RESQ is an auxiliary coordination tool. It does not replace emergency services, '
              'cannot guarantee delivery, and cannot guarantee that help will arrive. '
              'Contact official emergency services whenever you can.',
              style: TextStyle(fontSize: 13),
            ),
          ),
          const SectionTitle('CHOOSE YOUR ROLE'),
          for (final role in NodeRole.values) ...[
            ActionButton(role.label, primary: role == NodeRole.victim, onPressed: () => node.setRole(role)),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 16),
              child: Text(_explain[role]!, style: const TextStyle(fontSize: 12)),
            ),
          ],
          const Text(
            'Nearby-device permissions are requested only when you turn the mesh on.',
            style: TextStyle(fontSize: 11),
          ),
        ]),
      ),
    );
  }
}
