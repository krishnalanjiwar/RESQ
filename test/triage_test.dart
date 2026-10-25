import 'package:flutter_test/flutter_test.dart';
import 'package:resq/domain/models.dart';
import 'package:resq/domain/triage/capability_parser.dart';
import 'package:resq/domain/triage/triage_agent.dart';

void main() {
  const triage = TriageAgent();

  group('TriageAgent (table-driven, PRD §6.4)', () {
    final cases = <(String, Urgency, Set<Need>, bool)>[
      // text, expected urgency, required needs (subset), needsReview
      ('Need insulin for dad, ground floor flooded', Urgency.critical, {Need.medical, Need.waterRescue}, false),
      ('Need insulin urgently.', Urgency.critical, {Need.medical}, false),
      ('Dad needs dialysis and flood water is rising.', Urgency.critical, {Need.medical, Need.waterRescue}, false),
      ('Pani aa raha hai, bachao.', Urgency.high, {Need.waterRescue}, false),
      ('trapped under debris, leg injured', Urgency.critical, {Need.trapped, Need.medical}, false),
      ('need food and drinking water for 4 kids', Urgency.high, {Need.supplies}, false),
      ('Please help.', Urgency.unknown, <Need>{}, true),
      ('', Urgency.unknown, <Need>{}, true),
      ('   ', Urgency.unknown, <Need>{}, true),
      ('I do not need insulin now.', Urgency.unknown, <Need>{}, true),
      ('बचाओ पानी', Urgency.high, {Need.waterRescue}, false),
      ('unconsious man not breathing', Urgency.critical, {Need.medical}, false),
    ];
    for (final (text, urgency, needs, review) in cases) {
      test('"$text"', () {
        final r = triage.analyze(text);
        expect(r.urgency, urgency, reason: r.justification);
        expect(r.needs.containsAll(needs), isTrue, reason: 'needs ${r.needs}');
        expect(r.needsReview, review, reason: r.ruleIds.join(','));
      });
    }

    test('unknown input is never LOW', () {
      for (final t in ['help', 'asdkjh qwe', 'please', 'emergency']) {
        expect(triage.analyze(t).urgency, isNot(Urgency.low), reason: t);
      }
    });

    test('capability offers are flagged, not treated as SOS', () {
      final r = triage.analyze('Boat available; can help with rescue.');
      expect(r.isCapabilityOffer, isTrue);
      expect(r.needsReview, isTrue);
    });

    test('negation produces review, not silent downgrade', () {
      final r = triage.analyze('Heart disease history, no current emergency.');
      expect(r.needsReview, isTrue);
    });

    test('bounded input: very long text is processed in bounded time', () {
      final long = 'flood ' * 5000;
      final sw = Stopwatch()..start();
      final r = triage.analyze(long);
      sw.stop();
      expect(r.needs, contains(Need.waterRescue));
      expect(sw.elapsedMilliseconds, lessThan(500));
    });

    test('legacy facade maps from the typed result', () {
      final m = triage.analyzeLegacy('Need insulin urgently.');
      expect(m['urgency'], 'CRITICAL');
      expect(m['need'], contains('MEDICAL'));
    });

    test('deterministic', () {
      const t = 'Budhe dada chhat par hain, pani bhar gaya';
      expect(triage.analyze(t).toLegacyMap(), triage.analyze(t).toLegacyMap());
    });
  });

  group('CapabilityParser (zero-shot, code-mixed)', () {
    const parser = CapabilityParser();
    final cases = <(String, Set<Capability>)>[
      ('has a boat', {Capability.boat}),
      ('can do dialysis', {Capability.medicalAdvanced}),
      ('boat hai, tairna aata hai', {Capability.boat, Capability.swimmer}),
      ('doctor hoon', {Capability.medicalAdvanced}),
      ('tractor hai, strong', {Capability.vehicle, Capability.carry}),
      ('first aid aata hai', {Capability.medicalBasic}),
      ('firefighter with ladder', {Capability.fire, Capability.searchRescue}),
    ];
    for (final (text, caps) in cases) {
      test('"$text"', () => expect(parser.parse(text).capabilities.containsAll(caps), isTrue));
    }

    test('unrecognised text becomes GENERAL HELP for human review', () {
      final r = parser.parse('i operate a drone with thermal camera');
      expect(r.unrecognized, isTrue);
      expect(r.capabilities, {Capability.general});
    });
  });
}
