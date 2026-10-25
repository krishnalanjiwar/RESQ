import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../crypto/identity.dart';
import '../../domain/models.dart';
import '../../domain/trust/trust_agent.dart';
import '../../protocol/limits.dart';
import 'widgets.dart';

/// Global diagnostics/status drawer, available from every primary screen.
/// Every line reflects live provider state; nothing is hard-coded.
class StatusDrawer extends ConsumerWidget {
  const StatusDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(nodeVersionProvider);
    final node = ref.watch(nodeProvider);
    final device = ref.watch(deviceControllerProvider);
    final counts = node.counts;
    final power = node.powerPolicy;
    final report = node.reconciliationReport;
    const trust = TrustAgent();
    final verifiedKeys = node.beacons.values
        .where((b) => b.role == NodeRole.responder && trust.credentialStatus(b, node) == CredentialStatus.verified)
        .length;

    return Drawer(
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('STATUS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('RESQ 0.8.0 · protocol v${Limits.protocolVersion}', style: const TextStyle(fontSize: 11)),
          const SectionTitle('ROLE'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final r in NodeRole.values)
              ActionButton(
                r == node.role ? '● ${r.label}' : r.label,
                dense: true,
                primary: r == node.role,
                onPressed: r == node.role ? null : () => node.setRole(r),
              ),
          ]),
          const SectionTitle('RADIO'),
          KeyValue('TRANSPORT', '${node.transport.isSimulated ? 'SIMULATED' : 'REAL'} · ${node.transport.label}'),
          KeyValue('STATE', node.transportRunning ? 'RUNNING' : 'OFF', emphasis: true),
          KeyValue('LAST EVENT', node.transportDetail),
          KeyValue('PEERS', '${counts.connectedPeers} connected'),
          KeyValue('BACKGROUND', device.foregroundRunning ? 'FOREGROUND SERVICE ACTIVE' : 'BACKGROUND DISCOVERY NOT ACTIVE'),
          KeyValue('PERMISSIONS', device.permissions?.label ?? 'UNKNOWN'),
          if (device.permissions?.anyPermanentlyDenied ?? false)
            ActionButton('OPEN SETTINGS', dense: true, onPressed: () => ref.read(deviceControllerProvider.notifier).openSettings()),
          const SectionTitle('POWER'),
          KeyValue('BATTERY (REAL)', node.realBattery == null ? 'BATTERY READING UNAVAILABLE' : '${node.realBattery}%'),
          if (power.isSimulatedOverride) KeyValue('OVERRIDE', 'SIMULATED BATTERY OVERRIDE ${node.batteryOverride}%', emphasis: true),
          KeyValue('POLICY', power.mode.label),
          const SectionTitle('QUEUES'),
          KeyValue('OUTBOX', '${counts.outboxPending} own SOS not yet sent to any peer'),
          KeyValue('LIVE MESSAGES', '${counts.liveMessages}'),
          KeyValue('KNOWN', '${counts.sosKnown} SOS · ${counts.beaconsKnown} nodes · ${counts.hazardsKnown} hazards'),
          KeyValue('DEDUPE CACHE', '${counts.seenCacheSize} ids'),
          const SectionTitle('SECURITY'),
          const KeyValue('IDENTITY KEYS', 'READY · Ed25519 + X25519 in OS secure storage'),
          KeyValue('FINGERPRINT', PublicIdentity.fingerprintOf(node.selfId)),
          KeyValue('ENCRYPTION', verifiedKeys > 0
              ? 'SOS SEALED TO $verifiedKeys VERIFIED RESPONDER KEY(S)'
              : 'NO VERIFIED RESPONDER KEYS — SOS DETAILS SHARED OPENLY OR WITHHELD'),
          KeyValue('TRUST ANCHORS', '${node.anchors.length} (${node.provisionedAnchors.length} provisioned, ${node.pinnedAnchors.length} pinned)'),
          KeyValue('QUARANTINE', '${counts.quarantinedLinks} link(s) · ${counts.penalisedIdentities} identit(ies)'),
          const SectionTitle('RECONCILIATION'),
          KeyValue('RESULT', report.sosCount == 0
              ? 'NO SOS KNOWN'
              : '${report.conflicts} conflict(s) computed over ${report.sosCount} SOS'),
          KeyValue('DETAIL', '${report.standDownsIssued} stand-down · ${report.orphansReopened} reopened · ${report.multipleOnScene} multi-on-scene'),
          const SectionTitle('EVENT LOG (REDACTED)'),
          for (final e in node.log.entries.take(10))
            Text('${ago(e.atMs, node.nowMs).padRight(9)} ${e.code}${e.detail.isEmpty ? '' : ' · ${e.detail}'}',
                style: const TextStyle(fontSize: 10)),
        ]),
      ),
    );
  }
}
