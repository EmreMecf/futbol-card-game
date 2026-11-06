import 'dart:math';

import 'simulation.dart';
import 'tactics.dart';

// =====================================================================
// EŞLEŞTİRME NÜFUS SİMÜLASYONU (oyunda YOK; karşılaştırma için)
// =====================================================================
// Kalıcı kadrolu oyuncular kuyruğa girer, eşleşir, oynar; MMR ±25.
// Bir zaman adımı = 10 saniye (find_match'teki genişleme adımıyla aynı).
//
// Bugünkü kural (006_rpc_matchmaking.sql):
//   |Δmmr| ≤ 200 + 50 × (bekleme / 10 sn)

enum MatchmakingMode {
  mmrOnly('Bugün: sadece MMR'),
  deckBand('MMR + kadro gücü bandı'),
  combined('Birleşik puan (MMR + kadro gücü)');

  final String label;
  const MatchmakingMode(this.label);
}

/// Kadro gücü bandı ayarları (MMR + kadro gücü bandı modu)
class DeckBandSettings {
  /// Başlangıçta izin verilen ortalama kadro gücü farkı
  final double startBand;

  /// Her 10 saniyelik beklemede bant bu kadar genişler
  final double widenPerStep;

  const DeckBandSettings({this.startBand = 3, this.widenPerStep = 0.5});
}

class MmPlayer {
  final int id;
  final String deckType;
  final List<SimCard> squad;
  final double deckPower;
  final String styleName;
  final TacticPolicy Function() style;
  int mmr = 1000;
  int played = 0;
  double score = 0;

  /// Sistem oturduktan SONRA katılan yeni oyuncu mu?
  bool newcomer = false;
  int newcomerMatches = 0;
  double newcomerScore = 0;
  int newcomerHopeless = 0;

  MmPlayer(this.id, this.deckType, this.squad, this.styleName, this.style)
      : deckPower = squad.map((c) => c.effectivePower).reduce((a, b) => a + b) /
            squad.length;
}

class MatchmakingResult {
  final MatchmakingMode mode;
  final int matches;
  final double avgWaitSec;
  final double p90WaitSec;

  /// Ortalama kadro gücü farkı 4+ olan maç oranı (~%70'e %30 sonuç)
  final double hopelessRate;

  /// Başlangıç kadrolu oyuncuların puanı
  final double starterScore;

  /// Başlangıç kadrolu oyuncuların kıdemliyle eşleştiği maç oranı
  final double starterVsVeteranShare;

  /// Ortalama MMR: tarz -> MMR, kadro tipi -> MMR
  final Map<String, double> mmrByStyle;
  final Map<String, double> mmrByDeck;

  /// YENİ GELEN: sistem oturduktan sonra başlangıç kadrosu ve 1000
  /// MMR ile katılanların İLK 20 maçı
  final double newcomerScore;
  final double newcomerHopeless;

  const MatchmakingResult({
    required this.mode,
    required this.matches,
    required this.avgWaitSec,
    required this.p90WaitSec,
    required this.hopelessRate,
    required this.starterScore,
    required this.starterVsVeteranShare,
    required this.mmrByStyle,
    required this.mmrByDeck,
    required this.newcomerScore,
    required this.newcomerHopeless,
  });

  /// Sıralama beceriyi mi kadroyu mu yansıtıyor?
  /// (Akıllı − Taktiksiz MMR farkı) / (Kıdemli − Başlangıç MMR farkı)
  /// > 1: beceri kadrodan daha belirleyici.
  double get skillOverDeck {
    final beceri = (mmrByStyle['Akıllı'] ?? 0) - (mmrByStyle['Taktiksiz'] ?? 0);
    final kadro = (mmrByDeck['Kıdemli'] ?? 0) - (mmrByDeck['Başlangıç'] ?? 0);
    return kadro.abs() < 1 ? double.infinity : beceri / kadro;
  }
}

/// Nüfus: %30 başlangıç, %45 orta, %25 kıdemli kadro; tarzlar eşit.
List<MmPlayer> buildPopulation(Random rng, {int size = 240}) {
  final tarzlar = <(String, TacticPolicy Function())>[
    ('Taktiksiz', NoTacticPolicy.new),
    ('Rastgele', RandomPolicy.new),
    ('Akıllı', SmartPolicy.new),
  ];
  return [
    for (var i = 0; i < size; i++)
      () {
        final r = rng.nextDouble();
        final (tip, profil) = r < 0.30
            ? ('Başlangıç', SquadProfile.starter)
            : r < 0.75
                ? ('Orta', SquadProfile.standard)
                : ('Kıdemli', SquadProfile.veteran);
        final (ad, f) = tarzlar[i % tarzlar.length];
        return MmPlayer(i, tip, profil.build(rng), ad, f);
      }(),
  ];
}

bool _uygun(MatchmakingMode m, MmPlayer a, MmPlayer b, int bekleme,
    DeckBandSettings band) {
  final dMmr = (a.mmr - b.mmr).abs();
  final dGuc = (a.deckPower - b.deckPower).abs();
  final mmrOk = dMmr <= 200 + 50 * bekleme;
  return switch (m) {
    MatchmakingMode.mmrOnly => mmrOk,
    MatchmakingMode.deckBand =>
      mmrOk && dGuc <= band.startBand + band.widenPerStep * bekleme,
    MatchmakingMode.combined => dMmr / 100 + dGuc / 1.5 <= 2 + 0.5 * bekleme,
  };
}

double _uzaklik(MatchmakingMode m, MmPlayer a, MmPlayer b) {
  final dMmr = (a.mmr - b.mmr).abs().toDouble();
  final dGuc = (a.deckPower - b.deckPower).abs();
  return switch (m) {
    MatchmakingMode.mmrOnly => dMmr,
    MatchmakingMode.deckBand => dMmr / 100 + dGuc,
    MatchmakingMode.combined => dMmr / 100 + dGuc / 1.5,
  };
}

MatchmakingResult simulateMatchmaking(
  MatchmakingMode mode, {
  int seed = 11,
  int steps = 2500,
  int population = 240,
  double joinChance = 0.12,
  DeckBandSettings band = const DeckBandSettings(),
  TacticRules rules = TacticRules.balanced,
}) {
  final rng = Random(seed);
  final oyuncular = buildPopulation(rng, size: population);
  // Yeni gelenler: sistemin yarısında, nüfusun %10'u kadar, başlangıç
  // kadrosuyla ve 1000 MMR ile katılır (tarzlar eşit dağılır).
  final yeniler = [
    for (var i = 0; i < max(6, population ~/ 10); i++)
      MmPlayer(
        population + i,
        'Başlangıç',
        SquadProfile.starter.build(rng),
        ['Taktiksiz', 'Rastgele', 'Akıllı'][i % 3],
        [NoTacticPolicy.new, RandomPolicy.new, SmartPolicy.new][i % 3],
      )..newcomer = true,
  ];
  final sim = MatchSimulator(rules: rules, rng: rng);
  final kuyruk = <MmPlayer, int>{}; // oyuncu -> kuyruğa girdiği adım
  final bekleyenler = <int>[];
  var maclar = 0, umutsuz = 0, basKid = 0, basMac = 0;
  var basPuan = 0.0;

  for (var t = 0; t < steps; t++) {
    if (t == steps ~/ 2) oyuncular.addAll(yeniler);
    for (final o in oyuncular) {
      if (!kuyruk.containsKey(o) && rng.nextDouble() < joinChance) kuyruk[o] = t;
    }
    final sira = kuyruk.keys.toList()..sort((a, b) => kuyruk[a]!.compareTo(kuyruk[b]!));
    final eslesti = <MmPlayer>{};
    for (final a in sira) {
      if (eslesti.contains(a)) continue;
      MmPlayer? enIyi;
      var enIyiUz = double.infinity;
      for (final b in sira) {
        if (identical(a, b) || eslesti.contains(b)) continue;
        final bekleme = max(t - kuyruk[a]!, t - kuyruk[b]!);
        if (!_uygun(mode, a, b, bekleme, band)) continue;
        final uz = _uzaklik(mode, a, b);
        if (uz < enIyiUz) {
          enIyi = b;
          enIyiUz = uz;
        }
      }
      if (enIyi == null) continue;
      final b = enIyi;
      eslesti..add(a)..add(b);
      bekleyenler..add(t - kuyruk[a]!)..add(t - kuyruk[b]!);

      final s = sim.playSquads(a.style(), b.style(), a.squad, b.squad);
      maclar++;
      if ((a.deckPower - b.deckPower).abs() >= 4) umutsuz++;
      final pa = s.result > 0 ? 1.0 : (s.result == 0 ? 0.5 : 0.0);
      for (final (o, p) in [(a, pa), (b, 1 - pa)]) {
        o.played++;
        o.score += p;
        if (p == 1) o.mmr += 25;
        if (p == 0) o.mmr = max(0, o.mmr - 25);
        if (o.newcomer && o.newcomerMatches < 20) {
          o.newcomerMatches++;
          o.newcomerScore += p;
          if ((a.deckPower - b.deckPower).abs() >= 4) o.newcomerHopeless++;
        }
        if (o.deckType == 'Başlangıç') {
          basMac++;
          basPuan += p;
          final rakip = identical(o, a) ? b : a;
          if (rakip.deckType == 'Kıdemli') basKid++;
        }
      }
    }
    for (final o in eslesti) {
      kuyruk.remove(o);
    }
  }

  bekleyenler.sort();
  Map<String, double> ort(String Function(MmPlayer) anahtar) {
    final g = <String, List<int>>{};
    for (final o in oyuncular) {
      g.putIfAbsent(anahtar(o), () => []).add(o.mmr);
    }
    return {for (final e in g.entries) e.key: e.value.reduce((a, b) => a + b) / e.value.length};
  }

  return MatchmakingResult(
    mode: mode,
    matches: maclar,
    avgWaitSec: bekleyenler.isEmpty ? 0 : bekleyenler.reduce((a, b) => a + b) / bekleyenler.length * 10,
    p90WaitSec: bekleyenler.isEmpty ? 0 : bekleyenler[(bekleyenler.length * 0.9).floor()] * 10.0,
    hopelessRate: maclar == 0 ? 0 : umutsuz / maclar,
    starterScore: basMac == 0 ? 0 : basPuan / basMac,
    starterVsVeteranShare: basMac == 0 ? 0 : basKid / basMac,
    mmrByStyle: ort((o) => o.styleName),
    mmrByDeck: ort((o) => o.deckType),
    newcomerScore: _oran(yeniler, (o) => o.newcomerScore),
    newcomerHopeless: _oran(yeniler, (o) => o.newcomerHopeless.toDouble()),
  );
}

double _oran(List<MmPlayer> l, double Function(MmPlayer) f) {
  final mac = l.fold<int>(0, (t, o) => t + o.newcomerMatches);
  return mac == 0 ? 0 : l.fold<double>(0, (t, o) => t + f(o)) / mac;
}
