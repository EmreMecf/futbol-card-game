import 'dart:math';

import 'simulation.dart';
import 'tactics.dart';

/// DENGE ÖLÇÜMÜ
///
/// Hedefler ÖNCEDEN ve SAYIYLA tanımlı ([BalanceTargets]). Sonuçlara
/// bakıp "iyi görünüyor" demek yerine her hedef ya tutuyor ya tutmuyor.
/// Raporda ikisi de yazılıyor.

/// Denge hedefleri — MD bölüm 2 ve 7'den türetildi.
class BalanceTargets {
  const BalanceTargets._();

  /// "Tek numara" (hep aynı taktiği basan) bir tarz, diğer HER tarzı
  /// bundan fazla yenmemeli. Yenerse o taktik "her zaman doğru cevap"
  /// demektir; MD bunu açıkça istemiyor.
  static const double maxOneTrickWinRate = 0.60;

  /// Akıllı oyuncu taktiksizi en az bu kadar yenmeli: taktik bilgi ve
  /// karar gerektiriyor, "ustalaşması zaman alan" (MD bölüm 2).
  static const double minSkillWinRate = 0.55;

  /// ...ama bundan fazla değil: kart gücü hâlâ asıl belirleyici olmalı.
  /// Taktik kullanmayan yeni oyuncu ezilmemeli.
  static const double maxSkillWinRate = 0.72;

  /// Taktiklerin turu çevirme oranı bu aralıkta olmalı.
  /// Çok düşükse taktik süs; çok yüksekse kart gücü anlamsız.
  /// MD: "basit kart karşılaştırmasını daha stratejik hale getirmek"
  /// — yerine geçmek değil.
  static const double minFlipRate = 0.05;
  static const double maxFlipRate = 0.20;

  /// Legend kuralı ihlali: kesinlikle sıfır.
  static const int maxLegendViolations = 0;
}

class PairResult {
  final String a;
  final String b;
  final int matches;
  final int winsA;
  final int winsB;
  final int draws;

  const PairResult(this.a, this.b, this.matches, this.winsA, this.winsB,
      this.draws);

  /// A'nın puan oranı (beraberlik yarım sayılır)
  double get scoreA => (winsA + draws * 0.5) / matches;
}

class BalanceCheck {
  final String name;
  final String value;
  final String target;
  final bool passed;

  const BalanceCheck(this.name, this.value, this.target, this.passed);
}

class BalanceReport {
  final TacticRules rules;
  final int matchesPerPair;
  final int seed;
  final List<String> policyNames;

  /// [a][b] = a'nın b'ye karşı puan oranı
  final Map<String, Map<String, double>> matrix;
  final MatchStats stats;
  final List<BalanceCheck> checks;

  const BalanceReport({
    required this.rules,
    required this.matchesPerPair,
    required this.seed,
    required this.policyNames,
    required this.matrix,
    required this.stats,
    required this.checks,
  });

  bool get allPassed => checks.every((c) => c.passed);
}

/// Her tarz çiftini [matchesPerPair] maç oynatır (koltuklar dönüşümlü).
PairResult playPair(
  TacticPolicy Function() a,
  TacticPolicy Function() b, {
  required int matches,
  required TacticRules rules,
  required Random rng,
  MatchStats? into,
}) {
  final sim = MatchSimulator(rules: rules, rng: rng);
  var ka = 0, kb = 0, ber = 0;
  final pa = a(), pb = b();
  for (var i = 0; i < matches; i++) {
    // Koltuk değişimi: ilk açan rastgele ama A/B sırası da dönsün
    final ters = i.isOdd;
    final s = ters ? sim.play(pb, pa) : sim.play(pa, pb);
    into?.merge(s.stats);
    final r = ters ? -s.result : s.result;
    if (r > 0) {
      ka++;
    } else if (r < 0) {
      kb++;
    } else {
      ber++;
    }
  }
  return PairResult(pa.name, pb.name, matches, ka, kb, ber);
}

/// Standart tarz listesi
List<TacticPolicy Function()> standardPolicies() => [
      NoTacticPolicy.new,
      RandomPolicy.new,
      () => AlwaysPolicy(Tactic.highPress),
      () => AlwaysPolicy(Tactic.counterAttack),
      () => AlwaysPolicy(Tactic.defensiveWall),
      AdaptivePolicy.new,
      SmartPolicy.new,
    ];

BalanceReport runBalance({
  TacticRules rules = TacticRules.balanced,
  int matchesPerPair = 2000,
  int seed = 2026,
}) {
  final rng = Random(seed);
  final tarzlar = standardPolicies();
  final adlar = [for (final t in tarzlar) t().name];
  final matris = <String, Map<String, double>>{
    for (final a in adlar) a: {},
  };
  final toplam = MatchStats();

  for (var i = 0; i < tarzlar.length; i++) {
    for (var j = i + 1; j < tarzlar.length; j++) {
      final r = playPair(tarzlar[i], tarzlar[j],
          matches: matchesPerPair, rules: rules, rng: rng, into: toplam);
      matris[r.a]![r.b] = r.scoreA;
      matris[r.b]![r.a] = 1 - r.scoreA;
    }
  }

  return BalanceReport(
    rules: rules,
    matchesPerPair: matchesPerPair,
    seed: seed,
    policyNames: adlar,
    matrix: matris,
    stats: toplam,
    checks: _kontroller(matris, toplam),
  );
}

List<BalanceCheck> _kontroller(
  Map<String, Map<String, double>> m,
  MatchStats st,
) {
  String yuzde(double x) => '%${(x * 100).toStringAsFixed(1)}';
  final sonuc = <BalanceCheck>[];

  // 1) Hiçbir "tek numara" herkesi ezmiyor
  for (final t in [Tactic.highPress, Tactic.counterAttack, Tactic.defensiveWall]) {
    final ad = 'Hep ${t.label}';
    final enKotu = m[ad]!.values.reduce(min);
    final hepsiniYeniyor = enKotu > BalanceTargets.maxOneTrickWinRate;
    sonuc.add(BalanceCheck(
      '"$ad" herkesi ezmiyor',
      'en zayıf eşleşmesi ${yuzde(enKotu)}',
      'en az bir eşleşmede ≤ ${yuzde(BalanceTargets.maxOneTrickWinRate)}',
      !hepsiniYeniyor,
    ));
  }

  // 2) Taş-kâğıt-makas: her "tek numara"nın yenildiği bir rakip var
  for (final t in [Tactic.highPress, Tactic.counterAttack, Tactic.defensiveWall]) {
    final ad = 'Hep ${t.label}';
    final karsi = 'Hep ${t.beatenBy!.label}';
    final oran = m[karsi]![ad]!;
    sonuc.add(BalanceCheck(
      '"$karsi", "$ad"ı yener',
      yuzde(oran),
      '> %50',
      oran > 0.5,
    ));
  }

  // 3) Beceri ödüllendiriliyor ama ezmiyor
  final beceri = m['Akıllı']!['Taktiksiz']!;
  sonuc.add(BalanceCheck(
    'Akıllı oyuncu taktiksizi yener',
    yuzde(beceri),
    '${yuzde(BalanceTargets.minSkillWinRate)} – '
        '${yuzde(BalanceTargets.maxSkillWinRate)}',
    beceri >= BalanceTargets.minSkillWinRate &&
        beceri <= BalanceTargets.maxSkillWinRate,
  ));

  // 4) Kart gücü hâlâ asıl belirleyici
  final cevirme = st.flips / st.rounds;
  sonuc.add(BalanceCheck(
    'Taktiklerin turu çevirme oranı',
    yuzde(cevirme),
    '${yuzde(BalanceTargets.minFlipRate)} – ${yuzde(BalanceTargets.maxFlipRate)}',
    cevirme >= BalanceTargets.minFlipRate &&
        cevirme <= BalanceTargets.maxFlipRate,
  ));

  // 5) Legend kuralı bozulmadı
  sonuc.add(BalanceCheck(
    'Legend kuralı ihlali',
    '${st.legendViolations} / ${st.rounds} tur',
    '0',
    st.legendViolations <= BalanceTargets.maxLegendViolations,
  ));

  return sonuc;
}

// ====================================================================
// RAPOR (Markdown, Türkçe)
// ====================================================================
String renderReport(BalanceReport r) {
  String yuzde(double x) => '%${(x * 100).toStringAsFixed(1)}';
  final b = StringBuffer();
  final k = r.rules;

  b.writeln('# Taktik Sistemi — Denge Raporu (PROTOTİP)');
  b.writeln();
  b.writeln('> **Bu sistem oyunda AKTİF DEĞİL.** Gerçek maç kuralları '
      '(`_resolve_round`, `compare_cards`) değişmedi. Bu rapor, taktik '
      'fikrinin dengeli olup olmadığını simülasyonla ölçmek için üretildi. '
      'Oyuna alınıp alınmayacağına karar sizin.');
  b.writeln();
  b.writeln('Rapor `dart run bin/simulate.dart` ile üretildi. '
      'Tohum: `${r.seed}` (aynı tohum = aynı sonuç). '
      'Her tarz çifti için **${r.matchesPerPair}** maç, toplam '
      '**${r.stats.rounds}** tur.');
  b.writeln();

  b.writeln('## Sonuç: ${r.allPassed ? '✅ Bütün denge hedefleri tuttu' : '❌ Bazı hedefler tutmadı'}');
  b.writeln();
  b.writeln('| Kontrol | Ölçülen | Hedef | Durum |');
  b.writeln('|---|---|---|---|');
  for (final c in r.checks) {
    b.writeln('| ${c.name} | ${c.value} | ${c.target} | ${c.passed ? '✅' : '❌'} |');
  }
  b.writeln();

  b.writeln('## Taktikler');
  b.writeln();
  b.writeln('| Taktik | Enerji | Etki | Güçlü olduğu durum | Zayıf olduğu durum | Kırdığı | Kırıldığı |');
  b.writeln('|---|---|---|---|---|---|---|');
  b.writeln('| 🔥 Yüksek Pres | ${k.pressCost} | +${k.pressBonus} güç | '
      'Rakip duvar kurduğunda ya da taktik kullanmadığında | '
      'Rakip kontraya çıkarsa bonus SIFIR, üstelik rakip +${k.counterVsPressBonus} alır; en pahalı taktik | '
      'Savunma Duvarı | Kontra Atak |');
  b.writeln('| ⚡ Kontra Atak | ${k.counterCost} | +${k.counterBaseBonus} (rakip pres yaparsa +${k.counterVsPressBonus}) | '
      'Rakip pres yaptığında | Tek başına neredeyse etkisiz; duvara çarparsa SIFIR | '
      'Yüksek Pres | Savunma Duvarı |');
  b.writeln('| 🛡️ Savunma Duvarı | ${k.wallCost} | Savunurken +${k.wallDefendBonus}, turu açarken +${k.wallLeadBonus} | '
      'Turu rakip açtığında (savunma) | Turu sen açarken zayıf; pres onu SIFIRLAR | '
      'Kontra Atak | Yüksek Pres |');
  b.writeln();
  b.writeln('**Enerji:** Maça ${k.startEnergy} enerjiyle başlanır, her tur '
      '+${k.energyPerRound}, en fazla ${k.maxEnergy}. Harcanmayan enerji '
      'birikir. İki tarafın enerjisi de herkese açık.');
  b.writeln();
  b.writeln('**Bilgi:** Turu açan, kartını ve taktiğini gizli seçer. '
      'Cevap veren rakibin kartını görür ama taktiğini görmez. '
      'Taktikler tur çözülürken aynı anda açılır.');
  b.writeln();
  b.writeln('**Korunan kurallar:** Aynı mevki zorunluluğu, Legend kuralı '
      '(taktik bunu aşamaz), beraberlik/pot kuralı ve maç bitirme kuralı '
      'değişmedi.');
  b.writeln();

  b.writeln('## Tarzlar arası kazanma oranı');
  b.writeln();
  b.writeln('Satırdaki tarzın sütundaki tarza karşı puanı '
      '(galibiyet = 1, beraberlik = ½).');
  b.writeln();
  b.write('| |');
  for (final a in r.policyNames) {
    b.write(' $a |');
  }
  b.writeln();
  b.write('|---|');
  for (var i = 0; i < r.policyNames.length; i++) {
    b.write('---|');
  }
  b.writeln();
  for (final a in r.policyNames) {
    b.write('| **$a** |');
    for (final c in r.policyNames) {
      b.write(a == c ? ' — |' : ' ${yuzde(r.matrix[a]![c]!)} |');
    }
    b.writeln();
  }
  b.writeln();
  b.writeln('**Tarzlar:** *Taktiksiz* = bugünkü oyun. *Rastgele* = acemi. '
      '*Hep X* = gücü yettikçe hep aynı taktik. *Uyarlanır* = rakibin '
      'en çok kullandığı taktiğin karşısını seçer. *Akıllı* = rakibin '
      'kartını görüp hesap yapar, enerji saklar. Kart seçimi bütün '
      'tarzlarda aynı; fark sadece taktik kararlarından geliyor.');
  b.writeln();

  b.writeln('## Taktik kullanımı');
  b.writeln();
  b.writeln('| Taktik | Kullanıldığı tur | O turu kazanma oranı |');
  b.writeln('|---|---|---|');
  for (final t in Tactic.values) {
    final u = r.stats.used[t]!;
    final w = r.stats.wonWith[t]!;
    b.writeln('| ${t.label} | $u | ${u == 0 ? '—' : yuzde(w / u)} |');
  }
  b.writeln();

  return b.toString();
}
