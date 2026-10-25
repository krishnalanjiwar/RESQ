import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../crypto/identity.dart';
import '../../domain/models.dart';
import '../../domain/world.dart';
import '../../sim/simulator.dart';
import '../shared/mesh_bar.dart';
import '../shared/status_drawer.dart';
import '../shared/widgets.dart';
import 'sim_map.dart';

class DiagnosticsScreen extends StatelessWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('DIAGNOSTICS'),
            bottom: const TabBar(
              indicatorColor: Colors.white,
              labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              tabs: [Tab(text: 'RED TEAM SIM'), Tab(text: 'DEVICE'), Tab(text: 'TRUST')],
            ),
          ),
          endDrawer: const StatusDrawer(),
          body: const TabBarView(children: [_SimulatorTab(), _DeviceTab(), _TrustTab()]),
        ),
      );
}

// ---------------------------------------------------------------------------
// RED TEAM SIMULATOR
// ---------------------------------------------------------------------------

class _SimulatorTab extends ConsumerWidget {
  const _SimulatorTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(simControllerProvider);
    final ctrl = ref.read(simControllerProvider.notifier);
    final sim = st.sim;
    final busy = st.busy;

    Widget btn(String label, VoidCallback? onTap, {bool primary = false}) =>
        ActionButton(label, dense: true, primary: primary, onPressed: busy ? null : onTap);

    return ListView(padding: const EdgeInsets.all(12), children: [
      const SimulationBanner('virtual city of real RESQ nodes on a simulated radio'),
      const SizedBox(height: 8),
      const Text(
        'Every node below runs the same protocol code as this phone, with separate in-memory storage. '
        'Attacks inject real frames; outcomes are measured from node state. Nothing here touches your real records.',
        style: TextStyle(fontSize: 11),
      ),
      if (st.error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('ERROR: ${st.error}')),
      const SizedBox(height: 8),
      if (sim == null)
        btn(busy ? 'BUILDING CITY…' : 'BUILD SIMULATED CITY', ctrl.buildCity, primary: true)
      else ...[
        SimMap(sim: sim, version: st.version),
        const SizedBox(height: 6),
        Text(
          'STEP ${sim.steps} · T+${sim.steps * Simulator.stepDuration.inSeconds}s · ${sim.nodes.length} nodes · '
          '${sim.radio.links.length} links · frames ${sim.radio.framesDelivered} delivered / ${sim.radio.framesDropped} dropped'
          '${sim.partitioned ? ' · OFFLINE: QUEUING LOCALLY (partition)' : ''}',
          style: const TextStyle(fontSize: 10),
        ),
        const SectionTitle('RUN'),
        Wrap(spacing: 6, runSpacing: 6, children: [
          btn('STEP', ctrl.step),
          ActionButton(st.running ? 'PAUSE' : 'RUN', dense: true, primary: st.running, onPressed: ctrl.toggleRun),
          btn('RESET SIMULATION', () async {
            if (await confirm(context, 'RESET SIMULATION?', 'Discards the simulated city and all test results.')) {
              await ctrl.reset();
            }
          }),
        ]),
        const SectionTitle('SCENARIO'),
        Wrap(spacing: 6, runSpacing: 6, children: [
          btn('REPORT FLOOD ZONE', ctrl.reportFlood),
          btn('SEED EMERGENCIES', ctrl.seedEmergencies),
          btn('PARTITION DOUBLE-DISPATCH', ctrl.partitionScenario),
          btn(sim.partitioned ? 'HEAL PARTITION' : 'TOGGLE NETWORK PARTITION', ctrl.togglePartition),
        ]),
        const SectionTitle('RED TEAM HOUR'),
        Wrap(spacing: 6, runSpacing: 6, children: [
          btn('INJECT SYBIL TEST (40 NURSES)', ctrl.sybil),
          btn('FORGED MEDICAL CREDENTIAL', ctrl.forgedCredential),
          btn('SPOOFED LOCATION', ctrl.spoofedLocation),
          btn('FLOODWATER LURE', ctrl.floodLure),
          btn('BATTERY-DRAIN FLOOD', ctrl.batteryDrainAttack),
          btn('DRAIN BATTERY (RELAYS → 10%)', () => ctrl.drainRelayBatteries(10)),
          btn('CLEAR BATTERY OVERRIDE', () => ctrl.drainRelayBatteries(null)),
        ]),
        SectionTitle('TEST OUTCOMES (${sim.results.length})'),
        if (sim.results.isEmpty) const Text('Run an attack or a partition to see measured outcomes.', style: TextStyle(fontSize: 11)),
        for (final r in sim.results.reversed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Boxed(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('SIMULATION: ${r.attack}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                Text('OUTCOME: ${r.outcome.name.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                for (final d in r.details) Text('· $d', style: const TextStyle(fontSize: 11)),
              ]),
            ),
          ),
        _ObserverPanel(sim: sim),
        const SectionTitle('SIM LOG'),
        for (final e in sim.log.entries.take(25))
          Text('${e.code}${e.detail.isEmpty ? '' : ' · ${e.detail}'}', style: const TextStyle(fontSize: 10)),
      ],
    ]);
  }
}

class _ObserverPanel extends StatelessWidget {
  const _ObserverPanel({required this.sim});

  final Simulator sim;

  @override
  Widget build(BuildContext context) {
    final node = sim.observer.node;
    final report = node.reconciliationReport;
    final states = node.states.values.toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle('OBSERVER VIEW (${sim.observer.label})'),
      KeyValue('RECONCILIATION', '${report.conflicts} conflict(s) over ${report.sosCount} SOS (computed)'),
      KeyValue('STAND-DOWNS', '${report.standDownsIssued}'),
      KeyValue('ORPHANS REOPENED', '${report.orphansReopened}'),
      for (final s in states.take(8))
        Text(
          '${s.sosId.substring(0, 6)} ${s.phase.label}${s.conflicts.isEmpty ? '' : ' · ${s.conflicts.join(', ')}'}',
          style: const TextStyle(fontSize: 10),
        ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// DEVICE (real radio)
// ---------------------------------------------------------------------------

class _DeviceTab extends ConsumerWidget {
  const _DeviceTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(nodeVersionProvider);
    final node = ref.watch(nodeProvider);
    final peers = node.peers;
    final power = node.powerPolicy;
    return ListView(padding: const EdgeInsets.all(12), children: [
      const MeshBar(),
      SectionTitle('DIRECT PEERS (${peers.length})'),
      if (peers.isEmpty) const Text('No phones connected. Real radio only — no simulated peers here.', style: TextStyle(fontSize: 11)),
      for (final p in peers)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Boxed(
            padding: const EdgeInsets.all(8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(p.identity == null ? 'UNIDENTIFIED LINK' : PublicIdentity.fingerprintOf(p.identity!),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              KeyValue('ROLE', p.beacon?.role.label ?? 'NO BEACON YET'),
              KeyValue('TRUST', p.trust == null ? 'UNKNOWN' : '${p.trust!.level.name.toUpperCase()} · ${p.trust!.credentialStatus.label}'),
              KeyValue('IDENTITIES ON LINK', '${p.directIdentities}${p.directIdentities >= 3 ? ' — SYBIL INDICATOR' : ''}'),
              if (p.beacon?.batteryPct != null) KeyValue('BATTERY (CLAIM)', '${p.beacon!.batteryPct}%'),
            ]),
          ),
        ),
      const SectionTitle('POWER'),
      KeyValue('REAL BATTERY', node.realBattery == null ? 'UNAVAILABLE' : '${node.realBattery}%'),
      KeyValue('OVERRIDE', power.isSimulatedOverride ? 'SIMULATED BATTERY OVERRIDE ${node.batteryOverride}%' : 'NONE'),
      KeyValue('POLICY', power.mode.label),
      Wrap(spacing: 6, runSpacing: 6, children: [
        ActionButton('DRAIN BATTERY (SIM 10%)', dense: true, onPressed: () => node.setBatteryOverride(10)),
        ActionButton('CLEAR OVERRIDE', dense: true, onPressed: () => node.setBatteryOverride(null)),
      ]),
      const SectionTitle('DATA'),
      KeyValue('LIVE MESSAGES', '${node.counts.liveMessages}'),
      KeyValue('PENALISED IDS', '${node.counts.penalisedIdentities}'),
      ActionButton('DELETE LOCAL REPORT DATA', dense: true, onPressed: () async {
        if (await confirm(context, 'DELETE LOCAL DATA?',
            'Deletes stored SOS, events, hazards and settings on this phone. Your identity keys are kept.', yes: 'DELETE')) {
          await node.wipeLocalData();
        }
      }),
      const SectionTitle('EVENT LOG (REDACTED)'),
      for (final e in node.log.entries.take(40))
        Text('${ago(e.atMs, node.nowMs).padRight(9)} ${e.category.name.toUpperCase()} ${e.code}${e.detail.isEmpty ? '' : ' · ${e.detail}'}',
            style: const TextStyle(fontSize: 10)),
    ]);
  }
}

// ---------------------------------------------------------------------------
// TRUST: anchors, credentials, vouching (all in-person confirmed)
// ---------------------------------------------------------------------------

class _TrustTab extends ConsumerWidget {
  const _TrustTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(nodeVersionProvider);
    final node = ref.watch(nodeProvider);
    final directIds = {for (final p in node.peers) ?p.identity};
    final nearbyResponders = [
      for (final id in directIds)
        if (node.beacons[id]?.role == NodeRole.responder) node.beacons[id]!,
    ];

    return ListView(padding: const EdgeInsets.all(12), children: [
      const Text(
        'Trust is established offline and in person: compare the 16-character fingerprint shown on both phones before pinning, '
        'issuing or vouching. A signature proves control of a key, not real-world identity.',
        style: TextStyle(fontSize: 11),
      ),
      const SectionTitle('THIS PHONE'),
      KeyValue('FINGERPRINT', PublicIdentity.fingerprintOf(node.selfId), emphasis: true),
      const SectionTitle('AUTHORITIES NEARBY (NOT PINNED)'),
      if (node.unpinnedAuthorities.isEmpty) const Text('None seen.', style: TextStyle(fontSize: 11)),
      for (final a in node.unpinnedAuthorities)
        Boxed(
          padding: const EdgeInsets.all(8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('${a.authorityName} (DEMO AUTHORITY)', style: const TextStyle(fontWeight: FontWeight.w700)),
            KeyValue('FINGERPRINT', PublicIdentity.fingerprintOf(a.origin), emphasis: true),
            ActionButton('PIN — FINGERPRINT CONFIRMED IN PERSON', dense: true, onPressed: () async {
              if (await confirm(context, 'PIN THIS AUTHORITY?',
                  'Only pin if the authority operator showed you fingerprint ${PublicIdentity.fingerprintOf(a.origin)} in person. '
                  'Credentials it signs will be treated as verified on this phone.', yes: 'PIN')) {
                await node.pinAnchor(a.origin);
              }
            }),
          ]),
        ),
      SectionTitle('PINNED ANCHORS (${node.pinnedAnchors.length})'),
      for (final k in node.pinnedAnchors)
        Row(children: [
          Expanded(child: Text(PublicIdentity.fingerprintOf(k), style: const TextStyle(fontSize: 12))),
          TextButton(onPressed: () => node.unpinAnchor(k), child: const Text('[ UNPIN ]')),
        ]),
      const SectionTitle('AUTHORITY MODE (DEMO)'),
      if (node.authorityName == null)
        ActionButton('ACT AS DEMO AUTHORITY', dense: true, onPressed: () async {
          if (await confirm(context, 'ACT AS DEMO AUTHORITY?',
              'This phone will be able to issue responder credentials. Clearly labelled DEMO: real deployments use '
              'keys held by hospitals, NDRF or NGOs.', yes: 'ENABLE')) {
            await node.enableAuthority('DEMO AUTHORITY');
          }
        })
      else ...[
        KeyValue('AUTHORITY', '${node.authorityName} (DEMO)', emphasis: true),
        const Text('Nearby responders (direct radio link):', style: TextStyle(fontSize: 11)),
        if (nearbyResponders.isEmpty) const Text('None connected directly.', style: TextStyle(fontSize: 11)),
        for (final r in nearbyResponders) _IssueTile(r),
        SectionTitle('ISSUED (${node.issuedCredentials.length})'),
        for (final c in node.issuedCredentials)
          Row(children: [
            Expanded(
              child: Text('${PublicIdentity.fingerprintOf(c.subject).substring(0, 9)} · ${c.roles.map((r) => r.label).join(', ')}'
                  '${node.revokedCredentialIds.contains(c.cid) ? ' · REVOKED' : ''}', style: const TextStyle(fontSize: 11)),
            ),
            if (!node.revokedCredentialIds.contains(c.cid))
              TextButton(onPressed: () => node.revokeCredential(c.cid), child: const Text('[ REVOKE ]')),
          ]),
        ActionButton('STOP AUTHORITY MODE', dense: true, onPressed: node.disableAuthority),
      ],
      const SectionTitle('VOUCH FOR SOMEONE YOU MET'),
      if (directIds.isEmpty) const Text('No directly connected phones.', style: TextStyle(fontSize: 11)),
      for (final id in directIds)
        Row(children: [
          Expanded(child: Text(PublicIdentity.fingerprintOf(id), style: const TextStyle(fontSize: 12))),
          TextButton(
            onPressed: () async {
              if (await confirm(context, 'VOUCH?',
                  'Vouch only if this person showed you fingerprint ${PublicIdentity.fingerprintOf(id)} in person.', yes: 'VOUCH')) {
                await node.vouch(id);
              }
            },
            child: const Text('[ VOUCH ]'),
          ),
        ]),
    ]);
  }
}

class _IssueTile extends ConsumerStatefulWidget {
  const _IssueTile(this.beacon);

  final BeaconRecord beacon;

  @override
  ConsumerState<_IssueTile> createState() => _IssueTileState();
}

class _IssueTileState extends ConsumerState<_IssueTile> {
  late final Set<Capability> _roles = {...widget.beacon.declaredCaps}..remove(Capability.general);

  @override
  Widget build(BuildContext context) {
    final node = ref.read(nodeProvider);
    final fp = PublicIdentity.fingerprintOf(widget.beacon.origin);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Boxed(
        padding: const EdgeInsets.all(8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.beacon.name.isEmpty ? 'RESPONDER' : widget.beacon.name, style: const TextStyle(fontWeight: FontWeight.w700)),
          KeyValue('FINGERPRINT', fp, emphasis: true),
          Wrap(spacing: 4, children: [
            for (final c in Capability.values.where((c) => c != Capability.general))
              FilterChip(
                shape: const RoundedRectangleBorder(),
                label: Text(c.label, style: const TextStyle(fontSize: 10)),
                selected: _roles.contains(c),
                onSelected: (v) => setState(() => v ? _roles.add(c) : _roles.remove(c)),
              ),
          ]),
          ActionButton('ISSUE — FINGERPRINT CONFIRMED', dense: true, onPressed: _roles.isEmpty
              ? null
              : () async {
                  if (await confirm(context, 'ISSUE CREDENTIAL?',
                      'Confirm in person that the responder\'s screen shows $fp and that you have checked their qualifications.',
                      yes: 'ISSUE')) {
                    await node.issueCredential(widget.beacon.origin, _roles);
                    if (context.mounted) notify(context, 'CREDENTIAL SENT OVER THE MESH');
                  }
                }),
        ]),
      ),
    );
  }
}
