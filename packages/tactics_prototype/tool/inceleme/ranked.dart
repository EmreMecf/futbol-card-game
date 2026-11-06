// BAĞIMSIZ İNCELEME ANALİZİ — Ranked alternatifleri ve ilk açan avantajı.
import 'dart:math';

import 'package:tactics_prototype/tactics_prototype.dart';

import 'analiz.dart' show Kart, kadro, orta, baslangic, kidemli, y, cozum, LegendMode, k;

enum AcisStili { rastgele, enGuclu, enZayif }

/// Kadro ortalama gücü
double ort(List<Kart> d) => d.map((c) => c.guc).reduce((a, b) => a + b) / d.length;

List<Kart> tavan(List<Kart> d, int t) =>
    [for (final c in d) Kart(c.poz, min(c.guc, t), c.seviye)];

int mac(Random rng, List<Kart> ka, List<Kart> kb, TacticPolicy pa, TacticPolicy pb,
    {AcisStili acis = AcisStili.rastgele, LegendMode m = LegendMode.absolute, void Function(bool aIlk, int r)? ilkAcan}) {
  pa.reset();
  pb.reset();
  final eller = [List.of(ka), List.of(kb)];
  final oy = [pa, pb];
  final en = [k.startEnergy, k.startEnergy];
  final top = [0, 0];
  var pot = 0;
  var acan = rng.nextInt(2);
  final ilk = acan;
  for (var tur = 0; tur < 11; tur++) {
    if (tur > 0) {
      for (var i = 0; i < 2; i++) {
        en[i] = min(k.maxEnergy, en[i] + k.energyPerRound);
      }
    }
    final cev = 1 - acan;
    final el = eller[acan]..sort((a, b) => a.guc.compareTo(b.guc));
    final lk = switch (acis) {
      AcisStili.rastgele => el.removeAt(rng.nextInt(el.length)),
      AcisStili.enGuclu => el.removeLast(),
      AcisStili.enZayif => el.removeAt(0),
    };
    final lt = oy[acan].chooseLead(PolicyContext(myCard: lk.sim, myEnergy: en[acan], opponentEnergy: en[cev], rules: k, rng: rng));
    final ad = eller[cev].where((x) => x.poz == lk.poz).toList()..sort((a, b) => a.guc.compareTo(b.guc));
    var rk = ad.first;
    for (final x in ad) {
      if (cozum(lk, x, Tactic.none, Tactic.none, m) < 0) {
        rk = x;
        break;
      }
    }
    eller[cev].remove(rk);
    final rt = oy[cev].chooseResponse(PolicyContext(myCard: rk.sim, myEnergy: en[cev], opponentEnergy: en[acan], rules: k, rng: rng), lk.sim);
    en[acan] -= k.costOf(lt);
    en[cev] -= k.costOf(rt);
    final s = cozum(lk, rk, lt, rt, m);
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
  final r = top[0].compareTo(top[1]);
  ilkAcan?.call(ilk == 0, r);
  return r;
}

double puan(int r) => r > 0 ? 1 : (r == 0 ? 0.5 : 0);

void main(List<String> args) {
  final n = args.isEmpty ? 3000 : int.parse(args.first);

  // ---- İlk açan: kart seçme stiline göre ----
  print('## 6) İlk açan avantajı — açanın kart seçme stiline göre (Akıllı vs Akıllı)\n');
  for (final s in AcisStili.values) {
    final rng = Random(900);
    var p = 0.0;
    for (var i = 0; i < n; i++) {
      mac(rng, kadro(rng, orta), kadro(rng, orta), SmartPolicy(), SmartPolicy(), acis: s,
          ilkAcan: (aIlk, r) => p += aIlk ? puan(r) : 1 - puan(r));
    }
    print('- açan ${s.name} kartla açarsa: ilk açanın puanı ${y(p / n)}');
  }

  // ---- Ranked R1: kart gücü tavanı ----
  print('\n## 7) Ranked önerisi R1 — kart gücü tavanı (Başlangıç vs Kıdemli, ikisi Akıllı)\n');
  print('| Tavan | Başlangıç kadrosunun puanı | Eşit kadrolarda güçlü tarafın puanı (+4) |');
  print('|---|---|---|');
  for (final t in [999, 85, 80, 75, 70]) {
    final rng = Random(1000 + t);
    var p = 0.0, q = 0.0;
    for (var i = 0; i < n; i++) {
      p += puan(mac(rng, tavan(kadro(rng, baslangic), t), tavan(kadro(rng, kidemli), t), SmartPolicy(), SmartPolicy(), m: LegendMode.none));
      q += puan(mac(rng, tavan(kadro(rng, orta, ekGuc: 4), t), tavan(kadro(rng, orta), t), SmartPolicy(), SmartPolicy(), m: LegendMode.none));
    }
    print('| ${t == 999 ? 'yok' : t} | ${y(p / n)} | ${y(q / n)} |');
  }

  // ---- Ranked R2: kadro gücüne göre eşleştirme ----
  print('\n## 8) Ranked önerisi R2 — kadro gücü bandında eşleştirme (karışık oyuncu havuzu, ikisi Akıllı)\n');
  print('| Bant (ortalama güç farkı en fazla) | Zayıf kadronun puanı | %25\'ten az şansı olan maç oranı |');
  print('|---|---|---|');
  final havuz = [baslangic, orta, kidemli];
  for (final bant in [99.0, 10.0, 5.0, 3.0, 1.5]) {
    final rng = Random(2000 + bant.toInt());
    var p = 0.0, sayi = 0, umutsuz = 0;
    while (sayi < n) {
      final a = kadro(rng, havuz[rng.nextInt(3)]);
      final b = kadro(rng, havuz[rng.nextInt(3)]);
      final fark = (ort(a) - ort(b)).abs();
      if (fark > bant) continue;
      final zayifA = ort(a) <= ort(b);
      final r = mac(rng, a, b, SmartPolicy(), SmartPolicy());
      p += zayifA ? puan(r) : 1 - puan(r);
      if (fark >= 4) umutsuz++; // +4 güç farkı ~%70'e denk (bkz. bölüm 3)
      sayi++;
    }
    print('| ${bant == 99 ? 'sınırsız (bugün)' : bant} | ${y(p / sayi)} | ${y(umutsuz / sayi)} |');
  }
}
