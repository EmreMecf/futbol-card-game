// BAĞIMSIZ İNCELEME ANALİZİ — ilk açan dezavantajı için seçenekler (oyunda yok).
import 'dart:math';

import 'package:tactics_prototype/tactics_prototype.dart';

import 'analiz.dart' show Kart, kadro, orta, y, cozum, LegendMode, k;

enum Secenek {
  bugun('Bugün'),
  enerji('S1: ilk açana +1 başlangıç enerjisi'),
  kor('S2: cevap veren kartı GÜCÜNÜ görmeden seçer');

  final String label;
  const Secenek(this.label);
}

double mac(Random rng, Secenek s, TacticPolicy pa, TacticPolicy pb) {
  pa.reset();
  pb.reset();
  final eller = [kadro(rng, orta), kadro(rng, orta)];
  final oy = [pa, pb];
  var acan = rng.nextInt(2);
  final ilk = acan;
  final en = [k.startEnergy, k.startEnergy];
  if (s == Secenek.enerji) en[ilk] += 1;
  final top = [0, 0];
  var pot = 0;
  for (var tur = 0; tur < 11; tur++) {
    if (tur > 0) {
      for (var i = 0; i < 2; i++) {
        en[i] = min(k.maxEnergy, en[i] + k.energyPerRound);
      }
    }
    final cev = 1 - acan;
    final lk = eller[acan].removeAt(rng.nextInt(eller[acan].length));
    final lt = oy[acan].chooseLead(PolicyContext(myCard: lk.sim, myEnergy: en[acan], opponentEnergy: en[cev], rules: k, rng: rng));
    final ad = eller[cev].where((x) => x.poz == lk.poz).toList()..sort((a, b) => a.guc.compareTo(b.guc));
    Kart rk;
    if (s == Secenek.kor) {
      // Gücü bilmiyor: o mevkideki kartlarından ortancayı oynar
      rk = ad[ad.length ~/ 2];
    } else {
      rk = ad.first;
      for (final x in ad) {
        if (cozum(lk, x, Tactic.none, Tactic.none, LegendMode.absolute) < 0) {
          rk = x;
          break;
        }
      }
    }
    eller[cev].remove(rk);
    // Kör cevapta Akıllı da kartı göremez: ortalama bir kartmış gibi düşünür
    final gorulen = s == Secenek.kor ? SimCard(lk.poz, 75) : lk.sim;
    final rt = oy[cev].chooseResponse(PolicyContext(myCard: rk.sim, myEnergy: en[cev], opponentEnergy: en[acan], rules: k, rng: rng), gorulen);
    en[acan] -= k.costOf(lt);
    en[cev] -= k.costOf(rt);
    final r = cozum(lk, rk, lt, rt, LegendMode.absolute);
    oy[acan].observeOpponent(rt);
    oy[cev].observeOpponent(lt);
    pot += 2;
    if (r == 0) {
      acan = cev;
    } else {
      final kaz = r > 0 ? acan : cev;
      top[kaz] += pot;
      pot = 0;
      acan = kaz;
    }
  }
  final r = top[ilk].compareTo(top[1 - ilk]);
  return r > 0 ? 1 : (r == 0 ? 0.5 : 0);
}

void main(List<String> args) {
  final n = args.isEmpty ? 12000 : int.parse(args.first);
  print('## 9) İlk açan dezavantajı: seçenekler (ilk açanın puanı, n=$n)\n');
  print('| Seçenek | Taktiksiz vs Taktiksiz | Akıllı vs Akıllı |');
  print('|---|---|---|');
  for (final s in Secenek.values) {
    final r1 = Random(31), r2 = Random(32);
    var a = 0.0, b = 0.0;
    for (var i = 0; i < n; i++) {
      a += mac(r1, s, NoTacticPolicy(), NoTacticPolicy());
      b += mac(r2, s, SmartPolicy(), SmartPolicy());
    }
    print('| ${s.label} | ${y(a / n)} | ${y(b / n)} |');
  }
}
