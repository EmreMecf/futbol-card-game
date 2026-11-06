import 'dart:math';

import 'simulation.dart';
import 'tactics.dart';

// =====================================================================
// EKONOMİ SİMÜLASYONU (oyunda YOK; karşılaştırma için)
// =====================================================================
// Gerçek oyun sayıları (veritabanından):
//   * Başlangıç: 1000 coin + 15 kartlık başlangıç paketi
//   * Galibiyet: +100 coin, +25 MMR, +1 koruma hakkı (en fazla 10)
//   * Mağlubiyet: -25 MMR; BUGÜN korunmayan kadro kartlarından 3'ü
//     KALICI olarak kazanana geçer (007 _finish_match)
//   * Standart paket: 500 coin, 5 kart (Bronz %55, Gümüş %30, Altın %13,
//     Diamond %1,9, Legend %0,1) — 011_packs_and_drop_rates.sql
//
// Basitleştirmeler (raporda belirtilir): oyuncular coin yettikçe
// standart paket alır; en güçlü kartlarını korur; kadro her maçtan önce
// koleksiyonun en iyi 1-4-4-2'sinden kurulur; kimya rastgele 0-6.

enum LossRule {
  live3('Bugün: kaybeden 3 korumasız kartını kaybeder'),
  none('Kalıcı kayıp yok'),
  noneWithReward('Kayıp yok + kazanana 1 ödül kartı'),
  one('Kaybeden 1 kart kaybeder');

  final String label;
  const LossRule(this.label);
}

class EcoCard {
  final String position;
  final String tier;
  final int power; // güç + kimya
  const EcoCard(this.position, this.tier, this.power);
  SimCard get sim => SimCard(position, power, isLegend: tier == 'legend');
}

const Map<String, int> kStandardPackWeights = {
  'bronze': 5500,
  'silver': 3000,
  'gold': 1300,
  'diamond': 190,
  'legend': 10,
};

/// Katalogdaki mevki dağılımı (yaklaşık)
const Map<String, int> kPositionWeights = {'GK': 10, 'DEF': 35, 'MID': 35, 'FWD': 20};

const Map<String, int> kFormationNeeds = {'GK': 1, 'DEF': 4, 'MID': 4, 'FWD': 2};

String _agirlikli(Random r, Map<String, int> w) {
  final top = w.values.reduce((a, b) => a + b);
  var x = r.nextInt(top);
  for (final e in w.entries) {
    if (x < e.value) return e.key;
    x -= e.value;
  }
  return w.keys.first;
}

EcoCard _kart(Random r, String tier, String pos) {
  final (lo, hi) = kTierPower[tier]!;
  return EcoCard(pos, tier, lo + r.nextInt(hi - lo + 1) + r.nextInt(7));
}

class EcoPlayer {
  final int id;
  final String styleName;
  final TacticPolicy Function() style;
  final List<EcoCard> cards;
  int coins = 1000;
  int protection = 3;
  int mmr = 1000;
  int played = 0;
  double score = 0;
  final bool newcomer;
  int newcomerMatches = 0;
  double newcomerScore = 0;

  EcoPlayer(this.id, this.styleName, this.style, this.cards,
      {this.newcomer = false});

  /// Koleksiyonun en iyi 1-4-4-2'si; eksik mevki varsa null
  List<EcoCard>? deck() {
    final sonuc = <EcoCard>[];
    for (final e in kFormationNeeds.entries) {
      final aday = cards.where((c) => c.position == e.key).toList()
        ..sort((a, b) => b.power.compareTo(a.power));
      if (aday.length < e.value) return null;
      sonuc.addAll(aday.take(e.value));
    }
    return sonuc;
  }

  /// Korunacak kartlar: önce YEDEĞİ OLMAYAN mevkilerin kadro kartları
  /// (kaybedilirse kadro bozulur), sonra en güçlüler. Canlı kural için
  /// en iyimser oyuncu davranışı.
  List<EcoCard> protectedCards(List<EcoCard> deste) {
    final kritik = deste.where((c) =>
        cards.where((x) => x.position == c.position).length <=
        kFormationNeeds[c.position]!);
    final sira = [
      ...kritik,
      ...([...deste]..sort((a, b) => b.power.compareTo(a.power)))
          .where((c) => !kritik.contains(c)),
    ];
    return sira.take(protection).toList();
  }

  double get deckPower {
    final d = deck();
    if (d == null) return 0;
    return d.map((c) => c.power).reduce((a, b) => a + b) / d.length;
  }
}

/// Başlangıç paketi: GERÇEK oyundaki gibi 15 kart, her mevkide 1 yedek
/// (2 kaleci, 5 defans, 5 orta saha, 3 forvet); Bronz/Gümüş/Altın.
const Map<String, int> kStarterPositions = {'GK': 2, 'DEF': 5, 'MID': 5, 'FWD': 3};

List<EcoCard> starterCollection(Random r) {
  const w = {'bronze': 50, 'silver': 40, 'gold': 10};
  return [
    for (final e in kStarterPositions.entries)
      for (var i = 0; i < e.value; i++) _kart(r, _agirlikli(r, w), e.key),
  ];
}

EcoCard _paketKarti(Random r) =>
    _kart(r, _agirlikli(r, kStandardPackWeights), _agirlikli(r, kPositionWeights));

class EconomyResult {
  final LossRule rule;
  final int rounds;

  /// Kadro gücü dağılımı (oynayabilen oyuncular)
  final double meanDeck;
  final double p10Deck;
  final double p90Deck;

  /// Kadrosu eksik kaldığı için oynayamayan oyuncu oranı (sonda)
  final double stuckRate;

  /// Oyuncu başına kart sayısı (sonda) ve Legend sayısı
  final double cardsPerPlayer;
  final double legendsPerPlayer;

  /// "Zengin daha zengin" etkisi: en çok kazanan %20'nin ve en az
  /// kazanan %20'nin kadro gücü artışı (oynayabilenler arasında)
  final double topGrowth;
  final double bottomGrowth;

  /// Sonradan katılan yeni oyuncuların ilk 20 maçtaki puanı
  final double newcomerScore;

  /// Kart el değiştirme sayısı (oyuncu başına)
  final double transfersPerPlayer;

  const EconomyResult({
    required this.rule,
    required this.rounds,
    required this.meanDeck,
    required this.p10Deck,
    required this.p90Deck,
    required this.stuckRate,
    required this.cardsPerPlayer,
    required this.legendsPerPlayer,
    required this.topGrowth,
    required this.bottomGrowth,
    required this.newcomerScore,
    required this.transfersPerPlayer,
  });

  double get spread => p90Deck - p10Deck;
}

EconomyResult simulateEconomy(
  LossRule rule, {
  int seed = 23,
  int players = 160,
  int rounds = 120,
  TacticRules rules = TacticRules.balanced,
  /// true: eşleştirme MMR + kadro gücüne bakar (024 'combined' modu)
  bool deckAwarePairing = false,
}) {
  final rng = Random(seed);
  final sim = MatchSimulator(rules: rules, rng: rng);
  final tarzlar = <(String, TacticPolicy Function())>[
    ('Taktiksiz', NoTacticPolicy.new),
    ('Rastgele', RandomPolicy.new),
    ('Akıllı', SmartPolicy.new),
  ];
  EcoPlayer yeni(int i, {bool newcomer = false}) {
    final (ad, f) = tarzlar[i % 3];
    return EcoPlayer(i, ad, f, starterCollection(rng), newcomer: newcomer);
  }

  final oyuncular = [for (var i = 0; i < players; i++) yeni(i)];
  final baslangicGucu = {for (final o in oyuncular) o: o.deckPower};
  var transfer = 0;

  void paketAl(EcoPlayer o) {
    while (o.coins >= 500) {
      o.coins -= 500;
      for (var i = 0; i < 5; i++) {
        o.cards.add(_paketKarti(rng));
      }
    }
  }

  for (var tur = 0; tur < rounds; tur++) {
    // Yeni oyuncular sistemin ortasında katılır
    if (tur == rounds ~/ 2) {
      for (var i = 0; i < players ~/ 10; i++) {
        final o = yeni(players + i, newcomer: true);
        oyuncular.add(o);
        baslangicGucu[o] = o.deckPower;
      }
    }
    for (final o in oyuncular) {
      paketAl(o);
    }
    // Oynayabilenler MMR'a göre sıralanıp komşularıyla eşleşir
    double anahtar(EcoPlayer o) =>
        deckAwarePairing ? o.mmr / 100 + o.deckPower / 1.5 : o.mmr.toDouble();
    final aktif = oyuncular.where((o) => o.deck() != null).toList()
      ..shuffle(rng)
      ..sort((a, b) => anahtar(a).compareTo(anahtar(b)));
    for (var i = 0; i + 1 < aktif.length; i += 2) {
      final a = aktif[i], b = aktif[i + 1];
      final da = a.deck()!, db = b.deck()!;
      final s = sim.playSquads(a.style(), b.style(),
          da.map((c) => c.sim).toList(), db.map((c) => c.sim).toList());
      if (s.result == 0) {
        for (final o in [a, b]) {
          o.played++;
          o.score += 0.5;
          if (o.newcomer && o.newcomerMatches < 20) {
            o.newcomerMatches++;
            o.newcomerScore += 0.5;
          }
        }
        continue;
      }
      final kaz = s.result > 0 ? a : b;
      final kay = s.result > 0 ? b : a;
      final kayDeste = s.result > 0 ? db : da;
      for (final (o, p) in [(kaz, 1.0), (kay, 0.0)]) {
        o.played++;
        o.score += p;
        if (o.newcomer && o.newcomerMatches < 20) {
          o.newcomerMatches++;
          o.newcomerScore += p;
        }
      }
      kaz.coins += 100;
      kaz.mmr += 25;
      kaz.protection = min(10, kaz.protection + 1);
      kay.mmr = max(0, kay.mmr - 25);

      final kayip = switch (rule) {
        LossRule.live3 => 3,
        LossRule.one => 1,
        _ => 0,
      };
      if (kayip > 0) {
        // Kaybeden kritik ve en güçlü kartlarını korur; korumasızlardan
        // rastgele 3'ü gider (007 _finish_match)
        final korunan = kay.protectedCards(kayDeste);
        final korumasiz = kayDeste.where((c) => !korunan.contains(c)).toList()
          ..shuffle(rng);
        for (final c in korumasiz.take(kayip)) {
          kay.cards.remove(c);
          kaz.cards.add(c);
          transfer++;
        }
      }
      if (rule == LossRule.noneWithReward) kaz.cards.add(_paketKarti(rng));
    }
  }

  final guc = oyuncular.map((o) => o.deckPower).where((g) => g > 0).toList()..sort();
  double yuzdelik(double p) => guc.isEmpty ? 0 : guc[(guc.length * p).floor().clamp(0, guc.length - 1)];
  // Zengin daha mı zenginleşiyor? En çok kazanan %20 ile en az kazanan
  // %20'nin kadro gücü artışı (oynayamayanların gücü 0 sayılmaz;
  // onlar [stuckRate]'te ayrıca raporlanıyor).
  final eskiler = oyuncular
      .where((o) => !o.newcomer && o.deck() != null && o.played > 0)
      .toList()
    ..sort((a, b) => (b.score / b.played).compareTo(a.score / a.played));
  final dilim = max(1, eskiler.length ~/ 5);
  final ust = eskiler.take(dilim);
  final alt = eskiler.reversed.take(dilim);
  double artis(Iterable<EcoPlayer> l) => l.isEmpty
      ? 0
      : l.map((o) => o.deckPower - baslangicGucu[o]!).reduce((a, b) => a + b) /
          l.length;
  final yeniler = oyuncular.where((o) => o.newcomer);
  final yeniMac = yeniler.fold<int>(0, (t, o) => t + o.newcomerMatches);

  return EconomyResult(
    rule: rule,
    rounds: rounds,
    meanDeck: guc.isEmpty ? 0 : guc.reduce((a, b) => a + b) / guc.length,
    p10Deck: yuzdelik(0.10),
    p90Deck: yuzdelik(0.90),
    stuckRate: oyuncular.where((o) => o.deck() == null).length / oyuncular.length,
    cardsPerPlayer: oyuncular.fold<int>(0, (t, o) => t + o.cards.length) / oyuncular.length,
    legendsPerPlayer: oyuncular.fold<int>(0, (t, o) => t + o.cards.where((c) => c.tier == 'legend').length) /
        oyuncular.length,
    topGrowth: artis(ust),
    bottomGrowth: artis(alt),
    newcomerScore: yeniMac == 0 ? 0 : yeniler.fold<double>(0, (t, o) => t + o.newcomerScore) / yeniMac,
    transfersPerPlayer: transfer / players,
  );
}
