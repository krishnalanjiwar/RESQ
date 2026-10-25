import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../crypto/identity.dart';
import '../../domain/models.dart';
import '../../domain/trust/trust_agent.dart';
import '../../protocol/limits.dart';
import '../../ui/brand.dart';
import '../../ui/icons.dart';
import 'widgets.dart';

/// Global status drawer, available from every screen. Every line reflects
/// live state; nothing is hard-coded.
class StatusDrawer extends ConsumerWidget {
  const StatusDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(nodeVersionProvider);
    final node = ref.watch(nodeProvider);
    final device = ref.watch(deviceControllerProvider);
    final services = ref.read(appServicesProvider);
    final t = Theme.of(context).textTheme;
    final counts = node.counts;
    final power = node.powerPolicy;
    final report = node.reconciliationReport;
    const trust = TrustAgent();
    final verifiedKeys = node.beacons.values
        .where((b) => b.role == NodeRole.responder && trust.credentialStatus(b, node) == CredentialStatus.verified)
        .length;

    Widget group(String title, List<Widget> children) => Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(title, style: t.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary)),
            ),
            ...children,
          ]),
        );

    return Drawer(
      child: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
          const BrandLockup(markSize: 34),
          const SizedBox(height: 18),
          Text('Status', style: t.headlineSmall),
          Text('Live view of this phone · protocol v${Limits.protocolVersion}', style: t.bodySmall),
          if (services.keysRecovered) ...[
            const SizedBox(height: 12),
            const Callout('Keys were unreadable at startup. A new identity was created and local data was reset.',
                tone: Tone.danger),
          ],
          if (node.clockWarning) ...[
            const SizedBox(height: 12),
            Callout('Clock differs from nearby phones by ${node.clockOffset!.inMinutes.abs()} min.', tone: Tone.warn),
          ],
          group('Role', [
            SegmentedButton<NodeRole>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: NodeRole.victim, label: Text('Help')),
                ButtonSegment(value: NodeRole.responder, label: Text('Responder')),
                ButtonSegment(value: NodeRole.diagnostics, label: Text('Test')),
              ],
              selected: {?node.role},
              emptySelectionAllowed: true,
              onSelectionChanged: (s) {
                if (s.isNotEmpty) node.setRole(s.first);
              },
            ),
          ]),
          group('Radio', [
            InfoRow(ResqIcons.mesh,
                '${node.transport.isSimulated ? 'Simulated' : 'Real'} radio · ${node.transportRunning ? 'running' : (device.meshOn ? 'not running' : 'off')}'),
            InfoRow(ResqIcons.peers, '${counts.connectedPeers} phone(s) connected'),
            InfoRow(ResqIcons.info, 'Last event: ${node.transportDetail}'),
            InfoRow(ResqIcons.bolt, device.foregroundRunning ? 'Background relay active' : 'Background relay not active'),
            InfoRow(ResqIcons.bluetooth, device.bluetoothOff ? 'Bluetooth is off' : 'Bluetooth available',
                tone: device.bluetoothOff ? Tone.danger : null),
            InfoRow(ResqIcons.shield, device.permissions?.label.toLowerCase().replaceFirst('nearby', 'Nearby') ?? 'Permissions unknown'),
          ]),
          group('Power', [
            InfoRow(ResqIcons.battery, node.realBattery == null ? 'Battery reading unavailable' : 'Battery ${node.realBattery}%'),
            if (power.isSimulatedOverride)
              InfoRow(ResqIcons.flask, 'Simulated battery override: ${node.batteryOverride}%', tone: Tone.good),
            InfoRow(ResqIcons.bolt, power.mode.label.toLowerCase()),
          ]),
          group('Messages', [
            InfoRow(ResqIcons.send, counts.outboxPending == 0
                ? 'Nothing waiting to send'
                : '${counts.outboxPending} of your SOS not yet sent to any phone'),
            InfoRow(ResqIcons.status, '${counts.sosKnown} SOS · ${counts.beaconsKnown} phones · ${counts.hazardsKnown} hazards known'),
          ]),
          group('Security', [
            InfoRow(ResqIcons.fingerprint, PublicIdentity.fingerprintOf(node.selfId), mono: true),
            InfoRow(ResqIcons.key, 'Identity keys loaded from secure storage'),
            InfoRow(ResqIcons.lock, 'Local data encrypted (AES, key in secure storage)'),
            InfoRow(verifiedKeys > 0 ? ResqIcons.lock : ResqIcons.unlock, verifiedKeys > 0
                ? 'Your SOS details are encrypted to $verifiedKeys verified responder(s)'
                : 'No verified responders known. SOS details are shared openly or withheld.'),
            InfoRow(ResqIcons.shieldCheck,
                '${node.anchors.length} trusted authorities (${node.provisionedAnchors.length} built-in, ${node.pinnedAnchors.length} pinned)'),
            if (counts.quarantinedLinks + counts.penalisedIdentities > 0)
              InfoRow(ResqIcons.shieldAlert, '${counts.quarantinedLinks} link(s), ${counts.penalisedIdentities} identity(ies) blocked',
                  tone: Tone.danger),
          ]),
          group('Reconciliation', [
            InfoRow(ResqIcons.split, report.sosCount == 0
                ? 'No SOS known'
                : '${report.conflicts} conflict(s) across ${report.sosCount} SOS · ${report.standDownsIssued} stand-down · ${report.orphansReopened} reopened'),
          ]),
          group('Recent events', [
            for (final e in node.log.entries.take(8))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('${ago(e.atMs, node.nowMs)} · ${e.code.toLowerCase().replaceAll('_', ' ')}${e.detail.isEmpty ? '' : ' — ${e.detail}'}',
                    style: t.bodySmall),
              ),
          ]),
        ]),
      ),
    );
  }
}
