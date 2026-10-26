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
import '../../ui/icons.dart';
import '../../ui/motion.dart';
import '../medical/medical_card_screen.dart';
import '../shared/hazard_dialog.dart';
import '../shared/location_link.dart';
import '../shared/mesh_bar.dart';
import '../shared/page.dart';
import '../shared/widgets.dart';

class ResponderScreen extends ConsumerStatefulWidget {
  const ResponderScreen({super.key});

  @override
  ConsumerState<ResponderScreen> createState() => _ResponderScreenState();
}

class _ResponderScreenState extends ConsumerState<ResponderScreen> {
  @override
  Widget build(BuildContext context) {
    ref.watch(nodeVersionProvider);
    ref.watch(deviceControllerProvider); // alarm state lives in the runtime
    final node = ref.watch(nodeProvider);
    final offers = node.myOffers;
    final engagements = node.myEngagements;
    final open = node.openRequests.where((o) => o.assignedTo != node.selfId).toList();
    final cs = Theme.of(context).colorScheme;

    return ResqPage(
      title: 'Respond',
      subtitle: 'You are only offered requests you are best placed to help with. Nothing moves you without your decision.',
      children: [
          const MeshBar(),
          const SizedBox(height: 12),
          const _AvailabilityStrip(),
          SectionHeader('Matched to you', trailing: offers.isEmpty ? null : StatusChip('${offers.length}', tone: Tone.danger)),
          if (offers.isEmpty)
            const EmptyState(
              icon: ResqIcons.target,
              title: 'No request matched to you',
              body: 'You will only be offered requests you are best placed to help with. Keep RES-Q open and the mesh on.',
            ),
          for (final o in offers) Padding(padding: const EdgeInsets.only(bottom: 12), child: _OfferCard(o)),
          if (engagements.isNotEmpty) const SectionHeader('Your assignments'),
          for (final e in engagements) Padding(padding: const EdgeInsets.only(bottom: 12), child: _EngagementCard(e)),
          SectionHeader('Other open requests', trailing: open.isEmpty ? null : Text('${open.length}')),
          if (open.isEmpty)
            const EmptyState(icon: ResqIcons.checkCircle, title: 'No other open requests', body: 'Nothing else is waiting nearby.'),
          for (final o in open) Padding(padding: const EdgeInsets.only(bottom: 8), child: _OpenRequestCard(o)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => showHazardDialog(context, ref),
            icon: AppIcon(ResqIcons.hazard, size: 18, color: cs.primary),
            label: const Text('Report a danger nearby'),
          ),
      ],
    );
  }
}

Widget _needsChips(SosRecord s) => Wrap(spacing: 8, runSpacing: 8, children: [
      SosClassBadge(s.urgency),
      if (s.needs.isEmpty) const StatusChip('Need unclear', icon: ResqIcons.help),
      for (final n in s.needs) StatusChip(needLabel(n), icon: needIcon(n)),
    ]);

class _ChainDetails extends StatelessWidget {
  const _ChainDetails(this.result);

  final ChainResult result;

  static const List<String> _names = ['Claim check', 'Hazard check', 'Trust', 'Distance & battery', 'Dispatch'];

  @override
  Widget build(BuildContext context) => Column(children: [
        for (var i = 0; i < result.stages.length; i++)
          ScoreRow(
            index: i + 1,
            name: _names[i],
            value: result.stages[i].score,
            passed: result.stages[i].passed,
            showBar: i != 4,
            detail: result.stages[i].reasons.take(3).join(' · ').toLowerCase().replaceAll('_', ' '),
          ),
      ]);
}

class _OfferCard extends ConsumerWidget {
  const _OfferCard(this.offer);

  final OfferView offer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final node = ref.read(nodeProvider);
    final runtime = ref.read(meshRuntimeProvider);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final a = offer.assignment;
    final s = a.sos;
    final r = a.primaryResult;
    final ringing = runtime.isOfferRinging(s.id);

    return PulseGlow(
      color: sosClassColor(s.urgency),
      active: ringing,
      child: Card(
      elevation: 1,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(height: 5, color: sosClassColor(s.urgency)),
        if (ringing)
          Material(
            color: cs.errorContainer,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
              child: Row(children: [
                AppIcon(ResqIcons.warning, size: 18, color: cs.onErrorContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Alarm ringing until you answer',
                      style: t.labelLarge?.copyWith(color: cs.onErrorContainer)),
                ),
                TextButton(
                  onPressed: () {
                    Sfx.tap();
                    runtime.silenceOffer(s.id);
                  },
                  child: const Text('Silence'),
                ),
              ]),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: _needsChips(s)),
              Text(ago(s.claimedAtMs, node.nowMs), style: t.bodySmall),
            ]),
            const SizedBox(height: 12),
            Text(offer.justification, style: t.bodyLarge),
            if (s.text != null) ...[
              const SizedBox(height: 10),
              Text('"${s.text}"', style: t.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
            ],
            const SizedBox(height: 10),
            InfoRow(ResqIcons.location, 'Location: ${r.claim.locationLabel.toLowerCase()}'),
            if (s.location != null) LocationLink(s.location!, label: 'SOS', from: node.selfLocation?.point),
            InfoRow(ResqIcons.battery, s.batteryPct == null ? 'Their battery: unknown' : 'Their battery: ${s.batteryPct}%'),
            InfoRow(s.sealed ? ResqIcons.lock : ResqIcons.unlock,
                s.readable ? (s.sealed ? 'Decrypted for you' : 'Shared openly') : 'Details withheld by the requester'),
            if (r.claim.suspectedDecoy) ...[
              const SizedBox(height: 8),
              const Callout('Not confirmed by anyone nearby. This could be a decoy — check before taking risks.',
                  tone: Tone.danger),
            ],
          ]),
        ),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            leading: AppIcon(ResqIcons.info, size: 20, color: cs.primary),
            title: Text('Why you were matched', style: t.labelLarge),
            children: [_ChainDetails(r)],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: InfoRow(ResqIcons.clock,
              'Offered to the next responder in ${offer.windowRemaining.inSeconds}s if you don\'t answer. It never accepts for you.'),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  Sfx.warn();
                  runtime.silenceOffer(s.id);
                  node.respond(s.id, SosEventKind.declined);
                },
                child: const Text('Decline'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () async {
                  Sfx.success();
                  runtime.silenceOffer(s.id);
                  await node.respond(s.id, SosEventKind.accepted);
                  if (context.mounted) notify(context, 'Accepted. Their phone will ring when your answer reaches them.');
                },
                icon: AppIcon(ResqIcons.check, size: 18, color: cs.onPrimary),
                label: const Text('Accept'),
              ),
            ),
          ]),
        ),
      ]),
      ),
    );
  }
}

class _EngagementCard extends ConsumerWidget {
  const _EngagementCard(this.e);

  final EngagementView e;

  static String _phase(SosPhase p) => switch (p) {
        SosPhase.searching => 'Open',
        SosPhase.accepted => 'Accepted',
        SosPhase.enRoute => 'On the way',
        SosPhase.onScene => 'On scene',
        SosPhase.resolved => 'Resolved',
        SosPhase.cancelled => 'Cancelled by requester',
        SosPhase.expired => 'Expired',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final node = ref.read(nodeProvider);
    final t = Theme.of(context).textTheme;
    final s = e.sos;
    final closed = e.state.phase == SosPhase.resolved || e.state.phase == SosPhase.cancelled;

    Widget stepButton(String label, SosEventKind kind) {
      final done = e.myProgress >= kind.progress;
      final next = e.myProgress + 1 == kind.progress;
      final child = Text(label, textAlign: TextAlign.center);
      if (done) {
        return FilledButton.tonalIcon(onPressed: null, icon: AppIcon(ResqIcons.check, size: 16), label: child);
      }
      void press() {
        Sfx.success();
        node.respond(s.id, kind);
      }

      return next
          ? FilledButton(onPressed: press, child: child)
          : OutlinedButton(onPressed: press, child: child);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: _needsChips(s)),
            StatusChip(_phase(e.state.phase), tone: closed ? Tone.neutral : Tone.info),
          ]),
          if (s.text != null) ...[const SizedBox(height: 10), Text('"${s.text}"', style: t.bodyMedium)],
          if (s.location != null) ...[
            const SizedBox(height: 8),
            LocationLink(s.location!, title: 'Go to', label: 'SOS', from: node.selfLocation?.point),
          ],
          if (e.myProgress < SosEventKind.onScene.progress && s.location != null && !closed)
            const InfoRow(ResqIcons.flag, 'You will be marked ON SCENE automatically when your GPS reaches them.'),
          if (node.receivedCardFor(s.id) case final card?) ...[
            const SizedBox(height: 10),
            MedicalCardView(card),
          ],
          if (e.state.orphaned.contains(node.selfId)) ...[
            const SizedBox(height: 8),
            const Callout('Your assignment was released after loss of contact. The request is open again.', tone: Tone.warn),
          ],
          if (e.standDown) ...[
            const SizedBox(height: 8),
            const Callout('Another responder has precedence for this request. Please stand down.',
                title: 'Stand down', tone: Tone.warn),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: () => node.respond(s.id, SosEventKind.standDown),
              child: const Text('OK, standing down'),
            ),
          ] else if (e.state.conflicts.contains('MULTIPLE_ON_SCENE')) ...[
            const SizedBox(height: 8),
            const Callout('Another responder also reports being on scene. Coordinate in person.', tone: Tone.info),
          ],
          if (!closed && !e.standDown) ...[
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: stepButton('On the way', SosEventKind.enRoute)),
              const SizedBox(width: 8),
              Expanded(child: stepButton('On scene', SosEventKind.onScene)),
              const SizedBox(width: 8),
              Expanded(child: stepButton('Resolved', SosEventKind.resolved)),
            ]),
            if (e.myProgress < SosEventKind.onScene.progress)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () async {
                    if (await confirm(context, 'Withdraw?', 'The request will be offered to the next responder.', yes: 'Withdraw')) {
                      await node.respond(s.id, SosEventKind.standDown, note: 'withdrawn');
                    }
                  },
                  child: const Text('Withdraw'),
                ),
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
    final t = Theme.of(context).textTheme;
    final cred = node.myCredential;
    final status = cred == null
        ? CredentialStatus.none
        : (!node.anchors.contains(cred.issuer)
            ? CredentialStatus.unknownIssuer
            : (node.revokedCredentialIds.contains(cred.cid)
                ? CredentialStatus.revoked
                : (cred.expiresAtMs <= node.nowMs ? CredentialStatus.expired : CredentialStatus.verified)));
    final verified = status == CredentialStatus.verified;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(
            controller: controller,
            maxLength: Limits.maxProfileTextChars,
            maxLines: 3,
            minLines: 1,
            decoration: const InputDecoration(
              labelText: 'What can you do?',
              hintText: 'e.g. nurse, boat hai, tractor, can swim',
              helperText: 'Any language',
            ),
            onSubmitted: node.setProfile,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonal(
              onPressed: () {
                node.setProfile(controller.text);
                FocusScope.of(context).unfocus();
              },
              child: const Text('Save'),
            ),
          ),
          const SizedBox(height: 8),
          if (node.profile.capabilities.isEmpty)
            Text('No skills recognised yet.', style: t.bodySmall)
          else
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in node.profile.capabilities)
                StatusChip(capabilityLabel(c), icon: capabilityIcon(c), tone: verified && cred!.roles.contains(c) ? Tone.good : Tone.neutral),
            ]),
          if (node.profile.unrecognized)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: InfoRow(ResqIcons.info, 'Not recognised automatically — kept as general help for people to judge.'),
            ),
          const SizedBox(height: 12),
          InfoRow(
            verified ? ResqIcons.shieldCheck : ResqIcons.shield,
            verified
                ? 'Verified by ${cred!.issuerName}: ${cred.roles.map(capabilityLabel).join(', ')}'
                : switch (status) {
                    CredentialStatus.none => 'Not verified — others see your skills as self-declared',
                    CredentialStatus.unknownIssuer => 'Credential from an authority this phone does not trust',
                    CredentialStatus.revoked => 'Your credential was revoked',
                    CredentialStatus.expired => 'Your credential has expired',
                    _ => 'Credential could not be verified',
                  },
            tone: verified ? Tone.good : null,
          ),
          InfoRow(ResqIcons.fingerprint, PublicIdentity.fingerprintOf(node.selfId), mono: true),
          const Divider(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: node.available,
            onChanged: node.setAvailable,
            title: const Text('Available for requests'),
            subtitle: Text(node.available ? 'You can be matched to people nearby' : 'You will not receive offers'),
          ),
        ]),
      ),
    );
  }
}

class _OpenRequestCard extends ConsumerWidget {
  const _OpenRequestCard(this.o);

  final OpenRequestView o;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final node = ref.read(nodeProvider);
    final t = Theme.of(context).textTheme;
    final mine = o.myResult;
    final String status;
    if (o.assignedTo == null) {
      status = o.unmatchedReason == 'NO_RESPONDERS_KNOWN' ? 'No responders known nearby' : 'No suitable responder yet';
    } else {
      final name = node.beacons[o.assignedTo]?.name ?? '';
      status = 'Matched to ${name.isNotEmpty ? name : 'another responder'}';
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _needsChips(o.sos),
              const SizedBox(height: 8),
              Text('$status · ${ago(o.sos.claimedAtMs, node.nowMs)}', style: t.bodySmall),
              if (mine != null && !mine.eligible)
                Text('Not offered to you: ${mine.blockingReasons.take(1).join().toLowerCase().replaceAll('_', ' ')}',
                    style: t.bodySmall),
            ]),
          ),
          TextButton(
            onPressed: () async {
              final ok = await confirm(
                context,
                'Volunteer for this request?',
                o.assignedTo == null
                    ? 'No responder is matched yet. Check for hazards before moving.'
                    : 'Someone better placed was matched. If you both go, one of you will be asked to stand down.',
                yes: 'Volunteer',
              );
              if (ok) await node.respond(o.sos.id, SosEventKind.accepted, note: 'volunteered');
            },
            child: const Text('Volunteer'),
          ),
        ]),
      ),
    );
  }
}

/// Top of the responder screen: one switch for availability and the skills
/// others see, with a link to edit them.
class _AvailabilityStrip extends ConsumerWidget {
  const _AvailabilityStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final node = ref.watch(nodeProvider);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final caps = node.profile.capabilities;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: node.available,
            onChanged: (v) {
              Sfx.tap();
              node.setAvailable(v);
            },
            title: Text(node.available ? 'Available for requests' : 'Not available', style: t.titleMedium),
            subtitle: Text(node.available ? 'Nearby people can be matched to you' : 'You will not receive offers'),
          ),
          Row(children: [
            Expanded(
              child: caps.isEmpty
                  ? Text('No skills added yet', style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant))
                  : Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final c in caps) StatusChip(capabilityLabel(c), icon: capabilityIcon(c), tone: Tone.info),
                    ]),
            ),
            TextButton(
              onPressed: () {
                Sfx.tap();
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const _SkillsScreen()));
              },
              child: Text(caps.isEmpty ? 'Add skills' : 'Edit'),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _SkillsScreen extends ConsumerStatefulWidget {
  const _SkillsScreen();

  @override
  ConsumerState<_SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends ConsumerState<_SkillsScreen> {
  late final TextEditingController _profile = TextEditingController(text: ref.read(nodeProvider).profileText);

  @override
  void dispose() {
    _profile.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(nodeVersionProvider);
    return SubPage(
      title: 'Your skills',
      subtitle: 'Say what you can do in any language. People in need see your profession when you accept.',
      children: [_ProfileCard(controller: _profile)],
    );
  }
}
