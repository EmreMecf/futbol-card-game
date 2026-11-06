import 'dart:math';

import 'tactics.dart';

/// MAÇ SİMÜLATÖRÜ
///
/// Sunucudaki gerçek kuralların BİREBİR kopyası (bkz. `_resolve_round`,
/// `_finish_match`), üstüne prototip taktik katmanı:
///   * 11 tur, zorunlu 1-4-4-2 kadro
///   * Turu açan mevkiyi seçer, cevap veren AYNI mevkiden oynar
///   * Kazanan masadaki her kartı toplar ve sonraki turu açar
///   * Beraberlikte kartlar masada birikir, sıra RAKİBE geçer
///   * Maç sonunda masada kalan kartlar kimseye yazılmaz
///   * Maçı daha çok kart toplayan kazanır
///
/// Simülasyon deterministik: aynı tohum (seed) her zaman aynı sonucu
/// verir. Böylece testler ve rapor tekrarlanabilir.

/// Formasyon: 1 kaleci, 4 defans, 4 orta saha, 2 forvet
const List<String> kFormation = [
  'GK',
  'DEF', 'DEF', 'DEF', 'DEF',
  'MID', 'MID', 'MID', 'MID',
  'FWD', 'FWD',
];

/// Gerçek katalogdaki seviye güç aralıkları (010_seed_cards.sql)
const Map<String, (int, int)> kTierPower = {
  'bronze': (45, 62),
  'silver': (63, 74),
  'gold': (75, 85),
  'diamond': (86, 92),
  'legend': (93, 99),
};

/// Orta seviye bir oyuncunun kadrosundaki seviye dağılımı (ağırlık)
const Map<String, int> kTierWeights = {
  'bronze': 25,
  'silver': 30,
  'gold': 30,
  'diamond': 12,
  'legend': 3,
};

/// Mevki profilleri: özelliğin karta göre sapması (016_card_attributes.sql)
///                       ŞUT  HIZ  FİZİK  DEF  DRİB  HIZLANMA
const Map<String, List<int>> kAttributeProfile = {
  'GK': [-38, -20, 1, 2, -28, -22],
  'DEF': [-22, -5, 6, 8, -12, -6],
  'MID': [-3, -2, -5, -7, 6, -2],
  'FWD': [6, 5, -6, -24, 5, 6],
};

/// Kartın oyuncu tipi: mevki profili + karta özel −4..+4 sapma
/// (oyundaki gibi). Değer kartın gücünden BAĞIMSIZ.
TacticAffinity randomAffinity(String position, Random rng) {
  final p = kAttributeProfile[position]!;
  int ozellik(int i) => p[i] + rng.nextInt(9) - 4;
  final hiz = ozellik(1), fizik = ozellik(2), defans = ozellik(3);
  final drib = ozellik(4), hizlanma = ozellik(5);
  return TacticAffinity(
    ((fizik + hizlanma) / 2).round(),
    ((hiz + drib) / 2).round(),
    ((defans + fizik) / 2).round(),
  );
}

/// Kadro profili: seviye dağılımı ve (test için) her karta ek güç.
///
/// Denge testleri yalnızca "iki eşit oyuncu" durumunu ölçmemeli:
/// yeni oyuncu ile kıdemli oyuncu, güç farkı olan kadrolar da
/// ayrıca ölçülüyor (bağımsız inceleme, madde 1).
class SquadProfile {
  final String name;
  final Map<String, int> weights;
  final int powerBonus;

  /// Kartlara oyuncu tipi üretilsin mi? (sürüm 3 karşılaştırması)
  /// Kapalıyken rastgele sayı dizisi eskisiyle BİREBİR aynı kalır.
  final bool withAttributes;

  const SquadProfile(this.name, this.weights,
      {this.powerBonus = 0, this.withAttributes = false});

  /// Orta seviye oyuncu (varsayılan)
  static const standard = SquadProfile('Orta', kTierWeights);

  /// Başlangıç paketiyle oynayan yeni oyuncu (Diamond/Legend yok)
  static const starter =
      SquadProfile('Başlangıç', {'bronze': 50, 'silver': 40, 'gold': 10});

  /// Kıdemli oyuncu (%12 Legend)
  static const veteran = SquadProfile(
      'Kıdemli', {'silver': 15, 'gold': 40, 'diamond': 33, 'legend': 12});

  SquadProfile withBonus(int b) => SquadProfile('$name +$b', weights,
      powerBonus: b, withAttributes: withAttributes);

  SquadProfile get attributed =>
      SquadProfile(name, weights, powerBonus: powerBonus, withAttributes: true);

  List<SimCard> build(Random rng) => randomSquad(rng,
      weights: weights, powerBonus: powerBonus, withAttributes: withAttributes);
}

/// Rastgele ama gerçekçi bir kadro üretir.
List<SimCard> randomSquad(
  Random rng, {
  Map<String, int> weights = kTierWeights,
  int powerBonus = 0,
  bool withAttributes = false,
}) {
  final toplam = weights.values.reduce((a, b) => a + b);
  String seviye() {
    var r = rng.nextInt(toplam);
    for (final e in weights.entries) {
      if (r < e.value) return e.key;
      r -= e.value;
    }
    return 'bronze';
  }

  return [
    for (final poz in kFormation)
      () {
        final s = seviye();
        final (min, max) = kTierPower[s]!;
        final guc = min + rng.nextInt(max - min + 1);
        final kimya = rng.nextInt(7); // 0-6, gerçek oyundaki aralık
        return SimCard(
          poz,
          guc + kimya + powerBonus,
          isLegend: s == 'legend',
          affinity: withAttributes
              ? randomAffinity(poz, rng)
              : TacticAffinity.neutral,
        );
      }(),
  ];
}

// ====================================================================
// YAPAY OYUNCULAR (taktik seçme tarzları)
// ====================================================================
/// Bir oyuncunun taktik seçme tarzı.
///
/// KART seçimi bütün tarzlarda AYNI (simülatör yapıyor). Böylece
/// tarzlar arasındaki fark sadece TAKTİK kararlarından geliyor;
/// ölçtüğümüz şey gerçekten taktiklerin etkisi.
abstract class TacticPolicy {
  String get name;

  /// Turu ben açıyorum: hangi kartla? Varsayılan RASTGELE (bugünkü
  /// simülasyonla birebir aynı rastgele çekim).
  SimCard chooseLeadCard(List<SimCard> hand, Random rng) =>
      hand[rng.nextInt(hand.length)];

  /// Turu ben açıyorum. Rakibin kartını bilmiyorum.
  Tactic chooseLead(PolicyContext c);

  /// Rakip turu açtı; kartını görüyorum (taktiğini görmüyorum).
  Tactic chooseResponse(PolicyContext c, SimCard leadCard);

  /// Rakibin bu turda kullandığı taktik (tur çözülünce açılır)
  void observeOpponent(Tactic t) {}

  /// Yeni maç başlıyor (öğrenen tarzlar hafızasını sıfırlar)
  void reset() {}
}

class PolicyContext {
  final SimCard myCard;
  final int myEnergy;
  final int opponentEnergy;
  final TacticRules rules;
  final Random rng;

  const PolicyContext({
    required this.myCard,
    required this.myEnergy,
    required this.opponentEnergy,
    required this.rules,
    required this.rng,
  });

  List<Tactic> get affordable => [
        for (final t in Tactic.values)
          if (rules.costOf(t) <= myEnergy) t,
      ];

  List<Tactic> get opponentAffordable => [
        for (final t in Tactic.values)
          if (rules.costOf(t) <= opponentEnergy) t,
      ];
}

/// Hiç taktik kullanmaz (bugünkü oyun)
class NoTacticPolicy extends TacticPolicy {
  @override
  String get name => 'Taktiksiz';
  @override
  Tactic chooseLead(PolicyContext c) => Tactic.none;
  @override
  Tactic chooseResponse(PolicyContext c, SimCard leadCard) => Tactic.none;
}

/// Gücü yettiği taktiklerden rastgele birini seçer (acemi oyuncu)
class RandomPolicy extends TacticPolicy {
  @override
  String get name => 'Rastgele';
  Tactic _sec(PolicyContext c) =>
      c.affordable[c.rng.nextInt(c.affordable.length)];
  @override
  Tactic chooseLead(PolicyContext c) => _sec(c);
  @override
  Tactic chooseResponse(PolicyContext c, SimCard leadCard) => _sec(c);
}

/// Gücü yettikçe hep aynı taktiği kullanır ("tek numara" oyuncu).
///
/// DENGE TESTİNİN ÖZÜ: Eğer bir taktiği körü körüne basmak her şeyi
/// yeniyorsa sistem bozuk demektir.
class AlwaysPolicy extends TacticPolicy {
  final Tactic tactic;
  AlwaysPolicy(this.tactic);
  @override
  String get name => 'Hep ${tactic.label}';
  Tactic _sec(PolicyContext c) =>
      c.rules.costOf(tactic) <= c.myEnergy ? tactic : Tactic.none;
  @override
  Tactic chooseLead(PolicyContext c) => _sec(c);
  @override
  Tactic chooseResponse(PolicyContext c, SimCard leadCard) => _sec(c);
}

/// Enerjiyi BİRİKTİRİR: sadece enerji doluyken pres basar; cevapta,
/// rakibin pres yapmaya gücü yetiyorsa kontra bekler.
class HoarderPolicy extends TacticPolicy {
  @override
  String get name => 'Biriktirici';
  @override
  Tactic chooseLead(PolicyContext c) =>
      c.myEnergy >= c.rules.maxEnergy ? Tactic.highPress : Tactic.none;
  @override
  Tactic chooseResponse(PolicyContext c, SimCard leadCard) =>
      c.opponentEnergy >= c.rules.pressCost &&
              c.myEnergy >= c.rules.counterCost
          ? Tactic.counterAttack
          : Tactic.none;
}

/// Enerjiyi HARCAR: açarken gücü yetiyorsa pres, yetmiyorsa duvar;
/// cevapta her fırsatta duvar.
class SpenderPolicy extends TacticPolicy {
  @override
  String get name => 'Harcayıcı';
  @override
  Tactic chooseLead(PolicyContext c) => c.myEnergy >= c.rules.pressCost
      ? Tactic.highPress
      : (c.myEnergy >= c.rules.wallCost ? Tactic.defensiveWall : Tactic.none);
  @override
  Tactic chooseResponse(PolicyContext c, SimCard leadCard) =>
      c.myEnergy >= c.rules.wallCost ? Tactic.defensiveWall : Tactic.none;
}

/// Rakibin en çok kullandığı taktiğin KARŞISINI seçer (okuyan oyuncu).
class AdaptivePolicy extends TacticPolicy {
  final Map<Tactic, int> _sayim = {};

  @override
  String get name => 'Uyarlanır';

  @override
  void reset() => _sayim.clear();

  @override
  void observeOpponent(Tactic t) {
    if (t != Tactic.none) _sayim[t] = (_sayim[t] ?? 0) + 1;
  }

  Tactic _sec(PolicyContext c) {
    if (_sayim.isEmpty) return Tactic.none;
    final enCok =
        _sayim.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final karsi = enCok.beatenBy!;
    return c.rules.costOf(karsi) <= c.myEnergy ? karsi : Tactic.none;
  }

  @override
  Tactic chooseLead(PolicyContext c) => _sec(c);
  @override
  Tactic chooseResponse(PolicyContext c, SimCard leadCard) => _sec(c);
}

/// Hesaplayan oyuncu.
///
/// CEVAP VERİRKEN: Rakibin kartını görüyor. Rakibin gücü yeten her
/// taktiği EŞİT olasılıkla seçebileceğini varsayıp, kendi her taktiği
/// için tur kazanma beklentisini hesaplıyor; en iyisini seçiyor. Zaten
/// kazanıyorsa ya da kurtuluş yoksa enerjiyi saklıyor.
///
/// Oyuncu tipini bilen hesaplayan oyuncu (sürüm 3 değerlendirmesi).
///
/// Cevapta Akıllı ile aynı (beklenti hesabı kartın tipini zaten
/// içeriyor). Turu açarken: kartının tipi bir taktiğe belirgin şekilde
/// uyuyorsa (sapma ≥ 3) ve enerji yetiyorsa o taktiği kullanır.
class TypeAwarePolicy extends SmartPolicy {
  @override
  String get name => 'Tip Bilen';

  /// Turu açarken taktiğe EN UYGUN oyuncuyu sürer: pres/kontra tipi
  /// belirgin (sapma ≥ 3) ve Legend olmayan kartlar arasından en uygunu;
  /// yoksa rastgele.
  @override
  SimCard chooseLeadCard(List<SimCard> hand, Random rng) {
    SimCard? enIyi;
    var enIyiSapma = 2;
    for (final k in hand) {
      if (k.isLegend || k.effectivePower >= 88) continue;
      final s = max(k.affinity.press, k.affinity.counter);
      if (s > enIyiSapma) {
        enIyi = k;
        enIyiSapma = s;
      }
    }
    return enIyi ?? hand[rng.nextInt(hand.length)];
  }

  @override
  Tactic chooseLead(PolicyContext c) {
    if (c.myCard.isLegend || c.myCard.effectivePower >= 88) return Tactic.none;
    final a = c.myCard.affinity;
    final adaylar = [
      (Tactic.highPress, a.press),
      (Tactic.counterAttack, a.counter),
    ]..sort((x, y) => y.$2.compareTo(x.$2));
    for (final (t, sapma) in adaylar) {
      if (sapma >= 3 && c.rules.costOf(t) <= c.myEnergy - 1) return t;
    }
    return super.chooseLead(c);
  }
}

/// TURU AÇARKEN: Rakibin kartını bilmiyor. Orta güçlü kartla, enerjisi
/// pres + yedek için yetiyorsa ara sıra pres yapıyor.
class SmartPolicy extends TacticPolicy {
  @override
  String get name => 'Akıllı';

  @override
  Tactic chooseLead(PolicyContext c) {
    final g = c.myCard.effectivePower;
    if (c.myCard.isLegend || g >= 88) return Tactic.none;
    final pres = c.rules.costOf(Tactic.highPress);
    if (c.myEnergy >= pres + 1 && c.rng.nextDouble() < 0.35) {
      return Tactic.highPress;
    }
    return Tactic.none;
  }

  @override
  Tactic chooseResponse(PolicyContext c, SimCard leadCard) {
    double beklenti(Tactic benim) {
      final rakipler = c.opponentAffordable;
      var toplam = 0.0;
      for (final o in rakipler) {
        final r = resolveRound(
          lead: leadCard,
          response: c.myCard,
          leadTactic: o,
          responseTactic: benim,
          rules: c.rules,
        );
        toplam += r < 0 ? 1.0 : (r == 0 ? 0.4 : 0.0);
      }
      return toplam / rakipler.length;
    }

    var enIyi = Tactic.none;
    var enIyiDeger = beklenti(Tactic.none);
    for (final t in c.affordable) {
      if (t == Tactic.none) continue;
      final d = beklenti(t);
      // Enerji harcamaya değsin: anlamlı bir fark yoksa sakla
      if (d > enIyiDeger + 0.15) {
        enIyi = t;
        enIyiDeger = d;
      }
    }
    return enIyi;
  }
}

// ====================================================================
// MAÇ
// ====================================================================
class MatchStats {
  int rounds = 0;

  /// Taktikler sonucu DEĞİŞTİRDİ mi? (aynı kartlar, taktiksiz sonuç farklı)
  int flips = 0;

  /// Legend kuralı ihlali: taktik yüzünden Legend olmayan kart Legend'ı
  /// yendi ya da tersi. HER ZAMAN 0 olmalı.
  int legendViolations = 0;

  /// Taktik -> (kullanıldığı tur sayısı, o turu kazanma sayısı)
  final Map<Tactic, int> used = {for (final t in Tactic.values) t: 0};
  final Map<Tactic, int> wonWith = {for (final t in Tactic.values) t: 0};

  /// "MEVKİ|taktik" -> kullanım / o turu kazanma (sürüm 3: hiçbir
  /// mevki-taktik çifti aşırı güçlü olmamalı)
  final Map<String, int> usedByPos = {};
  final Map<String, int> wonByPos = {};

  void _say(Map<String, int> m, String k) => m[k] = (m[k] ?? 0) + 1;

  void merge(MatchStats o) {
    rounds += o.rounds;
    flips += o.flips;
    legendViolations += o.legendViolations;
    for (final t in Tactic.values) {
      used[t] = used[t]! + o.used[t]!;
      wonWith[t] = wonWith[t]! + o.wonWith[t]!;
    }
    o.usedByPos.forEach((k, v) => usedByPos[k] = (usedByPos[k] ?? 0) + v);
    o.wonByPos.forEach((k, v) => wonByPos[k] = (wonByPos[k] ?? 0) + v);
  }
}

/// Maç sonucu: 1 = A kazandı, -1 = B kazandı, 0 = berabere
class MatchOutcome {
  final int result;
  final int capturedA;
  final int capturedB;
  final MatchStats stats;

  /// İlk turu A mı açtı? (ilk açan avantajı ölçümü için)
  final bool firstLeaderIsA;

  const MatchOutcome(this.result, this.capturedA, this.capturedB, this.stats,
      {this.firstLeaderIsA = true});
}

/// Sonraki turu kim açar?
enum LeadRule {
  /// Bugün: turu kazanan açar (beraberlikte sıra rakibe)
  winnerLeads,

  /// Sırayla: kim kazanırsa kazansın açma sırası değişir
  alternate,

  /// Turu KAYBEDEN açar
  loserLeads,
}

/// İlk açan dezavantajı için denenen kural VARYANTLARI (oyunda YOK).
/// [MatchVariant.live] bugünkü oyunun birebir aynısı.
class MatchVariant {
  final String name;

  /// İlk turu açana ek başlangıç enerjisi
  final int firstLeaderEnergyBonus;

  /// Cevap veren, açanın kartının GÜCÜNÜ görmeden seçer (mevkiyi bilir)
  final bool blindResponse;

  /// Kör cevap sadece ilk turda mı?
  final bool blindFirstRoundOnly;

  final LeadRule leadRule;

  const MatchVariant(
    this.name, {
    this.firstLeaderEnergyBonus = 0,
    this.blindResponse = false,
    this.blindFirstRoundOnly = false,
    this.leadRule = LeadRule.winnerLeads,
  });

  static const live = MatchVariant('Bugün (canlı kural)');
}

class MatchSimulator {
  final TacticRules rules;
  final Random rng;
  final MatchVariant variant;

  MatchSimulator({
    required this.rules,
    required this.rng,
    this.variant = MatchVariant.live,
  });

  /// Kör cevap: rakibin gücünü bilmeyen oyuncu o mevkideki ORTANCA
  /// kartını oynar (en iyisini harcamaz, en kötüsüyle de kaybetmez).
  SimCard _korCevapKarti(List<SimCard> el, String mevki) {
    final adaylar = el.where((k) => k.position == mevki).toList()
      ..sort((a, b) => a.effectivePower.compareTo(b.effectivePower));
    return adaylar[adaylar.length ~/ 2];
  }

  /// Cevap veren için kart seçimi (bütün tarzlarda aynı):
  /// Kazandıran EN ZAYIF kart; yoksa EN ZAYIF kart (feda).
  SimCard _cevapKarti(List<SimCard> el, SimCard lead) {
    final adaylar = el.where((k) => k.position == lead.position).toList()
      ..sort((a, b) => a.effectivePower.compareTo(b.effectivePower));
    for (final k in adaylar) {
      if (resolveRound(lead: lead, response: k, rules: rules) < 0) return k;
    }
    return adaylar.first;
  }

  MatchOutcome play(
    TacticPolicy a,
    TacticPolicy b, {
    SquadProfile squadA = SquadProfile.standard,
    SquadProfile squadB = SquadProfile.standard,
  }) =>
      playSquads(a, b, squadA.build(rng), squadB.build(rng));

  /// Sabit kadrolarla maç (eşleştirme ve ekonomi simülasyonlarında her
  /// oyuncunun kendi kalıcı kadrosu var). Kadrolar KOPYALANIR.
  MatchOutcome playSquads(
    TacticPolicy a,
    TacticPolicy b,
    List<SimCard> kadroA,
    List<SimCard> kadroB,
  ) {
    a.reset();
    b.reset();
    final eller = [List.of(kadroA), List.of(kadroB)];
    final oyuncular = [a, b];
    final enerji = [rules.startEnergy, rules.startEnergy];
    final toplanan = [0, 0];
    var pot = 0;
    var acan = rng.nextInt(2); // sunucu ilk açanı rastgele seçer
    final ilkAcanA = acan == 0;
    enerji[acan] += variant.firstLeaderEnergyBonus;
    final st = MatchStats();

    for (var tur = 0; tur < kFormation.length; tur++) {
      if (tur > 0) {
        for (var i = 0; i < 2; i++) {
          enerji[i] = min(rules.maxEnergy, enerji[i] + rules.energyPerRound);
        }
      }
      final cevap = 1 - acan;

      // Turu açan kartını seçer (varsayılan: rastgele)
      final acanEl = eller[acan];
      final acanKart = oyuncular[acan].chooseLeadCard(acanEl, rng);
      acanEl.remove(acanKart);
      final acanTaktik = oyuncular[acan].chooseLead(PolicyContext(
        myCard: acanKart,
        myEnergy: enerji[acan],
        opponentEnergy: enerji[cevap],
        rules: rules,
        rng: rng,
      ));

      final kor = variant.blindResponse &&
          (!variant.blindFirstRoundOnly || tur == 0);
      final cevapKart = kor
          ? _korCevapKarti(eller[cevap], acanKart.position)
          : _cevapKarti(eller[cevap], acanKart);
      eller[cevap].remove(cevapKart);
      final cevapTaktik = oyuncular[cevap].chooseResponse(
        PolicyContext(
          myCard: cevapKart,
          myEnergy: enerji[cevap],
          opponentEnergy: enerji[acan],
          rules: rules,
          rng: rng,
        ),
        // Kör cevapta gücü bilmiyor: ortalama bir kart varsayar
        kor ? SimCard(acanKart.position, 75) : acanKart,
      );

      enerji[acan] -= rules.costOf(acanTaktik);
      enerji[cevap] -= rules.costOf(cevapTaktik);
      assert(enerji[acan] >= 0 && enerji[cevap] >= 0);

      final sonuc = resolveRound(
        lead: acanKart,
        response: cevapKart,
        leadTactic: acanTaktik,
        responseTactic: cevapTaktik,
        rules: rules,
      );
      final taktiksiz =
          resolveRound(lead: acanKart, response: cevapKart, rules: rules);

      // ---- İstatistik ----
      st.rounds++;
      if (sonuc != taktiksiz) st.flips++;
      if (acanKart.isLegend != cevapKart.isLegend && sonuc != taktiksiz) {
        st.legendViolations++;
      }
      st.used[acanTaktik] = st.used[acanTaktik]! + 1;
      st.used[cevapTaktik] = st.used[cevapTaktik]! + 1;
      final ka = '${acanKart.position}|${acanTaktik.name}';
      final kc = '${cevapKart.position}|${cevapTaktik.name}';
      st._say(st.usedByPos, ka);
      st._say(st.usedByPos, kc);
      if (sonuc > 0) st._say(st.wonByPos, ka);
      if (sonuc < 0) st._say(st.wonByPos, kc);
      if (sonuc > 0) st.wonWith[acanTaktik] = st.wonWith[acanTaktik]! + 1;
      if (sonuc < 0) st.wonWith[cevapTaktik] = st.wonWith[cevapTaktik]! + 1;

      oyuncular[acan].observeOpponent(cevapTaktik);
      oyuncular[cevap].observeOpponent(acanTaktik);

      // ---- Gerçek kurallar ----
      pot += 2;
      if (sonuc == 0) {
        acan = cevap; // beraberlikte sıra rakibe
      } else {
        final kazanan = sonuc > 0 ? acan : cevap;
        toplanan[kazanan] += pot;
        pot = 0;
        acan = switch (variant.leadRule) {
          LeadRule.winnerLeads => kazanan,
          LeadRule.alternate => cevap,
          LeadRule.loserLeads => 1 - kazanan,
        };
      }
    }

    final r = toplanan[0].compareTo(toplanan[1]);
    return MatchOutcome(r, toplanan[0], toplanan[1], st,
        firstLeaderIsA: ilkAcanA);
  }
}
