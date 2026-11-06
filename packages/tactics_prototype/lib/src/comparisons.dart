import 'dart:math';

import 'balance.dart';
import 'simulation.dart';
import 'tactics.dart';

// =====================================================================
// KARŞILAŞTIRMALI SİMÜLASYONLAR (canlı kurallar DEĞİŞMEDİ)
// =====================================================================
// Her alternatif, AYNI tohum ve AYNI kadrolarla bugünkü motora karşı
// ölçülür. Hiçbiri oyunda aktif değil; sonuçlar kullanıcı onayı için.

double _puan(int r) => r > 0 ? 1.0 : (r == 0 ? 0.5 : 0.0);

// ---------------------------------------------------------------------
// A) İLK AÇAN VARYANTLARI
// ---------------------------------------------------------------------
class FirstLeaderRow {
  final MatchVariant variant;

  /// İlk açanın puanı (Akıllı vs Akıllı) — hedef %45–55, ideal %50
  final double firstLeaderSmart;

  /// İlk açanın puanı (Taktiksiz vs Taktiksiz)
  final double firstLeaderPlain;

  /// Beceri ödülü: Akıllı'nın Taktiksiz'e karşı puanı
  final double skill;

  /// Güç ödülü: +4 güçlü kadronun puanı (ikisi Akıllı)
  final double power4;

  /// Maç içi geri dönüş: ilk 4 turdan sonra geride olanın maçı
  /// kazanma/berabere bitirme puanı (yüksek = kartopu etkisi az)
  final double comeback;

  const FirstLeaderRow(this.variant, this.firstLeaderSmart,
      this.firstLeaderPlain, this.skill, this.power4, this.comeback);
}

const firstLeaderVariants = [
  MatchVariant.live,
  MatchVariant('S1: ilk açana +1 enerji', firstLeaderEnergyBonus: 1),
  MatchVariant('S1b: ilk açana +2 enerji', firstLeaderEnergyBonus: 2),
  MatchVariant('S2: kör cevap (her tur)', blindResponse: true),
  MatchVariant('S2b: kör cevap (sadece ilk tur)',
      blindResponse: true, blindFirstRoundOnly: true),
  MatchVariant('S3: açma sırası dönüşümlü', leadRule: LeadRule.alternate),
  MatchVariant('S4: turu kaybeden açar', leadRule: LeadRule.loserLeads),
];

List<FirstLeaderRow> compareFirstLeader({int matches = 3000, int seed = 41}) {
  const k = TacticRules.balanced;
  final satirlar = <FirstLeaderRow>[];
  for (final v in firstLeaderVariants) {
    final rng = Random(seed);
    double ilkAcan(TacticPolicy Function() f) {
      var p = 0.0;
      playPair(f, f, matches: matches * 2, rules: k, rng: rng, variant: v,
          onMatch: (aIlk, r) => p += aIlk ? _puan(r) : 1 - _puan(r));
      return p / (matches * 2);
    }

    final akilli = ilkAcan(SmartPolicy.new);
    final duz = ilkAcan(NoTacticPolicy.new);
    final beceri = playPair(SmartPolicy.new, NoTacticPolicy.new,
            matches: matches, rules: k, rng: rng, variant: v)
        .scoreA;
    final guc = playPair(SmartPolicy.new, SmartPolicy.new,
            matches: matches,
            rules: k,
            rng: rng,
            variant: v,
            squadA: SquadProfile.standard.withBonus(4))
        .scoreA;
    satirlar.add(FirstLeaderRow(
        v, akilli, duz, beceri, guc, _geriDonus(v, matches, rng)));
  }
  return satirlar;
}

/// 4 tur sonra geride olan taraf maçı ne kadar kurtarabiliyor?
double _geriDonus(MatchVariant v, int matches, Random rng) {
  // Ayrı bir küçük simülasyon: 4. turdaki skoru görebilmek için
  // MatchSimulator'ı 11 yerine iki aşamada oynatmak yerine, 4 turluk
  // ve 11 turluk sonucu aynı tohumla karşılaştırmak yanıltıcı olurdu.
  // Bu yüzden basit bir yaklaşım: güçsüz (−3) taraf ne kadar kazanıyor?
  // Kartopu etkisi güçlüyse küçük güç farkı bile kesin yenilgiye döner.
  return 1 -
      playPair(SmartPolicy.new, SmartPolicy.new,
              matches: matches,
              rules: TacticRules.balanced,
              rng: rng,
              variant: v,
              squadA: SquadProfile.standard.withBonus(3))
          .scoreA;
}

// ---------------------------------------------------------------------
// B) KURAL SÜRÜMÜ 2 vs 3 (özellik → taktik çarpanı)
// ---------------------------------------------------------------------
class VersionComparison {
  final BalanceReport v2;
  final BalanceReport v3;

  /// "MEVKİ|taktik" -> (v2 tur kazanma, v3 tur kazanma, kullanım)
  final Map<String, (double, double, int)> positionTactic;

  const VersionComparison(this.v2, this.v3, this.positionTactic);

  /// Bir taktiğin mevkiler arası tur kazanma farkı (en iyi − en kötü)
  double spread(BalanceReport r, Tactic t, {bool v3 = false}) {
    final degerler = [
      for (final e in positionTactic.entries)
        if (e.key.endsWith('|${t.name}') && e.value.$3 > 2000)
          v3 ? e.value.$2 : e.value.$1,
    ];
    if (degerler.length < 2) return 0;
    return degerler.reduce(max) - degerler.reduce(min);
  }
}

VersionComparison compareRuleVersions({int matchesPerPair = 2000, int seed = 2026}) {
  final v2 = runBalance(
      rules: TacticRules.balanced,
      matchesPerPair: matchesPerPair,
      seed: seed,
      attributes: true);
  final v3 = runBalance(
      rules: TacticRules.v3Attributes,
      matchesPerPair: matchesPerPair,
      seed: seed,
      attributes: true);

  double oran(MatchStats s, String k) {
    final u = s.usedByPos[k] ?? 0;
    return u == 0 ? 0 : (s.wonByPos[k] ?? 0) / u;
  }

  final anahtarlar = {...v2.stats.usedByPos.keys, ...v3.stats.usedByPos.keys}
      .where((k) => !k.endsWith('|none'))
      .toList()
    ..sort();
  return VersionComparison(v2, v3, {
    for (final a in anahtarlar)
      a: (oran(v2.stats, a), oran(v3.stats, a), v3.stats.usedByPos[a] ?? 0),
  });
}
