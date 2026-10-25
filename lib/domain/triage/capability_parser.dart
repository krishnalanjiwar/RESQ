import '../models.dart';
import 'text_match.dart';

class CapabilityParse {
  const CapabilityParse(this.capabilities, this.evidence, {required this.unrecognized});

  final Set<Capability> capabilities;
  final List<String> evidence;

  /// True when the text named something we have no rule for. It's kept as
  /// GENERAL HELP and shown for human judgement, not discarded.
  final bool unrecognized;
}

/// Parses open-vocabulary, code-mixed capability claims ("has a boat",
/// "can do dialysis", "tairna aata hai") into the capability ontology.
/// Parsed capabilities are self-declared claims until backed by a credential.
class CapabilityParser {
  const CapabilityParser();

  static const Map<Capability, List<String>> _lexicon = {
    Capability.medicalAdvanced: [
      'doctor', 'nurse', 'paramedic', 'emt', 'surgeon', 'mbbs', 'physician', 'dialysis', 'can do dialysis',
      'insulin', 'icu', 'midwife', 'pharmacist', 'daktar', 'doctor hoon', 'nurse hoon', 'डॉक्टर', 'नर्स',
    ],
    Capability.medicalBasic: [
      'first aid', 'cpr', 'medical kit', 'bandage', 'first aid aata', 'red cross', 'nursing student',
      'medical student', 'प्राथमिक चिकित्सा',
    ],
    Capability.boat: [
      'boat', 'has a boat', 'boat hai', 'naav', 'nav hai', 'kayak', 'raft', 'dinghy', 'canoe', 'fishing boat',
      'motor boat', 'नाव',
    ],
    Capability.waterRescue: ['water rescue', 'lifeguard', 'diver', 'flood rescue', 'rescue swimmer', 'ndrf'],
    Capability.swimmer: ['swim', 'swimmer', 'swimming', 'tairna', 'tairna aata', 'tair sakta', 'तैरना'],
    Capability.fire: ['firefighter', 'fire fighter', 'fireman', 'fire brigade', 'fire extinguisher', 'damkal'],
    Capability.searchRescue: [
      'search and rescue', 'rescue', 'climber', 'rope', 'ropes', 'ladder', 'civil defence', 'civil defense',
      'army', 'police', 'jawan', 'sdrf', 'excavator', 'jcb',
    ],
    Capability.vehicle: [
      'car', 'jeep', 'truck', 'tractor', 'van', 'bike', 'motorcycle', 'ambulance', 'auto', 'rickshaw', 'gaadi',
      'gadi', 'gaadi hai', 'bus', 'suv', 'गाड़ी',
    ],
    Capability.carry: ['strong', 'can lift', 'stretcher', 'carry', 'utha sakta', 'labour', 'porter'],
    Capability.supplies: [
      'food', 'water bottles', 'drinking water', 'ration', 'medicines', 'blankets', 'clothes', 'generator',
      'power bank', 'khana', 'dawai', 'supplies',
    ],
    Capability.shelter: ['shelter', 'spare room', 'house', 'space for', 'jagah hai', 'rehne ki jagah', 'school building'],
  };

  CapabilityParse parse(String text) {
    final tokens = tokenize(text);
    if (tokens.isEmpty) return const CapabilityParse({}, [], unrecognized: false);
    final consumed = <int>{};
    final caps = <Capability>{};
    final evidence = <String>[];
    // Longest phrases across all capabilities first, so "first aid" beats "aid".
    final entries = [
      for (final e in _lexicon.entries)
        for (final p in e.value) (e.key, p),
    ]..sort((a, b) => b.$2.split(' ').length.compareTo(a.$2.split(' ').length));
    for (final (cap, phrase) in entries) {
      for (final hit in findPhrases(tokens, cap.name, [phrase], consumed)) {
        if (hit.negated) continue;
        caps.add(cap);
        evidence.add(hit.phrase);
      }
    }
    final contentTokens = tokens.where((t) => t.length > 3).length;
    final unrecognized = caps.isEmpty && contentTokens > 0;
    if (unrecognized) caps.add(Capability.general);
    return CapabilityParse(caps, evidence, unrecognized: unrecognized);
  }
}
