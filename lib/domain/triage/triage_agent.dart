import '../models.dart';
import 'text_match.dart';

/// Structured triage outcome. A recommendation from transparent rules, not a diagnosis.
class TriageResult {
  const TriageResult({
    required this.urgency,
    required this.needs,
    required this.ruleIds,
    required this.evidence,
    required this.needsReview,
    required this.isCapabilityOffer,
    required this.justification,
  });

  final Urgency urgency;
  final Set<Need> needs;
  final List<String> ruleIds;

  /// Matched phrases, for the plain-language explanation.
  final List<String> evidence;
  final bool needsReview;
  final bool isCapabilityOffer;
  final String justification;

  static const String rulesetVersion = 'triage-2026.10.1';

  /// Compatibility facade from the original brief: `{urgency, need, justification}`.
  Map<String, String> toLegacyMap() => {
        'urgency': urgency.label,
        'need': needs.isEmpty ? 'UNKNOWN' : needs.map((n) => n.label).join('+'),
        'justification': justification,
        'needsReview': needsReview.toString(),
      };
}

enum _Signal { critical, high, low, distress, urgencyWord, vulnerable, offer, supplies }

class _Rule {
  const _Rule(this.id, this.signal, this.need, this.phrases);

  final String id;
  final _Signal signal;
  final Need? need;
  final List<String> phrases;
}

/// Pure-Dart deterministic triage (FR-012). Rules run in a fixed order; more
/// specific phrases consume their tokens first so "drinking water" is not read
/// as a flood.
class TriageAgent {
  const TriageAgent();

  static const List<_Rule> _rules = [
    // Specific phrases first (they consume tokens).
    _Rule('SUP_DRINKING_WATER', _Signal.supplies, Need.supplies,
        ['drinking water', 'peene ka pani', 'pine ka pani', 'pani peena', 'peene ke liye pani', 'पीने का पानी']),
    _Rule('OFFER_CAPABILITY', _Signal.offer, null, [
      'i have a boat', 'have a boat', 'boat available', 'boat hai', 'naav hai', 'i can help', 'can help',
      'available to help', 'i am available', 'volunteer', 'madad kar sakta', 'madad kar sakti', 'help kar sakta',
      'i can rescue', 'can do dialysis', 'i am a doctor', 'i am a nurse', 'doctor hoon', 'nurse hoon',
    ]),
    _Rule('CRIT_BREATHING', _Signal.critical, Need.medical, [
      'not breathing', 'cant breathe', 'cant breath', 'difficulty breathing', 'breathless', 'saans nahi',
      'saans nahi aa rahi', 'saans lene mein dikkat', 'सांस नहीं', 'oxygen',
    ]),
    _Rule('CRIT_UNCONSCIOUS', _Signal.critical, Need.medical,
        ['unconscious', 'not responding', 'fainted', 'behosh', 'बेहोश', 'seizure', 'fits', 'stroke']),
    _Rule('CRIT_BLEEDING', _Signal.critical, Need.medical,
        ['heavy bleeding', 'bleeding badly', 'blood loss', 'lot of blood', 'bahut khoon', 'khoon beh raha', 'खून बह']),
    _Rule('CRIT_CARDIAC', _Signal.critical, Need.medical,
        ['heart attack', 'chest pain', 'dil ka daura', 'cardiac']),
    _Rule('CRIT_MEDICATION', _Signal.critical, Need.medical,
        ['insulin', 'dialysis', 'इंसुलिन', 'डायलिसिस', 'overdose', 'poison', 'snake bite', 'saanp ne kata']),
    _Rule('CRIT_LABOUR', _Signal.critical, Need.medical,
        ['labour pain', 'labor pain', 'in labour', 'in labor', 'delivery pain', 'water broke']),
    _Rule('CRIT_DROWNING', _Signal.critical, Need.waterRescue, [
      'drowning', 'doob raha', 'doob rahi', 'dub raha', 'swept away', 'bah gaya', 'neck deep', 'chest deep',
      'on the roof', 'on roof', 'chhat par', 'डूब',
    ]),
    _Rule('CRIT_FIRE_TRAPPED', _Signal.critical, Need.fire,
        ['trapped in fire', 'fire spreading', 'house on fire', 'aag lagi', 'aag lag gayi', 'आग लगी']),
    _Rule('CRIT_BURIED', _Signal.critical, Need.trapped,
        ['trapped under', 'buried', 'crushed', 'under debris', 'malbe mein', 'dab gaye', 'dabe hue', 'मलबे']),
    _Rule('HIGH_MEDICAL', _Signal.high, Need.medical, [
      'injured', 'injury', 'hurt', 'wound', 'wounded', 'fracture', 'broken leg', 'broken arm', 'burns', 'burnt',
      'bleeding', 'blood', 'fever', 'medicine', 'medicines', 'dawai', 'doctor', 'pregnant', 'sick', 'diabetic',
      'chot', 'ghayal', 'bimar', 'beemar', 'चोट', 'घायल', 'बीमार', 'दवा', 'heart', 'pain', 'vomiting',
    ]),
    _Rule('HIGH_WATER', _Signal.high, Need.waterRescue, [
      'flood', 'flooded', 'flooding', 'floods', 'water rising', 'water entering', 'ground floor', 'submerged',
      'stranded', 'boat', 'baadh', 'badh', 'pani bhar', 'pani aa raha', 'water', 'pani', 'पानी', 'बाढ़', 'naav',
    ]),
    _Rule('HIGH_FIRE', _Signal.high, Need.fire,
        ['fire', 'smoke', 'aag', 'dhuan', 'burning', 'gas leak', 'explosion', 'आग', 'धुआं']),
    _Rule('HIGH_TRAPPED', _Signal.high, Need.trapped, [
      'trapped', 'stuck', 'collapsed', 'collapse', 'debris', 'phasa', 'fasa', 'phase hue', 'fase', 'phanse',
      'cant get out', 'locked in', 'फंसे', 'मलबा',
    ]),
    _Rule('VULNERABLE', _Signal.vulnerable, Need.evacuation, [
      'elderly', 'old man', 'old woman', 'old lady', 'grandmother', 'grandfather', 'dadi', 'nani', 'dada', 'nana',
      'wheelchair', 'bedridden', 'disabled', 'baby', 'infant', 'newborn', 'child', 'children', 'kids', 'bachcha',
      'bacche', 'bachche', 'budhe', 'buzurg', 'बच्चा', 'बच्चे', 'बुजुर्ग',
    ]),
    _Rule('LOW_SUPPLIES', _Signal.supplies, Need.supplies, [
      'food', 'khana', 'hungry', 'milk', 'doodh', 'blanket', 'blankets', 'clothes', 'ration', 'baby formula',
      'torch', 'charger', 'खाना',
    ]),
    _Rule('LOW_SHELTER', _Signal.low, Need.shelter,
        ['shelter', 'place to stay', 'homeless', 'house destroyed', 'ghar toot', 'rehne ki jagah']),
    _Rule('URGENCY_WORD', _Signal.urgencyWord, null,
        ['urgent', 'urgently', 'emergency', 'immediately', 'asap', 'jaldi', 'turant', 'critical', 'serious']),
    _Rule('DISTRESS', _Signal.distress, null,
        ['help', 'madad', 'bachao', 'bacho', 'save', 'sos', 'please', 'बचाओ', 'मदद']),
  ];

  TriageResult analyze(String text) {
    final tokens = tokenize(text);
    if (tokens.isEmpty) {
      return const TriageResult(
        urgency: Urgency.unknown,
        needs: {},
        ruleIds: ['EMPTY_INPUT'],
        evidence: [],
        needsReview: true,
        isCapabilityOffer: false,
        justification: 'No description given. Needs human review.',
      );
    }

    final consumed = <int>{};
    final hits = <(_Rule, PhraseHit)>[];
    for (final rule in _rules) {
      for (final hit in findPhrases(tokens, rule.id, rule.phrases, consumed)) {
        hits.add((rule, hit));
      }
    }

    final active = hits.where((h) => !h.$2.negated).toList();
    final negatedCount = hits.length - active.length;
    final signals = active.map((h) => h.$1.signal).toSet();
    final needs = <Need>{for (final h in active) ?h.$1.need};
    final ruleIds = <String>{for (final h in active) h.$1.id};
    final evidence = [for (final h in active) h.$2.phrase];

    final isOffer = signals.contains(_Signal.offer);
    var urgency = Urgency.unknown;
    var review = false;

    if (signals.contains(_Signal.critical)) {
      urgency = Urgency.critical;
    } else if (signals.contains(_Signal.high)) {
      urgency = Urgency.high;
    } else if (signals.contains(_Signal.vulnerable)) {
      urgency = Urgency.high;
    } else if (signals.contains(_Signal.supplies) || signals.contains(_Signal.low)) {
      urgency = Urgency.low;
    }

    // Combinations that raise urgency.
    final trapped = needs.contains(Need.trapped);
    final water = needs.contains(Need.waterRescue);
    final medical = needs.contains(Need.medical);
    if (urgency != Urgency.critical && trapped && (water || medical || needs.contains(Need.fire))) {
      urgency = Urgency.critical;
      ruleIds.add('COMBO_TRAPPED_AT_RISK');
    }
    if (urgency != Urgency.critical && water && signals.contains(_Signal.vulnerable)) {
      urgency = Urgency.critical;
      ruleIds.add('COMBO_VULNERABLE_IN_WATER');
    }
    if (urgency == Urgency.low && signals.contains(_Signal.urgencyWord)) {
      urgency = Urgency.high;
      ruleIds.add('URGENCY_WORD_RAISE');
    }

    if (needs.isEmpty && !isOffer) {
      // Distress words alone ("please help", "bachao") are real SOS signals with
      // unknown need: never LOW, always human review.
      urgency = Urgency.unknown;
      review = true;
      ruleIds.add(signals.contains(_Signal.distress) ? 'DISTRESS_UNSPECIFIED' : 'NO_RULE_MATCHED');
    }
    if (negatedCount > 0) {
      review = true;
      ruleIds.add('NEGATION_PRESENT');
      if (needs.isEmpty) urgency = Urgency.unknown;
    }
    if (isOffer) {
      review = true;
      if (!signals.contains(_Signal.critical) && !signals.contains(_Signal.distress)) {
        urgency = Urgency.unknown;
      }
    }

    return TriageResult(
      urgency: urgency,
      needs: needs,
      ruleIds: ruleIds.toList(),
      evidence: evidence,
      needsReview: review,
      isCapabilityOffer: isOffer,
      justification: _justify(urgency, needs, evidence, review, isOffer, negatedCount > 0),
    );
  }

  /// The original brief's API, kept as a facade over [analyze].
  Map<String, String> analyzeLegacy(String text) => analyze(text).toLegacyMap();

  static String _justify(Urgency u, Set<Need> needs, List<String> evidence, bool review, bool offer, bool negation) {
    final parts = <String>[u.label];
    if (needs.isNotEmpty) parts.add(needs.map((n) => n.label).join(' + '));
    if (evidence.isNotEmpty) parts.add('matched: ${evidence.take(5).join(', ')}');
    if (offer) parts.add('reads like an offer of help');
    if (negation) parts.add('contains negation');
    if (review) parts.add('NEEDS HUMAN REVIEW');
    return '${parts.join(' · ')}. Rule-based recommendation, not a diagnosis.';
  }
}
