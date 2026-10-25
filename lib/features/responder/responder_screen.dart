import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../crypto/identity.dart';
import '../../domain/chain/evaluation_chain.dart';
import '../../domain/models.dart';
import '../../domain/reconcile/reconciler.dart';
import '../../domain/trust/trust_agent.dart';
import '../../domain/world.dart';
import '../../node/views.dart';
import '../../protocol/limits.dart';
import '../shared/hazard_dialog.dart';
import '../shared/mesh_bar.dart';
import '../shared/status_drawer.dart';
import '../shared/widgets.dart';

class ResponderScreen extends ConsumerStatefulWidget {
  const ResponderScreen({super.key});

  @override
  ConsumerState<ResponderScreen> createState() => _ResponderScreenState();
}

class _ResponderScreenState extends ConsumerState<ResponderScreen> {
  late final TextEditingController _profile = TextEditingController(text: ref.read(nodeProvider).profileText);

  @override
  void dispose() {
    _profile.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(nodeVersionProvider);
    final node = ref.watch(nodeProvider);
    final offers = node.myOffers;
    final engagements = node.myEngagements;
    final open = node.openRequests.where((o) => o.assignedTo != node.selfId).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('RESPONDER')),
      endDrawer: const StatusDrawer(),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const MeshBar(),
          SectionTitle('OFFERS FOR YOU (${offers.length})'),
          if (offers.isEmpty)
            const Text('No request is currently matched to you. You are only offered what you are best placed to do.',
                style: TextStyle(fontSize: 12)),
          for (final o in offers) _OfferCard(o),
          if (engagements.isNotEmpty) const SectionTitle('YOUR ASSIGNMENTS'),
          for (final e in engagements) _EngagementCard(e),
          const SectionTitle('MY CAPABILITIES'),
          _ProfileCard(controller: _profile),
          SectionTitle('OTHER OPEN REQUESTS (${open.length})'),
          if (open.isEmpty) const Text('None known.', style: TextStyle(fontSize: 12)),
          for (final o in open) _OpenRequestCard(o),
          const SizedBox(height: 12),
          ActionButton('REPORT HAZARD', dense: true, onPressed: () => showHazardDialog(context, ref)),
        ]),
      ),
    );
  }
}

class _ChainTable extends StatelessWidget {
  const _ChainTable(this.result);

  final ChainResult result;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < result.stages.length; i++) ...[
          Text(
            '${i + 1}. ${result.stages[i].name}  ${i == 4 ? '' : scoreBar(result.stages[i].score)}'
            '${result.stages[i].passed ? '' : '  ✕ BLOCKED'}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 4),
            child: Text(result.stages[i].reasons.take(4).join(' · '), style: const TextStyle(fontSize: 10)),
          ),
        ],
      ]);
}

String _sosSummary(SosRecord s, int now) {
  final needs = s.needs.isEmpty ? 'NEED UNCLEAR' : s.needs.map((n) => n.label).join(' + ');
  return '${s.urgency.label} · $needs · ${ago(s.claimedAtMs, now)}';
}

class _OfferCard extends ConsumerWidget {
  const _OfferCard(this.offer);

  final OfferView offer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final node = ref.read(nodeProvider);
    final a = offer.assignment;
    final s = a.sos;
    final r = a.primaryResult;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Boxed(
        thick: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(_sosSummary(s, node.nowMs), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 6),
          Text(offer.justification, style: const TextStyle(fontSize: 13)),
          const Divider(height: 20),
          KeyValue('REQUEST', s.id.substring(0, 8)),
          KeyValue('LOCATION', r.claim.locationLabel),
          KeyValue('VICTIM BATTERY', s.batteryPct == null ? 'UNKNOWN' : '${s.batteryPct}%'),
          KeyValue('CONTENT', s.readable ? (s.sealed ? 'DECRYPTED FOR YOU' : 'SHARED OPENLY') : 'SEALED — not addressed to you'),
          if (s.text != null) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('"${s.text}"')),
          if (r.claim.suspectedDecoy) const Text('⚠ UNCORROBORATED — POSSIBLE DECOY', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          _ChainTable(r),
          Text(
            'OFFER WINDOW ${offer.windowRemaining.inSeconds}s — informational. It never accepts for you; '
            'when it ends the request is offered to the next responder.',
            style: const TextStyle(fontSize: 10),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: ActionButton('ACCEPT', primary: true, onPressed: () async {
                await node.respond(s.id, SosEventKind.accepted);
                if (context.mounted) notify(context, 'ACCEPTANCE SAVED — SHARING WITH PEERS');
              }),
            ),
            const SizedBox(width: 8),
            Expanded(child: ActionButton('DECLINE', onPressed: () => node.respond(s.id, SosEventKind.declined))),
          ]),
        ]),
      ),
    );
  }
}

class _EngagementCard extends ConsumerWidget {
  const _EngagementCard(this.e);

  final EngagementView e;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final node = ref.read(nodeProvider);
    final s = e.sos;
    Widget progress(String label, SosEventKind kind) => Expanded(
          child: ActionButton(label,
              dense: true,
              primary: e.myProgress + 1 == kind.progress,
              onPressed: e.myProgress >= kind.progress ? null : () => node.respond(s.id, kind)),
        );
    final closed = e.state.phase == SosPhase.resolved || e.state.phase == SosPhase.cancelled;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Boxed(
        thick: e.isPrimary,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(_sosSummary(s, node.nowMs), style: const TextStyle(fontWeight: FontWeight.w700)),
          KeyValue('STATUS', e.state.phase.label),
          if (e.state.orphaned.contains(node.selfId))
            const Text('YOUR ASSIGNMENT WAS RELEASED AFTER LOSS OF CONTACT. The request is open again.',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          if (e.standDown) ...[
            const Text('STAND DOWN — another responder has precedence for this request.',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            ActionButton('ACKNOWLEDGE STAND DOWN', dense: true, onPressed: () => node.respond(s.id, SosEventKind.standDown)),
          ] else if (e.state.conflicts.contains('MULTIPLE_ON_SCENE'))
            const Text('STATUS CONFLICT — another responder is also on scene. Coordinate in person.',
                style: TextStyle(fontWeight: FontWeight.w700)),
          if (s.text != null) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text('"${s.text}"')),
          if (s.location != null) KeyValue('LOCATION', '${s.location!.point} ±${s.location!.accuracyM.round()} m'),
          if (!closed && !e.standDown) ...[
            const SizedBox(height: 8),
            Row(children: [
              progress('EN ROUTE', SosEventKind.enRoute),
              const SizedBox(width: 6),
              progress('ON SCENE', SosEventKind.onScene),
              const SizedBox(width: 6),
              progress('RESOLVED', SosEventKind.resolved),
            ]),
            if (e.myProgress < SosEventKind.onScene.progress)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: ActionButton('WITHDRAW', dense: true, onPressed: () async {
                  if (await confirm(context, 'WITHDRAW?', 'The request will be offered to the next responder.')) {
                    await node.respond(s.id, SosEventKind.standDown, note: 'withdrawn');
                  }
                }),
              ),
          ],
        ]),
      ),
    );
  }
}

class _ProfileCard extends ConsumerWidget {
  const _ProfileCard({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final node = ref.watch(nodeProvider);
    final trust = node.trustOf(node.selfId);
    final cred = node.myCredential;
    final status = cred == null
        ? CredentialStatus.none
        : (!node.anchors.contains(cred.issuer)
            ? CredentialStatus.unknownIssuer
            : (node.revokedCredentialIds.contains(cred.cid)
                ? CredentialStatus.revoked
                : (cred.expiresAtMs <= node.nowMs ? CredentialStatus.expired : CredentialStatus.verified)));
    return Boxed(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
          controller: controller,
          maxLength: Limits.maxProfileTextChars,
          maxLines: 3,
          minLines: 1,
          decoration: const InputDecoration(
            labelText: 'WHAT CAN YOU DO? (any language)',
            hintText: 'e.g. nurse · boat hai · tractor · can swim',
          ),
          onSubmitted: node.setProfile,
        ),
        ActionButton('SAVE CAPABILITIES', dense: true, onPressed: () {
          node.setProfile(controller.text);
          FocusScope.of(context).unfocus();
        }),
        const SizedBox(height: 8),
        Text(
          node.profile.capabilities.isEmpty
              ? 'NO CAPABILITIES PARSED YET'
              : 'PARSED: ${node.profile.capabilities.map((c) => c.label).join(' · ')}',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        if (node.profile.unrecognized)
          const Text('Not recognised by the rules — kept as GENERAL HELP for human judgement.', style: TextStyle(fontSize: 11)),
        KeyValue('VERIFICATION', status == CredentialStatus.verified
            ? 'VERIFIED: ${cred!.roles.map((r) => r.label).join(', ')} by ${cred.issuerName}'
            : '${status.label}${status == CredentialStatus.none ? ' (claims shown as unverified to others)' : ''}'),
        KeyValue('TRUST (LOCAL VIEW)', trust.level.name.toUpperCase()),
        KeyValue('MY FINGERPRINT', PublicIdentity.fingerprintOf(node.selfId)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: node.available,
          onChanged: node.setAvailable,
          title: Text(node.available ? 'AVAILABLE FOR REQUESTS' : 'NOT AVAILABLE', style: const TextStyle(fontSize: 13)),
        ),
      ]),
    );
  }
}

class _OpenRequestCard extends ConsumerWidget {
  const _OpenRequestCard(this.o);

  final OpenRequestView o;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final node = ref.read(nodeProvider);
    final mine = o.myResult;
    final assigned = o.assignedTo == null
        ? (o.unmatchedReason == 'NO_RESPONDERS_KNOWN' ? 'NO RESPONDERS KNOWN NEARBY' : 'NO ELIGIBLE RESPONDER YET')
        : 'MATCHED TO ANOTHER RESPONDER (${node.beacons[o.assignedTo]?.name.isNotEmpty == true ? node.beacons[o.assignedTo]!.name : PublicIdentity.fingerprintOf(o.assignedTo!).substring(0, 9)})';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Boxed(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(_sosSummary(o.sos, node.nowMs), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          Text(assigned, style: const TextStyle(fontSize: 11)),
          if (o.sos.triage?.needsReview ?? (o.sos.urgency == Urgency.unknown))
            const Text('NEEDS HUMAN REVIEW', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          if (mine != null && !mine.eligible)
            Text('Not offered to you: ${mine.blockingReasons.take(2).join(' · ')}', style: const TextStyle(fontSize: 10)),
          const SizedBox(height: 6),
          ActionButton('VOLUNTEER ANYWAY', dense: true, onPressed: () async {
            final ok = await confirm(
              context,
              'VOLUNTEER FOR THIS REQUEST?',
              o.assignedTo == null
                  ? 'No responder is matched yet. You will be shown as accepted; check hazards before moving.'
                  : 'The matcher picked a better-placed responder. If both of you go, reconciliation will ask one to stand down.',
              yes: 'ACCEPT',
            );
            if (ok) await node.respond(o.sos.id, SosEventKind.accepted, note: 'volunteered');
          }),
        ]),
      ),
    );
  }
}
