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

  // ---- Genişletilmiş hedefler (bağımsız inceleme, madde 1) ----

  /// Basit (bilgi kullanmayan) bir tarz, diğer HER tarzı yenmemeli.
  /// "Hep pres bas" gibi bir tarifin herkese karşı %50+ alması, oyunun
  /// tek doğru cevabı olduğu anlamına gelir.
  static const double maxSimpleDominance = 0.50;

  /// Her tek-taktik / enerji tarzının, ona karşı en az bu kadar iyi bir
  /// cevabı olmalı (sömürülebilir olmalı).
  static const double maxExploitableFloor = 0.45;

  /// Taktik kullanmayan (yeni) oyuncunun en kötü eşleşmesi.
  static const double minNoTacticFloor = 0.30;

  /// İlk turu açanın puanı bu aralıkta olmalı.
  static const double minFirstLeader = 0.45;
  static const double maxFirstLeader = 0.55;

  /// Taktikler kart gücü farkını büyütmemeli/kapatmamalı: aynı güç
  /// farkında "ikisi de taktiksiz" ile "ikisi de Akıllı" arasındaki fark.
  static const double maxTacticGapShift = 0.05;

  /// Başlangıç kadrosu kıdemli kadroya karşı en az bu kadar şans
  /// bulmalı (yoksa eşleştirme kadro gücüne bakmalı).
  static const double minStarterVsVeteran = 0.10;
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

  /// true  = ZORUNLU: tutmazsa test kırılır.
  /// false = İZLENEN: ölçülür ve raporda ❌ görünür; çözümü temel kural
  ///         ya da eşleştirme değişikliği gerektirdiği için kullanıcı
  ///         onayını bekler. "Geçti" sayılmaz.
  final bool required;

  const BalanceCheck(this.name, this.value, this.target, this.passed,
      {this.required = true});
}

/// Genişletilmiş senaryo ölçümleri (eşit olmayan oyuncular)
class ScenarioResults {
  /// İlk açanın puanı: tarz adı -> puan
  final Map<String, double> firstLeader;

  /// Güç farkı g -> (ikisi taktiksiz, ikisi Akıllı) güçlü tarafın puanı
  final Map<int, (double, double)> powerGap;

  /// Başlangıç vs Kıdemli: senaryo -> başlangıç kadrosunun puanı
  final Map<String, double> rarity;

  const ScenarioResults(this.firstLeader, this.powerGap, this.rarity);
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
  final ScenarioResults scenarios;

  const BalanceReport({
    required this.rules,
    required this.matchesPerPair,
    required this.seed,
    required this.policyNames,
    required this.matrix,
    required this.stats,
    required this.checks,
    required this.scenarios,
  });

  /// ZORUNLU hedeflerin hepsi tuttu mu?
  bool get allRequiredPassed =>
      checks.where((c) => c.required).every((c) => c.passed);

  /// Hepsi (izlenenler dahil) tuttu mu?
  bool get allPassed => checks.every((c) => c.passed);

  /// Tutmayan izlenen hedefler (kullanıcı kararı bekleyen)
  List<BalanceCheck> get openIssues =>
      checks.where((c) => !c.required && !c.passed).toList();
}

/// Her tarz çiftini [matchesPerPair] maç oynatır (koltuklar dönüşümlü).
PairResult playPair(
  TacticPolicy Function() a,
  TacticPolicy Function() b, {
  required int matches,
  required TacticRules rules,
  required Random rng,
  MatchStats? into,
  SquadProfile squadA = SquadProfile.standard,
  SquadProfile squadB = SquadProfile.standard,
  void Function(bool aLedFirst, int result)? onMatch,
}) {
  final sim = MatchSimulator(rules: rules, rng: rng);
  var ka = 0, kb = 0, ber = 0;
  final pa = a(), pb = b();
  for (var i = 0; i < matches; i++) {
    // Koltuk değişimi: ilk açan rastgele ama A/B sırası da dönsün
    final ters = i.isOdd;
    final s = ters
        ? sim.play(pb, pa, squadA: squadB, squadB: squadA)
        : sim.play(pa, pb, squadA: squadA, squadB: squadB);
    into?.merge(s.stats);
    final r = ters ? -s.result : s.result;
    onMatch?.call(ters ? !s.firstLeaderIsA : s.firstLeaderIsA, r);
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
      HoarderPolicy.new,
      SpenderPolicy.new,
      AdaptivePolicy.new,
      SmartPolicy.new,
    ];

/// Bilgi kullanmayan ("tarif") tarzlar: hiçbiri baskın olmamalı.
/// Akıllı ve Uyarlanır rakibi okuyor; onların öne geçmesi BECERİ.
const simplePolicyNames = [
  'Taktiksiz',
  'Rastgele',
  'Hep Yüksek Pres',
  'Hep Kontra Atak',
  'Hep Savunma Duvarı',
  'Biriktirici',
  'Harcayıcı',
];

/// Sömürülebilir olması gereken tarzlar (tek numara + enerji davranışı)
const exploitablePolicyNames = [
  'Hep Yüksek Pres',
  'Hep Kontra Atak',
  'Hep Savunma Duvarı',
  'Biriktirici',
  'Harcayıcı',
];

/// Eşit olmayan oyuncular: ilk açan, güç farkı, nadirlik.
ScenarioResults runScenarios({
  required TacticRules rules,
  required int matches,
  required Random rng,
}) {
  double puan(int r) => r > 0 ? 1.0 : (r == 0 ? 0.5 : 0.0);

  // İlk açan. Sınıra yakın bir değer (~%45) ve gürültüye açık: tek
  // tohumda şans eseri hedefin içine düşebiliyor (bağımsız incelemede
  // görüldü). Bu yüzden 4 kat maçla ölçülüyor.
  final ilkMac = matches * 4;
  final ilk = <String, double>{};
  for (final (ad, f) in <(String, TacticPolicy Function())>[
    ('Taktiksiz', NoTacticPolicy.new),
    ('Akıllı', SmartPolicy.new),
  ]) {
    var p = 0.0;
    playPair(f, f, matches: ilkMac, rules: rules, rng: rng,
        onMatch: (aIlk, r) => p += aIlk ? puan(r) : 1 - puan(r));
    ilk[ad] = p / ilkMac;
  }

  // Güç farkı
  final guc = <int, (double, double)>{};
  for (final g in const [0, 2, 4, 8]) {
    final guclu = SquadProfile.standard.withBonus(g);
    final t0 = playPair(NoTacticPolicy.new, NoTacticPolicy.new,
        matches: matches, rules: rules, rng: rng, squadA: guclu);
    final t1 = playPair(SmartPolicy.new, SmartPolicy.new,
        matches: matches, rules: rules, rng: rng, squadA: guclu);
    guc[g] = (t0.scoreA, t1.scoreA);
  }

  // Nadirlik
  final nadir = <String, double>{};
  for (final (ad, fa, fb) in <(String, TacticPolicy Function(), TacticPolicy Function())>[
    ('ikisi Akıllı', SmartPolicy.new, SmartPolicy.new),
    ('başlangıç Akıllı, kıdemli taktiksiz', SmartPolicy.new, NoTacticPolicy.new),
  ]) {
    nadir[ad] = playPair(fa, fb,
            matches: matches,
            rules: rules,
            rng: rng,
            squadA: SquadProfile.starter,
            squadB: SquadProfile.veteran)
        .scoreA;
  }

  return ScenarioResults(ilk, guc, nadir);
}

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

  final senaryo = runScenarios(rules: rules, matches: matchesPerPair, rng: rng);

  return BalanceReport(
    rules: rules,
    matchesPerPair: matchesPerPair,
    seed: seed,
    policyNames: adlar,
    matrix: matris,
    stats: toplam,
    checks: [
      ..._kontroller(matris, toplam),
      ..._genisKontroller(matris, senaryo),
    ],
    scenarios: senaryo,
  );
}

List<BalanceCheck> _genisKontroller(
  Map<String, Map<String, double>> m,
  ScenarioResults s,
) {
  String yuzde(double x) => '%${(x * 100).toStringAsFixed(1)}';
  final c = <BalanceCheck>[];

  // 6) Hiçbir basit tarz baskın değil (herkese karşı ≥ %50 almıyor)
  final baskin = [
    for (final a in simplePolicyNames)
      if (m[a]!.values.reduce(min) >= BalanceTargets.maxSimpleDominance) a,
  ];
  c.add(BalanceCheck(
    'Hiçbir basit tarz herkesi yenmiyor',
    baskin.isEmpty ? 'yok' : baskin.join(', '),
    'yok',
    baskin.isEmpty,
  ));

  // 7) Her tek numara / enerji tarzı sömürülebilir
  for (final a in exploitablePolicyNames) {
    final enKotu = m[a]!.values.reduce(min);
    c.add(BalanceCheck(
      '"$a" için iyi bir cevap var',
      'en kötü eşleşmesi ${yuzde(enKotu)}',
      '≤ ${yuzde(BalanceTargets.maxExploitableFloor)}',
      enKotu <= BalanceTargets.maxExploitableFloor,
    ));
  }

  // 8) Güç farkı tekdüze: daha güçlü kadro daha çok kazanır
  final gaps = s.powerGap.keys.toList()..sort();
  var tekduze = true;
  for (var i = 1; i < gaps.length; i++) {
    if (s.powerGap[gaps[i]]!.$2 < s.powerGap[gaps[i - 1]]!.$2) tekduze = false;
  }
  c.add(BalanceCheck(
    'Güç farkı arttıkça güçlü taraf daha çok kazanır',
    gaps.map((g) => '+$g: ${yuzde(s.powerGap[g]!.$2)}').join(', '),
    'artan',
    tekduze,
  ));

  // 9) Taktik, güç farkının etkisini bozmuyor
  final kayma = gaps
      .map((g) => (s.powerGap[g]!.$1 - s.powerGap[g]!.$2).abs())
      .reduce(max);
  c.add(BalanceCheck(
    'Taktikler kart gücü farkını büyütmüyor / silmiyor',
    'en büyük kayma ${yuzde(kayma)}',
    '≤ ${yuzde(BalanceTargets.maxTacticGapShift)}',
    kayma <= BalanceTargets.maxTacticGapShift,
  ));

  // ---- İZLENEN (temel kural / eşleştirme kararı gerektiriyor) ----
  final taktiksizEnKotu = m['Taktiksiz']!.values.reduce(min);
  c.add(BalanceCheck(
    'Taktik kullanmayan yeni oyuncu ezilmiyor',
    'en kötü eşleşmesi ${yuzde(taktiksizEnKotu)}',
    '≥ ${yuzde(BalanceTargets.minNoTacticFloor)}',
    taktiksizEnKotu >= BalanceTargets.minNoTacticFloor,
    required: false,
  ));

  for (final e in s.firstLeader.entries) {
    c.add(BalanceCheck(
      'İlk açan avantajı yok (${e.key})',
      'ilk açanın puanı ${yuzde(e.value)}',
      '${yuzde(BalanceTargets.minFirstLeader)} – ${yuzde(BalanceTargets.maxFirstLeader)}',
      e.value >= BalanceTargets.minFirstLeader &&
          e.value <= BalanceTargets.maxFirstLeader,
      required: false,
    ));
  }

  final baslangic = s.rarity['ikisi Akıllı']!;
  c.add(BalanceCheck(
    'Başlangıç kadrosu kıdemliye karşı şanslı',
    'başlangıç kadrosunun puanı ${yuzde(baslangic)}',
    '≥ ${yuzde(BalanceTargets.minStarterVsVeteran)}',
    baslangic >= BalanceTargets.minStarterVsVeteran,
    required: false,
  ));

  return c;
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

  b.writeln('# Taktik Sistemi — Denge Raporu');
  b.writeln();
  b.writeln('> Taktik sistemi kullanıcı onayıyla oyuna alındı '
      '(`database/migrations/021_tactics.sql`, kural sürümü 2). Bu rapor '
      'oyundaki sayılarla birebir aynı kurallar üzerinde simülasyondur; '
      'sayılar değişirse yeniden üretilmelidir.');
  b.writeln();
  b.writeln('Rapor `dart run bin/simulate.dart` ile üretildi. '
      'Tohum: `${r.seed}` (aynı tohum = aynı sonuç). '
      'Her tarz çifti için **${r.matchesPerPair}** maç, toplam '
      '**${r.stats.rounds}** tur.');
  b.writeln();

  b.writeln('## Sonuç');
  b.writeln();
  b.writeln(r.allRequiredPassed
      ? '- ✅ Bütün **zorunlu** hedefler tuttu.'
      : '- ❌ Bazı **zorunlu** hedefler TUTMADI.');
  b.writeln(r.openIssues.isEmpty
      ? '- ✅ İzlenen hedeflerin hepsi tuttu.'
      : '- ❌ **${r.openIssues.length} izlenen hedef tutmadı.** Bunlar '
          'temel kural ya da eşleştirme değişikliği gerektiriyor; '
          'kullanıcı onayı bekliyor (geçti sayılmaz).');
  b.writeln();
  b.writeln('| Kontrol | Ölçülen | Hedef | Tür | Durum |');
  b.writeln('|---|---|---|---|---|');
  for (final c in r.checks) {
    b.writeln('| ${c.name} | ${c.value} | ${c.target} | '
        '${c.required ? 'zorunlu' : 'izlenen'} | ${c.passed ? '✅' : '❌'} |');
  }
  b.writeln();

  final s = r.scenarios;
  b.writeln('## Eşit olmayan oyuncular');
  b.writeln();
  b.writeln('**Güç farkı** (güçlü kadronun her kartı +g güç):');
  b.writeln();
  b.writeln('| g | İkisi taktiksiz | İkisi Akıllı |');
  b.writeln('|---|---|---|');
  for (final g in s.powerGap.keys) {
    b.writeln('| +$g | ${yuzde(s.powerGap[g]!.$1)} | ${yuzde(s.powerGap[g]!.$2)} |');
  }
  b.writeln();
  b.writeln('**Nadirlik** (Başlangıç: Bronz/Gümüş/Altın; Kıdemli: '
      'Altın/Diamond/%12 Legend):');
  b.writeln();
  for (final e in s.rarity.entries) {
    b.writeln('- ${e.key}: başlangıç kadrosu ${yuzde(e.value)}');
  }
  b.writeln();
  b.writeln('**İlk turu açan:**');
  b.writeln();
  for (final e in s.firstLeader.entries) {
    b.writeln('- ${e.key} vs ${e.key}: ilk açan ${yuzde(e.value)}');
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
      '*Hep X* = gücü yettikçe hep aynı taktik. *Biriktirici* = '
      'enerji dolunca pres, cevapta kontra. *Harcayıcı* = her fırsatta '
      'harcar. *Uyarlanır* = rakibin '
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
