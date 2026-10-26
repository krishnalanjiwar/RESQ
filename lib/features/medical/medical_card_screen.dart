import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models.dart';
import '../../ui/icons.dart';
import '../../ui/motion.dart';
import '../shared/page.dart';
import '../shared/widgets.dart';

/// Opens the medical card editor on top of the current page.
Future<void> openMedicalCard(BuildContext context) {
  Sfx.tap();
  return Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MedicalCardScreen()));
}

/// Medical card editor. Saved encrypted on this phone; shared only with the
/// volunteer who accepts the SOS, sealed to them alone.
class MedicalCardScreen extends ConsumerStatefulWidget {
  const MedicalCardScreen({super.key});

  @override
  ConsumerState<MedicalCardScreen> createState() => _MedicalCardScreenState();
}

class _MedicalCardScreenState extends ConsumerState<MedicalCardScreen> {
  late final MedicalCard _initial = ref.read(nodeProvider).medicalCard ?? const MedicalCard();
  late String _blood = _initial.bloodGroup;
  late final _conditions = TextEditingController(text: _initial.conditions);
  late final _allergies = TextEditingController(text: _initial.allergies);
  late final _medications = TextEditingController(text: _initial.medications);
  late final _contactName = TextEditingController(text: _initial.contactName);
  late final _contactPhone = TextEditingController(text: _initial.contactPhone);
  late final _notes = TextEditingController(text: _initial.notes);

  @override
  void dispose() {
    for (final c in [_conditions, _allergies, _medications, _contactName, _contactPhone, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final card = MedicalCard(
      bloodGroup: _blood,
      conditions: _conditions.text.trim(),
      allergies: _allergies.text.trim(),
      medications: _medications.text.trim(),
      contactName: _contactName.text.trim(),
      contactPhone: _contactPhone.text.trim(),
      notes: _notes.text.trim(),
    );
    await ref.read(nodeProvider).setMedicalCard(card);
    Sfx.success();
    if (!mounted) return;
    notify(context, card.isEmpty ? 'Medical card cleared.' : 'Medical card saved.');
    Navigator.of(context).maybePop();
  }

  Widget _field(TextEditingController c, String label, {String? hint, TextInputType? type}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          maxLength: MedicalCard.maxFieldChars,
          keyboardType: type,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: label, hintText: hint, counterText: ''),
        ),
      );

  @override
  Widget build(BuildContext context) => SubPage(
        title: 'Medical card',
        subtitle: 'Helps the person who comes to you act fast. Fill in only what you are comfortable sharing.',
        children: [
          const Callout(
            'Stored encrypted on this phone. When a volunteer accepts your SOS, the card is sent to that '
            'volunteer only, encrypted so phones relaying it cannot read it.',
            tone: Tone.good,
            icon: ResqIcons.lock,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _blood,
            decoration: const InputDecoration(labelText: 'Blood group'),
            items: [
              for (final g in MedicalCard.bloodGroups)
                DropdownMenuItem(value: g, child: Text(g.isEmpty ? 'Not set' : g)),
            ],
            onChanged: (v) => setState(() => _blood = v ?? ''),
          ),
          const SizedBox(height: 12),
          _field(_conditions, 'Medical conditions', hint: 'e.g. diabetes, asthma, heart condition'),
          _field(_allergies, 'Allergies', hint: 'e.g. penicillin, peanuts'),
          _field(_medications, 'Regular medicines', hint: 'e.g. insulin twice a day'),
          _field(_contactName, 'Emergency contact name'),
          _field(_contactPhone, 'Emergency contact phone', type: TextInputType.phone),
          _field(_notes, 'Anything else', hint: 'e.g. uses a wheelchair, hearing impaired'),
          const SizedBox(height: 4),
          FilledButton.icon(
            onPressed: _save,
            icon: const AppIcon(ResqIcons.check, size: 18, color: Colors.white),
            label: const Text('Save medical card'),
          ),
        ],
      );
}

/// Read-only view of a requester's medical card, for the responder.
class MedicalCardView extends StatelessWidget {
  const MedicalCardView(this.card, {super.key});

  final MedicalCard card;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    Widget row(String label, String value) => value.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 118, child: Text(label, style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant))),
              Expanded(child: Text(value, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
            ]),
          );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          AppIcon(ResqIcons.medical, size: 18, color: cs.onTertiaryContainer),
          const SizedBox(width: 8),
          Expanded(child: Text('Medical card', style: t.titleSmall?.copyWith(color: cs.onTertiaryContainer))),
          if (card.bloodGroup.isNotEmpty) StatusChip('Blood ${card.bloodGroup}', tone: Tone.danger),
        ]),
        row('Conditions', card.conditions),
        row('Allergies', card.allergies),
        row('Medicines', card.medications),
        row('Contact', [card.contactName, card.contactPhone].where((s) => s.isNotEmpty).join(' · ')),
        row('Notes', card.notes),
        const SizedBox(height: 6),
        Text('Shared with you only. Not a diagnosis.', style: t.bodySmall?.copyWith(color: cs.onTertiaryContainer)),
      ]),
    );
  }
}
