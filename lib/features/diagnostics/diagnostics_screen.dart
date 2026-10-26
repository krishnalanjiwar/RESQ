import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../crypto/identity.dart';
import '../../domain/models.dart';
import '../../domain/world.dart';
import '../../sim/simulator.dart';
import '../../ui/icons.dart';
import '../shared/back_to_start.dart';
import '../shared/mesh_bar.dart';
import '../shared/status_drawer.dart';
import '../shared/widgets.dart';
import 'sim_map.dart';

class DiagnosticsScreen extends StatelessWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context) => BackToStartScope(
        builder: (context, scaffoldKey) => DefaultTabController(
        length: 3,
        child: Scaffold(
          key: scaffoldKey,
          appBar: AppBar(
            leading: const BackToStartButton(),
            title: const Text('Test & train'),
            actions: const [HomeButton(), StatusButton(), SizedBox(width: 4)],
            bottom: TabBar(tabs: [
              Tab(icon: AppIcon(ResqIcons.map, size: 20), text: 'Simulator'),
              Tab(icon: AppIcon(ResqIcons.mesh, size: 20), text: 'This phone'),
              Tab(icon: AppIcon(ResqIcons.shield, size: 20), text: 'Trust'),
            ]),
          ),
          endDrawer: const StatusDrawer(),
          body: const TabBarView(children: [_SimulatorTab(), _DeviceTab(), _TrustTab()]),
        ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Simulator / Red Team
// ---------------------------------------------------------------------------

class _SimulatorTab extends ConsumerWidget {
  const _SimulatorTab();

  static Tone _outcomeTone(AttackOutcome o) => switch (o) {
        AttackOutcome.blocked || AttackOutcome.quarantined => Tone.good,
        AttackOutcome.flagged => Tone.warn,
        AttackOutcome.notBlocked => Tone.danger,
      };

  static String _outcomeLabel(AttackOutcome o) => switch (o) {
        AttackOutcome.blocked => 'Blocked',
        AttackOutcome.quarantined => 'Quarantined',
        AttackOutcome.flagged => 'Flagged',
        AttackOutcome.notBlocked => 'Not blocked',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(simControllerProvider);
    final ctrl = ref.read(simControllerProvider.notifier);
    final sim = st.sim;
    final busy = st.busy;
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    Widget chip(String label, String icon, VoidCallback onTap) => ActionChip(
          avatar: AppIcon(icon, size: 18, color: cs.primary),
          label: Text(label),
          onPressed: busy ? null : onTap,
        );

    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
      const SimulationBanner(
          'A virtual city of real RES-Q nodes on a simulated radio. Attacks inject real messages and the results are measured. '
          'Nothing here touches this phone\'s real data.'),
      if (st.error != null) ...[const SizedBox(height: 12), Callout(st.error!, tone: Tone.danger)],
      const SizedBox(height: 16),
      if (sim == null)
        FilledButton.icon(
          onPressed: busy ? null : ctrl.buildCity,
          icon: busy
              ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary))
              : AppIcon(ResqIcons.map, size: 18, color: cs.onPrimary),
          label: Text(busy ? 'Building city…' : 'Build simulated city'),
        )
      else ...[
        SimMap(sim: sim, version: st.version),
        const SizedBox(height: 8),
        Text(
          'Step ${sim.steps} · ${sim.steps * Simulator.stepDuration.inSeconds}s simulated · ${sim.nodes.length} phones · '
          '${sim.radio.links.length} links${sim.partitioned ? ' · network split' : ''}',
          style: t.bodySmall,
        ),
        const SectionHeader('Run'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.tonalIcon(
            onPressed: busy ? null : ctrl.step,
            icon: AppIcon(ResqIcons.step, size: 18),
            label: const Text('Step'),
          ),
          FilledButton.icon(
            onPressed: ctrl.toggleRun,
            icon: AppIcon(st.running ? ResqIcons.pause : ResqIcons.play, size: 18, color: cs.onPrimary),
            label: Text(st.running ? 'Pause' : 'Run'),
          ),
          OutlinedButton.icon(
            onPressed: busy
                ? null
                : () async {
                    if (await confirm(context, 'Reset simulation?', 'Removes the simulated city and all results.', yes: 'Reset')) {
                      await ctrl.reset();
                    }
                  },
            icon: AppIcon(ResqIcons.refresh, size: 18, color: cs.primary),
            label: const Text('Reset'),
          ),
        ]),
        const SectionHeader('Scenario'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          chip('Report flood', ResqIcons.water, ctrl.reportFlood),
          chip('Send SOS', ResqIcons.send, ctrl.seedEmergencies),
          chip('Split & double dispatch', ResqIcons.split, ctrl.partitionScenario),
          chip(sim.partitioned ? 'Heal network split' : 'Split network', ResqIcons.split, ctrl.togglePartition),
        ]),
        const SectionHeader('Red Team attacks'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          chip('Sybil: 40 fake nurses', ResqIcons.group, ctrl.sybil),
          chip('Forged credential', ResqIcons.badge, ctrl.forgedCredential),
          chip('Spoofed location', ResqIcons.locationOff, ctrl.spoofedLocation),
          chip('Floodwater lure', ResqIcons.hazard, ctrl.floodLure),
          chip('Battery-drain flood', ResqIcons.bolt, ctrl.batteryDrainAttack),
          chip('Relays to 10% battery', ResqIcons.batteryLow, () => ctrl.drainRelayBatteries(10)),
          chip('Restore batteries', ResqIcons.battery, () => ctrl.drainRelayBatteries(null)),
        ]),
        SectionHeader('Results', trailing: sim.results.isEmpty ? null : Text('${sim.results.length}')),
        if (sim.results.isEmpty)
          const EmptyState(icon: ResqIcons.target, title: 'No results yet', body: 'Run an attack or split the network to see measured outcomes.'),
        for (final r in sim.results.reversed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(child: Text(r.attack, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
                    StatusChip(_outcomeLabel(r.outcome), tone: _outcomeTone(r.outcome),
                        icon: r.outcome == AttackOutcome.notBlocked ? ResqIcons.warning : ResqIcons.shieldCheck),
                  ]),
                  const SizedBox(height: 8),
                  for (final d in r.details) Text(d, style: t.bodySmall),
                ]),
              ),
            ),
          ),
        _ObserverPanel(sim: sim),
        const SizedBox(height: 8),
        Card(
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              title: const Text('Simulation log'),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children: [
                for (final e in sim.log.entries.take(30))
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('${e.code.toLowerCase().replaceAll('_', ' ')}${e.detail.isEmpty ? '' : ' — ${e.detail}'}',
                        style: t.bodySmall),
                  ),
              ],
            ),
          ),
        ),
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
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeader('Network view from ${sim.observer.label}'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            InfoRow(ResqIcons.split, '${report.conflicts} conflict(s) across ${report.sosCount} SOS'),
            InfoRow(ResqIcons.route, '${report.standDownsIssued} stand-down(s) · ${report.orphansReopened} reopened'),
            for (final s in node.states.values.take(6))
              InfoRow(ResqIcons.status, '${s.sosId.substring(0, 6)} · ${s.phase.label.toLowerCase()}'),
          ]),
        ),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// This phone (real radio)
// ---------------------------------------------------------------------------

class _DeviceTab extends ConsumerWidget {
  const _DeviceTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(nodeVersionProvider);
    final node = ref.watch(nodeProvider);
    final peers = node.peers;
    final power = node.powerPolicy;
    final t = Theme.of(context).textTheme;

    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
      const MeshBar(),
      SectionHeader('Nearby phones', trailing: Text('${peers.length}')),
      if (peers.isEmpty)
        const EmptyState(icon: ResqIcons.peers, title: 'No phones connected', body: 'Real radio only — simulated phones never appear here.'),
      for (final p in peers)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            child: ListTile(
              leading: IconCircle(p.beacon?.role == NodeRole.responder ? ResqIcons.lifebuoy : ResqIcons.person, size: 40),
              title: Text(p.identity == null ? 'Unidentified link' : PublicIdentity.fingerprintOf(p.identity!),
                  style: const TextStyle(fontFamily: 'RobotoMono')),
              subtitle: Text([
                p.beacon == null ? 'No status yet' : p.beacon!.role.label.toLowerCase(),
                if (p.trust != null) p.trust!.credentialStatus.label.toLowerCase(),
                if (p.beacon?.batteryPct != null) 'battery ${p.beacon!.batteryPct}%',
                if (p.directIdentities >= 3) '${p.directIdentities} identities on one link — suspicious',
              ].join(' · ')),
            ),
          ),
        ),
      const SectionHeader('Battery'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            InfoRow(ResqIcons.battery, node.realBattery == null ? 'Battery reading unavailable' : 'Real battery: ${node.realBattery}%'),
            if (power.isSimulatedOverride) InfoRow(ResqIcons.flask, 'Simulated override: ${node.batteryOverride}%', tone: Tone.good),
            InfoRow(ResqIcons.bolt, 'Policy: ${power.mode.label.toLowerCase()}'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              OutlinedButton(onPressed: () => node.setBatteryOverride(10), child: const Text('Simulate 10%')),
              TextButton(onPressed: () => node.setBatteryOverride(null), child: const Text('Clear')),
            ]),
          ]),
        ),
      ),
      const SectionHeader('Data on this phone'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            InfoRow(ResqIcons.status, '${node.counts.liveMessages} live messages'),
            InfoRow(ResqIcons.shieldAlert, '${node.counts.penalisedIdentities} blocked identities'),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () async {
                  if (await confirm(context, 'Delete local data?',
                      'Removes stored requests, events, hazards and settings on this phone. Your identity keys are kept.',
                      yes: 'Delete', destructive: true)) {
                    await node.wipeLocalData();
                  }
                },
                icon: AppIcon(ResqIcons.trash, size: 18, color: Theme.of(context).colorScheme.error),
                label: const Text('Delete local data'),
              ),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      Card(
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            title: const Text('Event log'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            children: [
              for (final e in node.log.entries.take(40))
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('${ago(e.atMs, node.nowMs)} · ${e.code.toLowerCase().replaceAll('_', ' ')}${e.detail.isEmpty ? '' : ' — ${e.detail}'}',
                      style: t.bodySmall),
                ),
            ],
          ),
        ),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Trust: authorities, credentials, vouching (always confirmed in person)
// ---------------------------------------------------------------------------

class _TrustTab extends ConsumerWidget {
  const _TrustTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(nodeVersionProvider);
    final node = ref.watch(nodeProvider);
    final t = Theme.of(context).textTheme;
    final directIds = {for (final p in node.peers) ?p.identity};
    final nearbyResponders = [
      for (final id in directIds)
        if (node.beacons[id]?.role == NodeRole.responder) node.beacons[id]!,
    ];

    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
      const Callout(
        'Trust is set up in person. Compare the fingerprint shown on both phones before pinning, issuing or vouching. '
        'A signature proves who holds a key, not their real identity.',
        tone: Tone.info,
        icon: ResqIcons.fingerprint,
      ),
      const SectionHeader('This phone'),
      Card(
        child: ListTile(
          leading: const IconCircle(ResqIcons.fingerprint),
          title: Text(PublicIdentity.fingerprintOf(node.selfId), style: const TextStyle(fontFamily: 'RobotoMono')),
          subtitle: const Text('Your fingerprint'),
        ),
      ),
      const SectionHeader('Authorities nearby'),
      if (node.unpinnedAuthorities.isEmpty)
        const EmptyState(icon: ResqIcons.shield, title: 'None found', body: 'Authorities that are not yet trusted on this phone appear here.'),
      for (final a in node.unpinnedAuthorities)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: Text(a.authorityName!, style: t.titleSmall)),
                  const StatusChip('Demo authority', tone: Tone.good),
                ]),
                InfoRow(ResqIcons.fingerprint, PublicIdentity.fingerprintOf(a.origin), mono: true),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () async {
                      if (await confirm(context, 'Trust this authority?',
                          'Only continue if the operator showed you ${PublicIdentity.fingerprintOf(a.origin)} in person. '
                          'Credentials it issues will count as verified on this phone.', yes: 'Trust')) {
                        await node.pinAnchor(a.origin);
                      }
                    },
                    child: const Text('Trust — checked in person'),
                  ),
                ),
              ]),
            ),
          ),
        ),
      if (node.pinnedAnchors.isNotEmpty) ...[
        const SectionHeader('Trusted authorities'),
        Card(
          child: Column(children: [
            for (final k in node.pinnedAnchors)
              ListTile(
                leading: const IconCircle(ResqIcons.shieldCheck, tone: Tone.good, size: 36),
                title: Text(PublicIdentity.fingerprintOf(k), style: const TextStyle(fontFamily: 'RobotoMono')),
                trailing: TextButton(onPressed: () => node.unpinAnchor(k), child: const Text('Remove')),
              ),
          ]),
        ),
      ],
      const SectionHeader('Authority mode (demo)'),
      if (node.authorityName == null)
        Card(
          child: ListTile(
            leading: const IconCircle(ResqIcons.badge, tone: Tone.good),
            title: const Text('Act as a demo authority'),
            subtitle: const Text('Issue responder credentials. Real deployments use keys held by hospitals or agencies.'),
            onTap: () async {
              if (await confirm(context, 'Act as demo authority?',
                  'This phone will be able to issue responder credentials. It is clearly labelled as a demo.', yes: 'Enable')) {
                await node.enableAuthority('Demo authority');
              }
            },
          ),
        )
      else ...[
        Card(
          child: ListTile(
            leading: const IconCircle(ResqIcons.badge, tone: Tone.good),
            title: Text(node.authorityName!),
            subtitle: const Text('Demo authority is active'),
            trailing: TextButton(onPressed: node.disableAuthority, child: const Text('Stop')),
          ),
        ),
        const SizedBox(height: 8),
        if (nearbyResponders.isEmpty)
          const EmptyState(icon: ResqIcons.lifebuoy, title: 'No responders connected directly', body: 'Responders must be next to you to be verified.'),
        for (final r in nearbyResponders) Padding(padding: const EdgeInsets.only(bottom: 8), child: _IssueCard(r)),
        if (node.issuedCredentials.isNotEmpty) ...[
          const SectionHeader('Issued credentials'),
          Card(
            child: Column(children: [
              for (final c in node.issuedCredentials)
                ListTile(
                  title: Text(PublicIdentity.fingerprintOf(c.subject).substring(0, 9), style: const TextStyle(fontFamily: 'RobotoMono')),
                  subtitle: Text(c.roles.map(capabilityLabel).join(', ')),
                  trailing: node.revokedCredentialIds.contains(c.cid)
                      ? const StatusChip('Revoked', tone: Tone.danger)
                      : TextButton(onPressed: () => node.revokeCredential(c.cid), child: const Text('Revoke')),
                ),
            ]),
          ),
        ],
      ],
      const SectionHeader('Vouch for someone you met'),
      if (directIds.isEmpty)
        const EmptyState(icon: ResqIcons.group, title: 'No phones connected directly', body: 'You can only vouch for someone next to you.'),
      if (directIds.isNotEmpty)
        Card(
          child: Column(children: [
            for (final id in directIds)
              ListTile(
                leading: const IconCircle(ResqIcons.person, size: 36),
                title: Text(PublicIdentity.fingerprintOf(id), style: const TextStyle(fontFamily: 'RobotoMono')),
                trailing: TextButton(
                  onPressed: () async {
                    if (await confirm(context, 'Vouch for this person?',
                        'Only vouch if they showed you ${PublicIdentity.fingerprintOf(id)} in person.', yes: 'Vouch')) {
                      await node.vouch(id);
                    }
                  },
                  child: const Text('Vouch'),
                ),
              ),
          ]),
        ),
    ]);
  }
}

class _IssueCard extends ConsumerStatefulWidget {
  const _IssueCard(this.beacon);

  final BeaconRecord beacon;

  @override
  ConsumerState<_IssueCard> createState() => _IssueCardState();
}

class _IssueCardState extends ConsumerState<_IssueCard> {
  late final Set<Capability> _roles = {...widget.beacon.declaredCaps}..remove(Capability.general);

  @override
  Widget build(BuildContext context) {
    final node = ref.read(nodeProvider);
    final fp = PublicIdentity.fingerprintOf(widget.beacon.origin);
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.beacon.name.isEmpty ? 'Responder' : widget.beacon.name, style: t.titleSmall),
          InfoRow(ResqIcons.fingerprint, fp, mono: true),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final c in Capability.values.where((c) => c != Capability.general))
              FilterChip(
                label: Text(capabilityLabel(c)),
                selected: _roles.contains(c),
                onSelected: (v) => setState(() => v ? _roles.add(c) : _roles.remove(c)),
              ),
          ]),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _roles.isEmpty
                  ? null
                  : () async {
                      if (await confirm(context, 'Issue credential?',
                          'Check in person that their screen shows $fp and that you have verified their qualifications.',
                          yes: 'Issue')) {
                        await node.issueCredential(widget.beacon.origin, _roles);
                        if (context.mounted) notify(context, 'Credential sent over the mesh.');
                      }
                    },
              child: const Text('Issue — checked in person'),
            ),
          ),
        ]),
      ),
    );
  }
}
