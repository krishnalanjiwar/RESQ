/// Deterministic, bounded text normalisation and phrase matching used by the
/// triage and capability parsers. No ML, no network, no unbounded work.
library;

const int maxParseChars = 600;

final RegExp _punct = RegExp(r'''[.,!?;:"'()\[\]{}<>/\\|@#$%^&*+=~`_\-–—…।]+''');
final RegExp _spaces = RegExp(r'\s+');

const Map<String, String> _variants = {
  "can't": 'cant',
  'cannot': 'cant',
  "don't": 'dont',
  "isn't": 'isnt',
  "i'm": 'im',
  'pls': 'please',
  'plz': 'please',
  'paani': 'pani',
  'nahin': 'nahi',
  'nhi': 'nahi',
  'bachaao': 'bachao',
  'bachalo': 'bachao',
  'davai': 'dawai',
  'dawa': 'dawai',
};

/// Lowercases, strips punctuation, collapses whitespace, applies spelling variants.
List<String> tokenize(String raw) {
  var text = raw.length > maxParseChars ? raw.substring(0, maxParseChars) : raw;
  text = text.toLowerCase();
  for (final e in _variants.entries.where((e) => e.key.contains("'"))) {
    text = text.replaceAll(e.key, e.value);
  }
  text = text.replaceAll(_punct, ' ').replaceAll(_spaces, ' ').trim();
  if (text.isEmpty) return const [];
  return text.split(' ').map((t) => _variants[t] ?? t).toList(growable: false);
}

/// Levenshtein distance with an early-exit [bound]; returns bound+1 when exceeded.
int boundedEditDistance(String a, String b, int bound) {
  if ((a.length - b.length).abs() > bound) return bound + 1;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0);
    cur[0] = i;
    var rowMin = cur[0];
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      cur[j] = [prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost].reduce((x, y) => x < y ? x : y);
      if (cur[j] < rowMin) rowMin = cur[j];
    }
    if (rowMin > bound) return bound + 1;
    prev = cur;
  }
  return prev[b.length];
}

bool _isLatin(String s) => s.codeUnits.every((c) => c < 128);

/// Token equality with typo tolerance for longer Latin-script words.
bool tokenMatches(String token, String term, {bool fuzzy = true}) {
  if (token == term) return true;
  // Short words are matched exactly: "water"~"later" or "heart"~"heard" would be false alarms.
  if (!fuzzy || !_isLatin(term) || term.length < 6) return false;
  final bound = term.length >= 9 ? 2 : 1;
  return boundedEditDistance(token, term, bound) <= bound;
}

class PhraseHit {
  const PhraseHit(this.ruleId, this.phrase, this.start, this.length, {this.negated = false});

  final String ruleId;
  final String phrase;
  final int start;
  final int length;
  final bool negated;
}

const Set<String> negationWords = {'no', 'not', 'dont', 'never', 'without', 'nahi', 'na', 'isnt', 'nobody', 'none'};

/// Finds every occurrence of [phrases] in [tokens] that doesn't overlap a
/// [consumed] position. Matched positions are added to [consumed].
List<PhraseHit> findPhrases(
  List<String> tokens,
  String ruleId,
  List<String> phrases,
  Set<int> consumed, {
  bool fuzzy = true,
}) {
  final hits = <PhraseHit>[];
  final split = phrases.map((p) => p.split(' ')).toList()..sort((a, b) => b.length.compareTo(a.length));
  for (final parts in split) {
    for (var i = 0; i + parts.length <= tokens.length; i++) {
      var ok = true;
      for (var k = 0; k < parts.length; k++) {
        if (consumed.contains(i + k) ||
            !tokenMatches(tokens[i + k], parts[k], fuzzy: fuzzy && parts.length == 1)) {
          ok = false;
          break;
        }
      }
      if (!ok) continue;
      final negated = _negatedAt(tokens, i);
      for (var k = 0; k < parts.length; k++) {
        consumed.add(i + k);
      }
      hits.add(PhraseHit(ruleId, parts.join(' '), i, parts.length, negated: negated));
    }
  }
  return hits;
}

/// Negation within the two preceding tokens, or Hindi post-position "nahi"
/// right after the phrase (e.g. "saans nahi" is handled by explicit phrases).
bool _negatedAt(List<String> tokens, int start) {
  for (var j = start - 1; j >= 0 && j >= start - 2; j--) {
    if (negationWords.contains(tokens[j])) return true;
  }
  return false;
}
