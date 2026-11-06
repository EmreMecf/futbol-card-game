import 'dart:math';

import 'package:tactics_prototype/tactics_prototype.dart';
import 'package:test/test.dart';

/// Rekabet analizi: karşılaştırmalı simülasyonların testleri.
///
/// Yön testleri: alternatiflerin İDDİA ettiğimiz etkiyi gerçekten
/// gösterdiğini (ve canlı kuralların değişmediğini) sabit tohumla
/// doğrular. Sayılar küçük tutuldu (CI süresi); kesin değerler
/// bin/karsilastir.dart ile üretilen KARSILASTIRMA.md'de.
void main() {
  group('Canlı kurallar değişmedi', () {
    test('MatchVariant.live = bugünkü simülasyon (aynı tohum, aynı sonuç)', () {
      MatchOutcome oyna(MatchVariant? v) {
        final sim = v == null
            ? MatchSimulator(rules: TacticRules.balanced, rng: Random(9))
            : MatchSimulator(
                rules: TacticRules.balanced, rng: Random(9), variant: v);
        return sim.play(SmartPolicy(), AdaptivePolicy());
      }

      final a = oyna(null), b = oyna(MatchVariant.live);
      expect(a.capturedA, b.capturedA);
      expect(a.capturedB, b.capturedB);
    });

    test('sürüm 2 oyuncu tipini YOK sayar', () {
      const tip = TacticAffinity(10, 10, 10);
      expect(
        TacticRules.balanced.bonus(Tactic.highPress, Tactic.none,
            iAmLead: true, affinity: tip),
        TacticRules.balanced.pressBonus,
      );
    });
  });

  group('Sürüm 3 adayı: özellik çarpanı', () {
    const k = TacticRules.v3Attributes;

    test('bonus en fazla ±%20 ölçeklenir (sınırsız güç yok)', () {
      const cokUygun = TacticAffinity(99, 99, 99);
      const hicUygunDegil = TacticAffinity(-99, -99, -99);
      expect(k.bonus(Tactic.highPress, Tactic.none, iAmLead: true, affinity: cokUygun),
          (9 * 1.2).round());
      expect(k.bonus(Tactic.highPress, Tactic.none, iAmLead: true, affinity: hicUygunDegil),
          (9 * 0.8).round());
    });

    test('kırılan taktik yine SIFIR (çarpan sıfırı büyütmez)', () {
      const cokUygun = TacticAffinity(99, 99, 99);
      expect(k.bonus(Tactic.highPress, Tactic.counterAttack,
          iAmLead: true, affinity: cokUygun), 0);
    });

    test('taktik yoksa özellik hiçbir şey yapmaz', () {
      expect(k.bonus(Tactic.none, Tactic.highPress,
          iAmLead: true, affinity: const TacticAffinity(99, 99, 99)), 0);
    });

    test('oyuncu tipi mevki profiline uyar (forvet kontraya, stoper duvara yatkın)', () {
      final r = Random(3);
      double ort(String poz, int Function(TacticAffinity) f) =>
          [for (var i = 0; i < 400; i++) f(randomAffinity(poz, r))]
              .reduce((a, b) => a + b) / 400;
      expect(ort('FWD', (a) => a.counter), greaterThan(ort('DEF', (a) => a.counter)));
      expect(ort('DEF', (a) => a.wall), greaterThan(ort('FWD', (a) => a.wall)));
    });

    test('Legend kuralı sürüm 3te de bozulmaz', () {
      const legend = SimCard('MID', 70, isLegend: true);
      const guclu = SimCard('MID', 99, affinity: TacticAffinity(20, 20, 20));
      expect(resolveRound(lead: legend, response: guclu,
          responseTactic: Tactic.highPress, rules: k), 1);
    });

    test('zorunlu denge hedefleri sürüm 3te de tutuyor', () {
      // Ana denge raporuyla AYNI örneklem (2000): güç farkı kayması
      // sınıra yakın (%5) olduğu için küçük örneklem gürültüyle kırılıyor.
      final r = runBalance(
          rules: k, matchesPerPair: 2000, seed: 2026, attributes: true);
      final tutmayan = r.checks
          .where((c) => c.required && !c.passed)
          .map((c) => '${c.name}: ${c.value}');
      expect(tutmayan, isEmpty);
    });
  });

  group('İlk açan varyantları', () {
    test('sadece ilk turda kör cevap, ilk açanı %50e yaklaştırır', () {
      final satirlar = compareFirstLeader(matches: 1500, seed: 3);
      final bugun = satirlar.firstWhere((s) => s.variant == MatchVariant.live);
      final kor = satirlar.firstWhere((s) => s.variant.blindFirstRoundOnly);
      expect((kor.firstLeaderSmart - 0.5).abs(),
          lessThan((bugun.firstLeaderSmart - 0.5).abs()));
      // Beceri ödülü korunur (en fazla 4 puan düşebilir)
      expect(kor.skill, greaterThan(bugun.skill - 0.04));
    });
  });

  group('Eşleştirme', () {
    test('birleşik puan: yeni gelenin umutsuz maçı ve puanı iyileşir', () {
      final bugun = simulateMatchmaking(MatchmakingMode.mmrOnly,
          steps: 900, population: 120);
      final yeni = simulateMatchmaking(MatchmakingMode.combined,
          steps: 900, population: 120);
      expect(yeni.newcomerHopeless, lessThan(bugun.newcomerHopeless));
      expect(yeni.newcomerScore, greaterThan(bugun.newcomerScore));
      // Sıralama beceriyi kadrodan daha çok yansıtır
      expect(yeni.skillOverDeck, greaterThan(bugun.skillOverDeck));
    });
  });

  group('Ekonomi', () {
    test('kalıcı kayıp yoksa kimse kilitlenmez; bugünkü kural kilitler', () {
      final bugun = simulateEconomy(LossRule.live3, players: 60, rounds: 80);
      final kayipsiz = simulateEconomy(LossRule.none, players: 60, rounds: 80);
      expect(kayipsiz.stuckRate, 0);
      expect(bugun.stuckRate, greaterThan(0.10));
    });

    test('başlangıç koleksiyonu gerçek pakete uyar (her mevkide 1 yedek)', () {
      final k = starterCollection(Random(1));
      expect(k, hasLength(15));
      for (final e in kStarterPositions.entries) {
        expect(k.where((c) => c.position == e.key).length, e.value);
      }
      expect(k.any((c) => c.tier == 'diamond' || c.tier == 'legend'), isFalse);
    });
  });
}
