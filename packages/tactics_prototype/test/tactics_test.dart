import 'dart:io';
import 'dart:math';

import 'package:tactics_prototype/tactics_prototype.dart';
import 'package:test/test.dart';

/// FAZ 5 — Taktik prototipi testleri.
void main() {
  const k = TacticRules.balanced;

  // ==================================================================
  // İZOLASYON: prototip gerçek oyuna BAĞLI DEĞİL
  // ==================================================================
  group('İzolasyon (MD: "maç kurallarına doğrudan koyma")', () {
    test('Flutter uygulaması bu paketi KULLANMIYOR', () {
      final pubspec = File('../../pubspec.yaml').readAsStringSync();
      expect(pubspec, isNot(contains('tactics_prototype')));
    });

    test('Dart sunucusu bu paketi KULLANMIYOR', () {
      final pubspec = File('../../server/pubspec.yaml').readAsStringSync();
      expect(pubspec, isNot(contains('tactics_prototype')));
    });

    test('veritabanında taktik ya da enerji alanı YOK', () {
      final migrations = Directory('../../database/migrations')
          .listSync()
          .whereType<File>()
          .map((f) => f.readAsStringSync().toLowerCase())
          .join('\n');
      expect(migrations, isNot(contains('tactic')));
      expect(migrations, isNot(contains('energy')));
    });
  });

  // ==================================================================
  // TAŞ - KÂĞIT - MAKAS
  // ==================================================================
  group('Taktik etkileşimleri', () {
    test('her taktiğin kırdığı ve kırıldığı bir taktik var (döngü)', () {
      for (final t in [Tactic.highPress, Tactic.counterAttack, Tactic.defensiveWall]) {
        expect(t.beats, isNotNull);
        expect(t.beatenBy, isNotNull);
        expect(t.beats!.beatenBy, t, reason: 'Döngü tutarlı olmalı');
        expect(t.beats, isNot(t.beatenBy));
      }
    });

    test('karşı taktik bonusu SIFIRLAR', () {
      // Pres, kontraya yakalanınca
      expect(k.bonus(Tactic.highPress, Tactic.counterAttack, iAmLead: true), 0);
      // Duvar, presle kırılınca
      expect(k.bonus(Tactic.defensiveWall, Tactic.highPress, iAmLead: false), 0);
      // Kontra, duvara çarpınca
      expect(k.bonus(Tactic.counterAttack, Tactic.defensiveWall, iAmLead: true), 0);
    });

    test('kontra, pres yapan rakibi CEZALANDIRIR', () {
      expect(
        k.bonus(Tactic.counterAttack, Tactic.highPress, iAmLead: false),
        greaterThan(k.pressBonus),
        reason: 'Yakalanan pres, rakibe pres bonusundan fazlasını vermeli',
      );
    });

    test('duvar SADECE savunurken güçlü', () {
      final savunma = k.bonus(Tactic.defensiveWall, Tactic.none, iAmLead: false);
      final hucum = k.bonus(Tactic.defensiveWall, Tactic.none, iAmLead: true);
      expect(savunma, greaterThan(hucum));
    });

    test('kontra tek başına zayıf', () {
      expect(
        k.bonus(Tactic.counterAttack, Tactic.none, iAmLead: true),
        lessThan(k.pressBonus),
      );
    });

    test('hiçbir taktik HER durumda pozitif değil (MD bölüm 7)', () {
      for (final t in [Tactic.highPress, Tactic.counterAttack, Tactic.defensiveWall]) {
        final hepsiPozitif = Tactic.values.every((o) =>
            k.bonus(t, o, iAmLead: true) > 0 &&
            k.bonus(t, o, iAmLead: false) > 0);
        expect(hepsiPozitif, isFalse, reason: '${t.label} hep pozitif olmamalı');
      }
    });

    test('pres en pahalı, duvar en ucuz', () {
      expect(k.pressCost, greaterThan(k.counterCost));
      expect(k.counterCost, greaterThan(k.wallCost));
      expect(k.costOf(Tactic.none), 0);
    });
  });

  // ==================================================================
  // TEMEL KURALLAR KORUNUYOR
  // ==================================================================
  group('Temel kurallar', () {
    const legend = SimCard('MID', 93, isLegend: true);
    const guclu = SimCard('MID', 98);

    test('LEGEND KURALI: hiçbir taktik Legend olmayan kartın Legend\'ı '
        'yenmesini sağlayamaz', () {
      // Abartılı bonuslarla bile
      const asiri = TacticRules(
        startEnergy: 9, energyPerRound: 9, maxEnergy: 99,
        pressCost: 0, counterCost: 0, wallCost: 0,
        pressBonus: 500, counterBaseBonus: 500, counterVsPressBonus: 500,
        wallDefendBonus: 500, wallLeadBonus: 500,
      );
      for (final a in Tactic.values) {
        for (final b in Tactic.values) {
          expect(
            resolveRound(lead: legend, response: guclu, leadTactic: b,
                responseTactic: a, rules: asiri),
            1,
            reason: 'Legend açtı, $a ile cevap',
          );
          expect(
            resolveRound(lead: guclu, response: legend, leadTactic: a,
                responseTactic: b, rules: asiri),
            -1,
          );
        }
      }
    });

    test('taktiksiz sonuç sunucudaki compare_cards ile aynı', () {
      expect(resolveRound(lead: const SimCard('FWD', 80), response: const SimCard('FWD', 79)), 1);
      expect(resolveRound(lead: const SimCard('FWD', 79), response: const SimCard('FWD', 80)), -1);
      expect(resolveRound(lead: const SimCard('FWD', 80), response: const SimCard('FWD', 80)), 0);
      // İki Legend: güç karşılaştırılır
      expect(resolveRound(lead: legend, response: const SimCard('MID', 95, isLegend: true)), -1);
    });

    test('taktik bonusu güç karşılaştırmasına eklenir', () {
      // 80 vs 85: pres (+9) ile turu açan kazanır
      expect(
        resolveRound(
          lead: const SimCard('FWD', 80),
          response: const SimCard('FWD', 85),
          leadTactic: Tactic.highPress,
        ),
        1,
      );
    });
  });

  // ==================================================================
  // SİMÜLATÖR
  // ==================================================================
  group('Simülatör', () {
    test('aynı tohum = aynı maç (tekrarlanabilir)', () {
      MatchOutcome oyna() => MatchSimulator(rules: k, rng: Random(42))
          .play(SmartPolicy(), RandomPolicy());
      final a = oyna(), b = oyna();
      expect(a.capturedA, b.capturedA);
      expect(a.capturedB, b.capturedB);
    });

    test('toplanan kartlar 22\'yi geçmez; kalan pot kimseye yazılmaz', () {
      final sim = MatchSimulator(rules: k, rng: Random(1));
      for (var i = 0; i < 300; i++) {
        final s = sim.play(RandomPolicy(), AdaptivePolicy());
        expect(s.capturedA + s.capturedB, lessThanOrEqualTo(22));
        expect((22 - s.capturedA - s.capturedB).isEven, isTrue,
            reason: 'Her tur 2 kart; kalan pot çift sayı olmalı');
        expect(s.stats.rounds, 11);
      }
    });

    test('kadro 1-4-4-2 ve gerçek güç aralıklarında', () {
      final kadro = randomSquad(Random(3));
      expect(kadro.map((c) => c.position).toList(), kFormation);
      for (final c in kadro) {
        expect(c.effectivePower, inInclusiveRange(45, 99 + 6));
      }
    });

    test('gücü yetmeyen taktik kullanılmaz (enerji eksiye düşmez)', () {
      final p = AlwaysPolicy(Tactic.highPress);
      final c = PolicyContext(
        myCard: const SimCard('FWD', 80),
        myEnergy: k.pressCost - 1,
        opponentEnergy: 5,
        rules: k,
        rng: Random(1),
      );
      expect(p.chooseLead(c), Tactic.none);
    });

    test('akıllı oyuncu zaten kazanıyorsa enerjisini saklar', () {
      final c = PolicyContext(
        myCard: const SimCard('DEF', 99),
        myEnergy: 5,
        opponentEnergy: 0, // rakip hiçbir taktiğe gücü yetmiyor
        rules: k,
        rng: Random(1),
      );
      expect(SmartPolicy().chooseResponse(c, const SimCard('DEF', 60)),
          Tactic.none);
    });

    test('akıllı oyuncu pres beklentisinde kontraya çıkar', () {
      // Rakip kartı biraz güçlü; rakibin enerjisi pres yapmaya yetiyor
      final c = PolicyContext(
        myCard: const SimCard('FWD', 80),
        myEnergy: 5,
        opponentEnergy: k.pressCost,
        rules: k,
        rng: Random(1),
      );
      final secim = SmartPolicy().chooseResponse(c, const SimCard('FWD', 83));
      expect(secim, isNot(Tactic.none));
    });
  });

  // ==================================================================
  // DENGE — raporla aynı hedefler
  // ==================================================================
  group('Denge hedefleri (sabit tohum, çift başına 2000 maç)', () {
    late BalanceReport rapor;

    setUpAll(() => rapor = runBalance(matchesPerPair: 2000, seed: 2026));

    test('bütün hedefler tutuyor', () {
      final tutmayan =
          rapor.checks.where((c) => !c.passed).map((c) => '${c.name}: ${c.value}');
      expect(tutmayan, isEmpty);
    });

    test('Legend kuralı hiç ihlal edilmedi', () {
      expect(rapor.stats.legendViolations, 0);
      expect(rapor.stats.rounds, greaterThan(400000));
    });

    test('taktik kullanmak bedava zafer değil: rastgele taktik '
        'taktiksizi ezmiyor', () {
      expect(rapor.matrix['Rastgele']!['Taktiksiz']!, lessThan(0.62));
    });
  });
}
