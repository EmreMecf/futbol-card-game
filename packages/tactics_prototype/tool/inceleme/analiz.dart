// BAĞIMSIZ İNCELEME ANALİZİ — oyun kodu DEĞİL; prototipi sadece okur.
// Çalıştırma: dart run tool/inceleme/genel.dart 3000
// Gerçek oyun kurallarının (021 + compare_cards) kopyası üzerinde
// genişletilmiş denge ve Legend alternatifi ölçümleri.
import 'dart:math';

import 'package:tactics_prototype/tactics_prototype.dart';

// --------------------------------------------------------------------
// Legend modları (SADECE simülasyon; oyunda hiçbiri yok)
// --------------------------------------------------------------------
enum LegendMode {
  absolute('Mevcut: Legend mutlak'),
  bonus('Alt.1: Legend +6 güç, mutlak değil'),
  capped('Alt.2: Legend sadece Altın ve altını mutlak yener'),
  none('Alt.3: Seviye kuralı yok (güç + kimya + taktik)');

  final String label;
  const LegendMode(this.label);
}

const k = TacticRules.balanced;

class Kart {
  final String poz;
  final int guc; // güç + kimya
  final String seviye;
  const Kart(this.poz, this.guc, this.seviye);
  bool get legend => seviye == 'legend';
  int get seviyeNo => const {'bronze': 1, 'silver': 2, 'gold': 3, 'diamond': 4, 'legend': 5}[seviye]!;
  SimCard get sim => SimCard(poz, guc, isLegend: legend);
}

int cozum(Kart a, Kart b, Tactic ta, Tactic tb, LegendMode m) {
  final ba = k.bonus(ta, tb, iAmLead: true);
  final bb = k.bonus(tb, ta, iAmLead: false);
  switch (m) {
    case LegendMode.absolute:
      if (a.legend && !b.legend) return 1;
      if (b.legend && !a.legend) return -1;
    case LegendMode.capped:
      if (a.legend && b.seviyeNo <= 3) return 1;
      if (b.legend && a.seviyeNo <= 3) return -1;
    case LegendMode.bonus:
      return (a.guc + ba + (a.legend ? 6 : 0)).compareTo(b.guc + bb + (b.legend ? 6 : 0));
    case LegendMode.none:
      break;
  }
  return (a.guc + ba).compareTo(b.guc + bb);
}

// --------------------------------------------------------------------
// Kadro üretimi
// --------------------------------------------------------------------
const formasyon = ['GK', 'DEF', 'DEF', 'DEF', 'DEF', 'MID', 'MID', 'MID', 'MID', 'FWD', 'FWD'];
const aralik = {'bronze': (45, 62), 'silver': (63, 74), 'gold': (75, 85), 'diamond': (86, 92), 'legend': (93, 99)};

List<Kart> kadro(Random r, Map<String, int> agirlik, {int ekGuc = 0}) {
  final top = agirlik.values.reduce((a, b) => a + b);
  String sec() {
    var x = r.nextInt(top);
    for (final e in agirlik.entries) {
      if (x < e.value) return e.key;
      x -= e.value;
    }
    return 'bronze';
  }
  return [
    for (final p in formasyon)
      () {
        final s = sec();
        final (lo, hi) = aralik[s]!;
        return Kart(p, lo + r.nextInt(hi - lo + 1) + r.nextInt(7) + ekGuc, s);
      }(),
  ];
}

const orta = {'bronze': 25, 'silver': 30, 'gold': 30, 'diamond': 12, 'legend': 3};
const baslangic = {'bronze': 50, 'silver': 40, 'gold': 10};
const kidemli = {'silver': 15, 'gold': 40, 'diamond': 33, 'legend': 12};

// --------------------------------------------------------------------
// Ek enerji davranışları
// --------------------------------------------------------------------
/// Enerjiyi biriktirir; sadece doluyken pres basar, cevapta kontra bekler.
class Biriktirici extends TacticPolicy {
  @override
  String get name => 'Biriktirici';
  @override
  Tactic chooseLead(PolicyContext c) =>
      c.myEnergy >= c.rules.maxEnergy ? Tactic.highPress : Tactic.none;
  @override
  Tactic chooseResponse(PolicyContext c, SimCard lead) =>
      c.opponentEnergy >= c.rules.pressCost && c.myEnergy >= c.rules.counterCost
          ? Tactic.counterAttack
          : Tactic.none;
}

/// Her fırsatta en ucuz taktiği harcar (duvar).
class Harcayici extends TacticPolicy {
  @override
  String get name => 'Harcayıcı';
  @override
  Tactic chooseLead(PolicyContext c) =>
      c.myEnergy >= 3 ? Tactic.highPress : (c.myEnergy >= 1 ? Tactic.defensiveWall : Tactic.none);
  @override
  Tactic chooseResponse(PolicyContext c, SimCard lead) =>
      c.myEnergy >= 1 ? Tactic.defensiveWall : Tactic.none;
}

// --------------------------------------------------------------------
// Maç (gerçek kuralların kopyası, kadro ve Legend modu dışarıdan)
// --------------------------------------------------------------------
class Sonuc {
  final int r; // 1 A, -1 B, 0 beraberlik
  final bool aIlkAcan;
  final int legendKarari; // Legend kuralının güce rağmen kararı belirlediği tur
  final int turlar;
  Sonuc(this.r, this.aIlkAcan, this.legendKarari, this.turlar);
}

Sonuc mac(Random rng, List<Kart> ka, List<Kart> kb, TacticPolicy pa, TacticPolicy pb, LegendMode m) {
  pa.reset();
  pb.reset();
  final eller = [List.of(ka), List.of(kb)];
  final oy = [pa, pb];
  final enerji = [k.startEnergy, k.startEnergy];
  final top = [0, 0];
  var pot = 0;
  var acan = rng.nextInt(2);
  final ilk = acan;
  var legendKarari = 0;

  for (var tur = 0; tur < 11; tur++) {
    if (tur > 0) {
      for (var i = 0; i < 2; i++) {
        enerji[i] = min(k.maxEnergy, enerji[i] + k.energyPerRound);
      }
    }
    final cev = 1 - acan;
    final lk = eller[acan].removeAt(rng.nextInt(eller[acan].length));
    final lt = oy[acan].chooseLead(PolicyContext(myCard: lk.sim, myEnergy: enerji[acan], opponentEnergy: enerji[cev], rules: k, rng: rng));

    final adaylar = eller[cev].where((x) => x.poz == lk.poz).toList()..sort((a, b) => a.guc.compareTo(b.guc));
    var rk = adaylar.first;
    for (final x in adaylar) {
      if (cozum(lk, x, Tactic.none, Tactic.none, m) < 0) {
        rk = x;
        break;
      }
    }
    eller[cev].remove(rk);
    final rt = oy[cev].chooseResponse(PolicyContext(myCard: rk.sim, myEnergy: enerji[cev], opponentEnergy: enerji[acan], rules: k, rng: rng), lk.sim);

    enerji[acan] -= k.costOf(lt);
    enerji[cev] -= k.costOf(rt);

    final s = cozum(lk, rk, lt, rt, m);
    if (m == LegendMode.absolute && lk.legend != rk.legend) {
      final saf = cozum(lk, rk, lt, rt, LegendMode.none);
      if (saf != s) legendKarari++;
    }
    oy[acan].observeOpponent(rt);
    oy[cev].observeOpponent(lt);

    pot += 2;
    if (s == 0) {
      acan = cev;
    } else {
      final kaz = s > 0 ? acan : cev;
      top[kaz] += pot;
      pot = 0;
      acan = kaz;
    }
  }
  return Sonuc(top[0].compareTo(top[1]), ilk == 0, legendKarari, 11);
}

/// A'nın puanı (beraberlik ½), koltuk ve kadrolar her maçta yeniden.
({double puan, double ilkAcanPuani, double legendTurOrani}) seri({
  required int n,
  required int tohum,
  required TacticPolicy Function() a,
  required TacticPolicy Function() b,
  Map<String, int> agA = orta,
  Map<String, int> agB = orta,
  int ekGucA = 0,
  LegendMode m = LegendMode.absolute,
}) {
  final rng = Random(tohum);
  var p = 0.0, ilkP = 0.0, lk = 0, tur = 0;
  for (var i = 0; i < n; i++) {
    final s = mac(rng, kadro(rng, agA, ekGuc: ekGucA), kadro(rng, agB), a(), b(), m);
    final pa = s.r > 0 ? 1.0 : (s.r == 0 ? 0.5 : 0.0);
    p += pa;
    ilkP += s.aIlkAcan ? pa : 1 - pa;
    lk += s.legendKarari;
    tur += s.turlar;
  }
  return (puan: p / n, ilkAcanPuani: ilkP / n, legendTurOrani: lk / tur);
}

String y(double x) => '%${(x * 100).toStringAsFixed(1)}';

void calistir(List<String> args) {
  final n = args.isEmpty ? 3000 : int.parse(args.first);
  print('# GENİŞLETİLMİŞ DENGE ANALİZİ (n=$n maç/hücre, tohum 7)\n');

  final tarzlar = <String, TacticPolicy Function()>{
    'Taktiksiz': NoTacticPolicy.new,
    'Rastgele': RandomPolicy.new,
    'Hep Pres': () => AlwaysPolicy(Tactic.highPress),
    'Hep Kontra': () => AlwaysPolicy(Tactic.counterAttack),
    'Hep Duvar': () => AlwaysPolicy(Tactic.defensiveWall),
    'Uyarlanır': AdaptivePolicy.new,
    'Akıllı': SmartPolicy.new,
    'Biriktirici': Biriktirici.new,
    'Harcayıcı': Harcayici.new,
  };
  final adlar = tarzlar.keys.toList();

  // 1) Tam matris
  print('## 1) Bütün strateji eşleşmeleri (satırın sütuna karşı puanı)\n');
  print('| | ${adlar.join(' | ')} | ortalama | en kötü |');
  print('|---|${'---|' * (adlar.length + 2)}');
  final mat = <String, Map<String, double>>{for (final a in adlar) a: {}};
  var tohum = 7;
  for (var i = 0; i < adlar.length; i++) {
    for (var j = i + 1; j < adlar.length; j++) {
      final r = seri(n: n, tohum: tohum++, a: tarzlar[adlar[i]]!, b: tarzlar[adlar[j]]!);
      mat[adlar[i]]![adlar[j]] = r.puan;
      mat[adlar[j]]![adlar[i]] = 1 - r.puan;
    }
  }
  final baskin = <String>[];
  for (final a in adlar) {
    final v = mat[a]!.values.toList();
    final ort = v.reduce((x, z) => x + z) / v.length;
    final enKotu = v.reduce(min);
    if (enKotu >= 0.5) baskin.add(a);
    print('| **$a** | ${[for (final c in adlar) a == c ? '—' : y(mat[a]![c]!)].join(' | ')} | ${y(ort)} | ${y(enKotu)} |');
  }
  print('\nBASKIN strateji (herkese karşı ≥%50): ${baskin.isEmpty ? 'YOK' : baskin.join(', ')}\n');

  // 2) İlk açan avantajı
  print('## 2) İlk turu açan avantajı (ilk açanın puanı)\n');
  for (final (ad, f) in [('Taktiksiz', NoTacticPolicy.new), ('Akıllı', SmartPolicy.new), ('Hep Pres', () => AlwaysPolicy(Tactic.highPress))]) {
    final r = seri(n: n * 2, tohum: 100, a: f, b: f);
    print('- $ad vs $ad: ilk açan ${y(r.ilkAcanPuani)}');
  }

  // 3) Güç farkı
  print('\n## 3) Güç farkı: A her kartında +g güçlü\n');
  print('| g | taktiksiz (iki taraf) | ikisi de Akıllı | zayıf taraf Akıllı, güçlü taktiksiz |');
  print('|---|---|---|---|');
  for (final g in [0, 2, 4, 6, 8, 12]) {
    final t0 = seri(n: n, tohum: 200 + g, a: NoTacticPolicy.new, b: NoTacticPolicy.new, ekGucA: g);
    final t1 = seri(n: n, tohum: 300 + g, a: SmartPolicy.new, b: SmartPolicy.new, ekGucA: g);
    final t2 = seri(n: n, tohum: 400 + g, a: NoTacticPolicy.new, b: SmartPolicy.new, ekGucA: g);
    print('| +$g | güçlü ${y(t0.puan)} | güçlü ${y(t1.puan)} | güçlü ${y(t2.puan)} |');
  }

  // 4) Nadirlik dağılımları
  print('\n## 4) Nadirlik: Başlangıç kadrosu (Bronz/Gümüş) vs Kıdemli (Altın/Diamond/%12 Legend)\n');
  for (final (ad, fa, fb) in [
    ('ikisi taktiksiz', NoTacticPolicy.new, NoTacticPolicy.new),
    ('ikisi Akıllı', SmartPolicy.new, SmartPolicy.new),
    ('başlangıç Akıllı, kıdemli taktiksiz', SmartPolicy.new, NoTacticPolicy.new),
  ]) {
    final r = seri(n: n, tohum: 500, a: fa, b: fb, agA: baslangic, agB: kidemli);
    print('- $ad: başlangıç kadrosu ${y(r.puan)}');
  }

  // 5) Legend modları
  print('\n## 5) Legend kuralı ve alternatifleri (Ranked önerisi için)\n');
  print('| Mod | %12 Legend\'lı kıdemli vs Legend\'sız eşit güçte* | Başlangıç vs Kıdemli (Akıllı) | Legend\'ın güce rağmen kazandırdığı tur |');
  print('|---|---|---|---|');
  // *Eşit güç: kıdemli dağılımın Legend'ını Diamond'a çevirip gücü aynı tutan rakip
  const legendsiz = {'silver': 15, 'gold': 40, 'diamond': 45};
  for (final m in LegendMode.values) {
    final a = seri(n: n, tohum: 600, a: SmartPolicy.new, b: SmartPolicy.new, agA: kidemli, agB: legendsiz, m: m);
    final b = seri(n: n, tohum: 700, a: SmartPolicy.new, b: SmartPolicy.new, agA: baslangic, agB: kidemli, m: m);
    final c = seri(n: n, tohum: 800, a: SmartPolicy.new, b: SmartPolicy.new, m: m);
    print('| ${m.label} | Legend\'lı ${y(a.puan)} | başlangıç ${y(b.puan)} | ${m == LegendMode.absolute ? y(c.legendTurOrani) : '—'} |');
  }
  print('\n(Not: Akıllı oyuncu beklentisini mevcut kurala göre hesaplıyor; alternatif modlarda kararları biraz yanlı olabilir.)');
}
