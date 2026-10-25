import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../domain/models.dart';
import '../../domain/reconcile/reconciler.dart';
import '../../domain/triage/triage_agent.dart';
import '../../node/views.dart';
import '../../protocol/limits.dart';
import '../shared/hazard_dialog.dart';
import '../shared/mesh_bar.dart';
import '../shared/status_drawer.dart';
import '../shared/widgets.dart';

class VictimScreen extends ConsumerStatefulWidget {
  const VictimScreen({super.key});

  @override
  ConsumerState<VictimScreen> createState() => _VictimScreenState();
}

class _VictimScreenState extends ConsumerState<VictimScreen> with SingleTickerProviderStateMixin {
  final _text = TextEditingController();
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
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
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final node = ref.read(nodeProvider);
    final device = ref.read(deviceControllerProvider.notifier);
    setState(() => _sending = true);
    LocationFix? fix;
    if (_attachLocation) fix = await device.refreshLocation();
    await node.submitSos(text: _text.text, location: fix, shareOpenlyIfNoKeys: _shareOpenly);
    if (!mounted) return;
    setState(() => _sending = false);
    _text.clear();
    notify(context, node.transport.connectedPeers.isEmpty
        ? 'SAVED LOCALLY — WAITING FOR A NEARBY PEER'
        : 'SAVED LOCALLY — SENDING TO CONNECTED PEERS');
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(nodeVersionProvider);
    final node = ref.watch(nodeProvider);
    final device = ref.watch(deviceControllerProvider);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final mine = node.mySos;
    final canSend = _text.text.trim().isNotEmpty && !_sending;

    return Scaffold(
      appBar: AppBar(title: const Text('VICTIM · SOS')),
      endDrawer: const StatusDrawer(),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const MeshBar(),
          const SizedBox(height: 20),
          Center(
            child: Semantics(
              label: 'SOS beacon',
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (_, child) => Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: ResqTheme.white, width: 2 + (reduceMotion ? 0 : 6 * _pulse.value)),
                  ),
                  alignment: Alignment.center,
                  child: child,
                ),
                child: const Text('SOS', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _text,
            maxLength: Limits.maxSosTextChars,
            maxLines: 4,
            minLines: 2,
            decoration: const InputDecoration(
              labelText: 'WHAT IS HAPPENING? (any language)',
              hintText: 'e.g. Need insulin for dad, ground floor flooded',
            ),
          ),
          if (_preview != null) _TriagePreview(_preview!),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _attachLocation,
            onChanged: (v) => setState(() => _attachLocation = v),
            title: const Text('ATTACH MY LOCATION', style: TextStyle(fontSize: 13)),
            subtitle: Text(
              device.lastFix == null
                  ? (device.locationStatus?.label ?? 'Location is optional. Asked only when you send.')
                  : 'LAST FIX ±${device.lastFix!.accuracyM.round()} m · ${ago(device.lastFix!.fixedAtMs, node.nowMs)}',
              style: const TextStyle(fontSize: 11),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _shareOpenly,
            onChanged: (v) => setState(() => _shareOpenly = v),
            title: const Text('IF NO VERIFIED RESPONDER IS KNOWN: SHARE DETAILS OPENLY', style: TextStyle(fontSize: 13)),
            subtitle: Text(
              _shareOpenly
                  ? 'Details are encrypted when verified responder keys are known; otherwise relays can read them.'
                  : 'Without verified responder keys, only urgency, need type and ~5 km area are sent.',
              style: const TextStyle(fontSize: 11),
            ),
          ),
          const SizedBox(height: 8),
          ActionButton(_sending ? 'SAVING…' : 'SEND SOS', primary: true, onPressed: canSend ? _send : null),
          const SizedBox(height: 8),
          ActionButton('REPORT HAZARD', dense: true, onPressed: () => showHazardDialog(context, ref)),
          SectionTitle('MY REQUESTS (${mine.length})'),
          if (mine.isEmpty) const Text('No requests sent from this phone.', style: TextStyle(fontSize: 12)),
          for (final m in mine) _MySosCard(m),
        ]),
      ),
    );
  }
}

class _TriagePreview extends StatelessWidget {
  const _TriagePreview(this.result);

  final TriageResult result;

  @override
  Widget build(BuildContext context) => Boxed(
        padding: const EdgeInsets.all(8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            'RULE-BASED READING: ${result.urgency.label}'
            '${result.needs.isEmpty ? '' : ' · ${result.needs.map((n) => n.label).join(' + ')}'}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          if (result.needsReview) const Text('NEEDS HUMAN REVIEW — will still be sent', style: TextStyle(fontSize: 11)),
          if (result.isCapabilityOffer)
            const Text('This reads like an offer to help. Responders: use the RESPONDER role.', style: TextStyle(fontSize: 11)),
          Text(result.justification, style: const TextStyle(fontSize: 10)),
        ]),
      );
}

class _MySosCard extends ConsumerWidget {
  const _MySosCard(this.view);

  final MySosView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final node = ref.read(nodeProvider);
    final s = view.sos;
    final privacy = s.sealed
        ? 'DETAILS ENCRYPTED TO ${s.recipientCount} VERIFIED RESPONDER(S)'
        : (s.readable ? 'DETAILS SHARED OPENLY (no verified responder keys known)' : 'DETAILS WITHHELD — coarse info only');
    final closed = view.state.phase == SosPhase.cancelled || view.state.phase == SosPhase.resolved;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Boxed(
        thick: view.state.isActive,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(view.headline, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 6),
          KeyValue('TRIAGE', '${s.urgency.label}${s.needs.isEmpty ? '' : ' · ${s.needs.map((n) => n.label).join(' + ')}'}'),
          KeyValue('SENT', '${ago(s.claimedAtMs, node.nowMs)} · to ${view.delivery.sentTo} peer(s) · ${view.delivery.acks} ack(s)'),
          KeyValue('PRIVACY', privacy),
          if (s.location != null) KeyValue('LOCATION', '±${s.location!.accuracyM.round()} m') else const KeyValue('LOCATION', 'LOCATION NOT PROVIDED'),
          if (view.state.phase == SosPhase.accepted)
            const KeyValue('NOTE', 'Acceptance does not mean the responder has left or arrived.'),
          if (s.text != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('"${s.text}"', style: const TextStyle(fontSize: 12))),
          if (!closed) ...[
            const SizedBox(height: 8),
            ActionButton('CANCEL REQUEST', dense: true, onPressed: () async {
              if (await confirm(context, 'CANCEL THIS REQUEST?', 'Responders will be told you no longer need help.')) {
                await node.cancelSos(s.id);
              }
            }),
          ],
        ]),
      ),
    );
  }
}
