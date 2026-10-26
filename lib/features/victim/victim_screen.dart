import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models.dart';
import '../../domain/reconcile/reconciler.dart';
import '../../domain/triage/triage_agent.dart';
import '../../node/views.dart';
import '../../protocol/limits.dart';
import '../../ui/icons.dart';
import '../../ui/motion.dart';
import '../medical/medical_card_screen.dart';
import '../shared/hazard_dialog.dart';
import '../shared/mesh_bar.dart';
import '../shared/page.dart';
import '../shared/widgets.dart';

class VictimScreen extends ConsumerStatefulWidget {
  const VictimScreen({super.key});

  @override
  ConsumerState<VictimScreen> createState() => _VictimScreenState();
}

class _VictimScreenState extends ConsumerState<VictimScreen> with SingleTickerProviderStateMixin {
  final _text = TextEditingController();
  final _focus = FocusNode();
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
  bool _attachLocation = true;
  bool _shareOpenly = true;
  bool _sending = false;
  TriageResult? _preview;

  static const TriageAgent _triage = TriageAgent();

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() => _preview = _text.text.trim().isEmpty ? null : _triage.analyze(_text.text)));
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_text.text.trim().isEmpty) {
      Sfx.warn();
      _focus.requestFocus();
      notify(context, 'Describe what is happening first, then tap SOS.');
      return;
    }
    Sfx.tap();
    final node = ref.read(nodeProvider);
    final device = ref.read(deviceControllerProvider.notifier);
    setState(() => _sending = true);
    LocationFix? fix;
    if (_attachLocation) fix = await device.refreshLocation();
    await node.submitSos(text: _text.text, location: fix, shareOpenlyIfNoKeys: _shareOpenly);
    if (!mounted) return;
    Sfx.send();
    setState(() => _sending = false);
    _text.clear();
    _focus.unfocus();
    notify(context, node.transport.connectedPeers.isEmpty
        ? 'Saved. It will be sent when a nearby phone is in range.'
        : 'Saved and sending to nearby phones.');
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(nodeVersionProvider);
    final node = ref.watch(nodeProvider);
    final device = ref.watch(deviceControllerProvider);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final mine = node.mySos;

    return ResqPage(
      title: 'Get help',
      subtitle: 'Describe what is happening and tap SOS. Your message hops between nearby phones until it reaches help.',
      children: [
          const MeshBar(),
          const SizedBox(height: 24),
          Center(
            child: Semantics(
              button: true,
              label: 'Send SOS',
              child: SizedBox(
                width: 210,
                height: 210,
                child: Stack(alignment: Alignment.center, children: [
                  if (!reduceMotion && !_sending)
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, _) => Container(
                        width: 160 + 50 * _pulse.value,
                        height: 160 + 50 * _pulse.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cs.error.withValues(alpha: 0.18 * (1 - _pulse.value)),
                        ),
                      ),
                    ),
                  Material(
                    color: cs.error,
                    shape: const CircleBorder(),
                    elevation: 3,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _sending ? null : _send,
                      child: SizedBox(
                        width: 160,
                        height: 160,
                        child: Center(
                          child: _sending
                              ? CircularProgressIndicator(color: cs.onError)
                              : Column(mainAxisSize: MainAxisSize.min, children: [
                                  Text('SOS',
                                      style: t.displaySmall?.copyWith(
                                          color: cs.onError, fontWeight: FontWeight.w800, letterSpacing: 2)),
                                  Text('Tap to send', style: t.labelMedium?.copyWith(color: cs.onError)),
                                ]),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _text,
            focusNode: _focus,
            maxLength: Limits.maxSosTextChars,
            maxLines: 4,
            minLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'What is happening?',
              hintText: 'e.g. Need insulin for dad, ground floor flooded',
              helperText: 'Any language. Short and specific helps the right person come.',
            ),
          ),
          if (_preview != null) ...[const SizedBox(height: 4), _TriagePreview(_preview!)],
          const SizedBox(height: 12),
          Card(
            child: Column(children: [
              SwitchListTile(
                value: _attachLocation,
                onChanged: (v) => setState(() => _attachLocation = v),
                secondary: AppIcon(ResqIcons.location, color: cs.onSurfaceVariant),
                title: const Text('Share my location'),
                subtitle: Text(device.lastFix == null
                    ? (device.locationStatus == null
                        ? 'Asked only when you send'
                        : _locationStatusText(device.locationStatus!.name))
                    : 'Last fix ±${device.lastFix!.accuracyM.round()} m · ${ago(device.lastFix!.fixedAtMs, node.nowMs)}'),
              ),
              const Divider(indent: 16, endIndent: 16),
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  leading: AppIcon(_shareOpenly ? ResqIcons.unlock : ResqIcons.lock, color: cs.onSurfaceVariant),
                  title: const Text('Privacy options'),
                  children: [
                    SwitchListTile(
                      value: _shareOpenly,
                      onChanged: (v) => setState(() => _shareOpenly = v),
                      title: const Text('Share details if no verified responder is nearby'),
                      subtitle: Text(_shareOpenly
                          ? 'Details are encrypted when verified responders are known. Otherwise nearby phones can read them.'
                          : 'Without verified responders, only urgency, type of help and a rough area are sent.'),
                    ),
                  ],
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
              leading: AppIcon(ResqIcons.medical, color: cs.tertiary),
              title: const Text('Medical card'),
              subtitle: Text(node.medicalCard == null
                  ? 'Not set up. Add it so whoever comes knows your blood group and medicines.'
                  : 'Ready. Goes only to the volunteer who accepts.'),
              trailing: AppIcon(ResqIcons.chevronRight, size: 20, color: cs.outline),
              onTap: () => openMedicalCard(context),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => showHazardDialog(context, ref),
            icon: AppIcon(ResqIcons.hazard, size: 18, color: cs.primary),
            label: const Text('Report a danger nearby'),
          ),
          SectionHeader('Your requests', trailing: mine.isEmpty ? null : Text('${mine.length}', style: t.labelLarge)),
          if (mine.isEmpty)
            EmptyState(icon: ResqIcons.send, title: 'No requests yet', body: 'Your SOS and its progress will appear here.'),
          for (final m in mine) Padding(padding: const EdgeInsets.only(bottom: 12), child: _RequestCard(m)),
      ],
    );
  }

  static String _locationStatusText(String status) => switch (status) {
        'serviceOff' => 'Location services are off',
        'denied' => 'Location permission denied',
        'deniedForever' => 'Location blocked — enable it in settings',
        'timeout' => 'No location fix yet',
        _ => 'Location unavailable',
      };
}

class _TriagePreview extends StatelessWidget {
  const _TriagePreview(this.result);

  final TriageResult result;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('How RES-Q reads this', style: t.labelLarge),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            SosClassBadge(result.urgency),
            UrgencyChip(result.urgency),
            for (final n in result.needs) StatusChip(needLabel(n), icon: needIcon(n)),
          ]),
          if (result.needsReview) ...[
            const SizedBox(height: 10),
            const InfoRow(ResqIcons.info, 'A person will review this. It is still sent right away.'),
          ],
          if (result.isCapabilityOffer)
            const InfoRow(ResqIcons.lifebuoy, 'This sounds like an offer to help. Use "I can help" in the status menu.'),
          const SizedBox(height: 4),
          Text('Rule-based reading, not a medical diagnosis.', style: t.bodySmall),
        ]),
      ),
    );
  }
}

class _RequestCard extends ConsumerWidget {
  const _RequestCard(this.view);

  final MySosView view;

  static const List<String> _steps = ['Saved', 'Sent', 'Received', 'Accepted', 'On the way', 'On scene'];

  int _reached() {
    final p = view.state.phase;
    if (p == SosPhase.onScene || p == SosPhase.resolved) return 5;
    if (p == SosPhase.enRoute) return 4;
    if (p == SosPhase.accepted) return 3;
    if (view.delivery.acks > 0) return 2;
    if (view.delivery.sentTo > 0) return 1;
    return 0;
  }

  String _headline() {
    final d = view.delivery;
    return switch (view.state.phase) {
      SosPhase.searching => switch (d.stage) {
          DeliveryStage.savedLocally => 'Saved on this phone',
          DeliveryStage.waitingForPeer => 'Waiting for a nearby phone',
          DeliveryStage.sentToPeers => 'Sent to ${d.sentTo} phone${d.sentTo == 1 ? '' : 's'}',
          DeliveryStage.acknowledged => 'Received nearby — looking for a responder',
        },
      SosPhase.accepted => 'A responder accepted',
      SosPhase.enRoute => 'Your responder is on the way',
      SosPhase.onScene => 'Your responder is on scene',
      SosPhase.resolved => 'Resolved',
      SosPhase.cancelled => 'Cancelled',
      SosPhase.expired => 'Expired',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final node = ref.read(nodeProvider);
    final runtime = ref.read(meshRuntimeProvider);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final s = view.sos;
    final ringing = runtime.ringingAccepted.contains(s.id);
    final primary = view.state.primary;
    final who = primary == null ? null : node.responderInfo(primary);
    final closed = view.state.phase == SosPhase.cancelled || view.state.phase == SosPhase.resolved || view.state.phase == SosPhase.expired;
    final reached = _reached();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Flexible(flex: 2, child: SosClassBadge(s.urgency)),
            const SizedBox(width: 8),
            Expanded(child: Text(ago(s.claimedAtMs, node.nowMs), style: t.bodySmall)),
            if (closed) Flexible(child: StatusChip(_headline(), tone: Tone.neutral)),
          ]),
          const SizedBox(height: 12),
          Text(_headline(), style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          if (view.state.phase == SosPhase.accepted)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('They have not confirmed leaving yet.', style: t.bodySmall),
            ),
          if (!closed) ...[const SizedBox(height: 14), _Timeline(steps: _steps, reached: reached)],
          if (primary != null && view.state.isActive) ...[
            const SizedBox(height: 14),
            _WhoIsComing(
              profession: who == null ? 'Volunteer' : professionOf(who.caps),
              name: who?.name ?? '',
              skills: who?.caps.map(capabilityLabel).toList() ?? const [],
              verifiedBy: who?.verifiedBy,
              cardShared: node.medicalCardSentFor(s.id),
            ),
          ],
          if (ringing) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: cs.tertiary, foregroundColor: cs.onTertiary),
              onPressed: () {
                Sfx.success();
                runtime.acknowledgeAccepted(s.id);
              },
              icon: AppIcon(ResqIcons.check, size: 18, color: cs.onTertiary),
              label: const Text('Got it, stop the alarm'),
            ),
          ],
          if (view.state.reopened) ...[
            const SizedBox(height: 12),
            const Callout('Your responder lost contact. RES-Q is looking for someone else.', tone: Tone.warn),
          ],
          if (view.state.conflicts.contains('MULTIPLE_ON_SCENE')) ...[
            const SizedBox(height: 12),
            const Callout('More than one responder reports being on scene.', tone: Tone.info),
          ],
          const SizedBox(height: 12),
          if (s.text != null) Text('"${s.text}"', style: t.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
          const SizedBox(height: 6),
          InfoRow(
            s.sealed ? ResqIcons.lock : (s.readable ? ResqIcons.unlock : ResqIcons.shield),
            s.sealed
                ? 'Details encrypted to ${s.recipientCount} verified responder${s.recipientCount == 1 ? '' : 's'}'
                : (s.readable ? 'Details shared openly (no verified responders known)' : 'Details withheld — only type of help and area sent'),
          ),
          InfoRow(
            s.location == null ? ResqIcons.locationOff : ResqIcons.location,
            s.location == null ? 'No location shared' : 'Location shared (±${s.location!.accuracyM.round()} m)',
          ),
          if (!closed)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () async {
                  if (await confirm(context, 'Cancel this request?', 'Responders will be told you no longer need help.',
                      yes: 'Cancel request', destructive: true)) {
                    Sfx.warn();
                    runtime.acknowledgeAccepted(s.id);
                    await node.cancelSos(s.id);
                  }
                },
                child: const Text('Cancel request'),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Horizontal progress timeline: filled dots for reached steps.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.steps, required this.reached});

  final List<String> steps;
  final int reached;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Column(children: [
      Row(children: [
        for (var i = 0; i < steps.length; i++) ...[
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i <= reached ? cs.primary : cs.surfaceContainerHighest,
              border: Border.all(color: i <= reached ? cs.primary : cs.outlineVariant, width: 2),
            ),
          ),
          if (i < steps.length - 1)
            Expanded(child: Container(height: 2, color: i < reached ? cs.primary : cs.outlineVariant)),
        ],
      ]),
      const SizedBox(height: 6),
      Row(children: [
        for (var i = 0; i < steps.length; i++)
          Expanded(
            child: Text(
              steps[i],
              textAlign: i == 0 ? TextAlign.left : (i == steps.length - 1 ? TextAlign.right : TextAlign.center),
              style: t.labelSmall?.copyWith(
                color: i <= reached ? cs.onSurface : cs.onSurfaceVariant,
                fontWeight: i == reached ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
      ]),
    ]);
  }
}

/// "Who is coming": the accepting volunteer's profession, skills and whether
/// a trusted authority verified them.
class _WhoIsComing extends StatelessWidget {
  const _WhoIsComing({
    required this.profession,
    required this.name,
    required this.skills,
    required this.verifiedBy,
    required this.cardShared,
  });

  final String profession;
  final String name;
  final List<String> skills;
  final String? verifiedBy;
  final bool cardShared;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: cs.primaryContainer.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('WHO IS COMING', style: t.labelSmall?.copyWith(color: cs.onPrimaryContainer, letterSpacing: 1)),
        const SizedBox(height: 6),
        Row(children: [
          AppIcon(verifiedBy != null ? ResqIcons.shieldCheck : ResqIcons.person, size: 22, color: cs.onPrimaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$profession volunteer${name.isEmpty ? '' : ' · $name'}',
              style: t.titleMedium?.copyWith(color: cs.onPrimaryContainer, fontWeight: FontWeight.w700),
            ),
          ),
        ]),
        const SizedBox(height: 4),
        Text(
          verifiedBy != null ? 'Verified by $verifiedBy' : 'Skills are self-declared, not verified by an authority',
          style: t.bodySmall?.copyWith(color: cs.onPrimaryContainer),
        ),
        if (skills.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final k in skills) StatusChip(k, tone: Tone.info)]),
        ],
        if (cardShared) ...[
          const SizedBox(height: 8),
          const InfoRow(ResqIcons.medical, 'Your medical card was sent to them, encrypted.', tone: Tone.good),
        ],
      ]),
    );
  }
}
