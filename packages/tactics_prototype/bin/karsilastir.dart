import 'dart:io';
import 'dart:math';

import 'package:tactics_prototype/tactics_prototype.dart';

/// Rekabet analizi: bütün karşılaştırmalı simülasyonları çalıştırır ve
/// KARSILASTIRMA.md dosyasını yazar. Canlı kurallar DEĞİŞMEZ.
///
///   dart run bin/karsilastir.dart
void main() {
  final saat = Stopwatch()..start();
  String y(double x) => '%${(x * 100).toStringAsFixed(1)}';
  String f(double x) => x.toStringAsFixed(1);
  final b = StringBuffer()
    ..writeln('# Rekabet Analizi — Karşılaştırmalı Simülasyonlar')
    ..writeln()
    ..writeln('> Bu dosya `dart run bin/karsilastir.dart` ile üretildi. Her '
        'alternatif AYNI tohum ve kadrolarla bugünkü motora karşı ölçüldü. '
        '**Hiçbiri oyunda aktif değil.**')
    ..writeln();

  // ---------------- A) İlk açan ----------------
  b
    ..writeln('## A) İlk turu açanın dezavantajı')
    ..writeln()
    ..writeln('| Varyant | İlk açan (Akıllı) | İlk açan (Taktiksiz) | Beceri: Akıllı vs Taktiksiz | +4 güçlü kadro | −3 zayıf kadro |')
    ..writeln('|---|---|---|---|---|---|');
  for (final r in compareFirstLeader(matches: 3000)) {
    b.writeln('| ${r.variant.name} | ${y(r.firstLeaderSmart)} | ${y(r.firstLeaderPlain)} | '
        '${y(r.skill)} | ${y(r.power4)} | ${y(r.comeback)} |');
  }
  b
    ..writeln()
    ..writeln('Hedef: ilk açan %45–55 (ideal %50); beceri ve güç ödülleri '
        'bugünküne yakın kalmalı.')
    ..writeln();

  // ---------------- B) Sürüm 2 vs 3 ----------------
  final c = compareRuleVersions(matchesPerPair: 2000);
  b
    ..writeln('## B) Kural sürümü 2 (canlı) vs 3 adayı (özellik → taktik çarpanı, ±%20)')
    ..writeln()
    ..writeln('| | Sürüm 2 | Sürüm 3 |')
    ..writeln('|---|---|---|')
    ..writeln('| Zorunlu denge hedefleri | ${c.v2.allRequiredPassed ? '✅' : '❌'} | ${c.v3.allRequiredPassed ? '✅' : '❌'} |')
    ..writeln('| Turu çevirme oranı | ${y(c.v2.stats.flips / c.v2.stats.rounds)} | ${y(c.v3.stats.flips / c.v3.stats.rounds)} |')
    ..writeln('| Akıllı vs Taktiksiz | ${y(c.v2.matrix['Akıllı']!['Taktiksiz']!)} | ${y(c.v3.matrix['Akıllı']!['Taktiksiz']!)} |');
  for (final t in [Tactic.highPress, Tactic.counterAttack, Tactic.defensiveWall]) {
    b.writeln('| ${t.label}: mevkiler arası tur kazanma farkı | '
        '${y(c.spread(c.v2, t))} | ${y(c.spread(c.v3, t, v3: true))} |');
  }
  // Tip Bilen oyuncu: oyuncu tipini kullanmak avantaj sağlıyor mu?
  for (final (ad, k) in [('Sürüm 2', TacticRules.balanced), ('Sürüm 3', TacticRules.v3Attributes)]) {
    final kadro = SquadProfile.standard.attributed;
    final r = playPair(TypeAwarePolicy.new, SmartPolicy.new,
        matches: 6000, rules: k, rng: Random(77), squadA: kadro, squadB: kadro);
    b.writeln('| "Tip Bilen" vs Akıllı ($ad) | ${ad == 'Sürüm 2' ? y(r.scoreA) : '—'} | ${ad == 'Sürüm 3' ? y(r.scoreA) : '—'} |');
  }
  b
    ..writeln()
    ..writeln('"Tip Bilen": turu açarken taktiğe en uygun oyuncu tipini sürer. '
        'Sürüm 2\'de de önde olması oyuncu tipinden değil, güçlü kartları '
        'saklayıp zayıflarla açmasından (kart yönetimi). Sürüm 3\'ün '
        'katkısı bu iki satırın farkı kadar.')
    ..writeln();

  // ---------------- C) Eşleştirme ----------------
  b.writeln('## C) Eşleştirme: MMR + kadro gücü');
  for (final nufus in [240, 40]) {
    b
      ..writeln()
      ..writeln('**Nüfus: $nufus oyuncu** (%30 başlangıç, %45 orta, %25 kıdemli kadro; tarzlar eşit)')
      ..writeln()
      ..writeln('| Mod | Umutsuz maç | Yeni gelen: puan (ilk 20) | Yeni gelen: umutsuz | Bekleme ort / p90 | Sıralamada beceri ÷ kadro | Başlangıç MMR / Kıdemli MMR |')
      ..writeln('|---|---|---|---|---|---|---|');
    for (final m in MatchmakingMode.values) {
      final r = simulateMatchmaking(m, population: nufus);
      b.writeln('| ${m.label} | ${y(r.hopelessRate)} | ${y(r.newcomerScore)} | ${y(r.newcomerHopeless)} | '
          '${r.avgWaitSec.toStringAsFixed(0)} / ${r.p90WaitSec.toStringAsFixed(0)} sn | '
          '${r.skillOverDeck.toStringAsFixed(2)} | '
          '${r.mmrByDeck['Başlangıç']!.round()} / ${r.mmrByDeck['Kıdemli']!.round()} |');
    }
  }
  b
    ..writeln()
    ..writeln('Umutsuz maç: ortalama kadro gücü farkı ≥ 4 (~%70\'e %30 sonuç). '
        '"Beceri ÷ kadro" > 1 ise sıralama ustalığı kadrodan çok yansıtıyor.')
    ..writeln();

  // ---------------- D) Ekonomi ----------------
  b.writeln('## D) Ekonomi: kalıcı kart kaybı');
  for (final kadroEs in [false, true]) {
    b
      ..writeln()
      ..writeln('**Eşleştirme: ${kadroEs ? 'MMR + kadro gücü (024 combined)' : 'sadece MMR (bugün)'}** '
          '— 160 oyuncu, kişi başı 120 maç, yeni gelenler ortada katılır')
      ..writeln()
      ..writeln('| Kural | Kilitlenen (oynayamayan) | Kadro gücü ort (p10–p90) | En çok / en az kazanan %20: güç artışı | Kart/oyuncu | Legend/oyuncu | Yeni gelen puanı | El değiştiren kart/oyuncu |')
      ..writeln('|---|---|---|---|---|---|---|---|');
    for (final r in LossRule.values) {
      final e = simulateEconomy(r, deckAwarePairing: kadroEs);
      b.writeln('| ${r.label} | ${y(e.stuckRate)} | ${f(e.meanDeck)} (${f(e.p10Deck)}–${f(e.p90Deck)}) | '
          '+${f(e.topGrowth)} / +${f(e.bottomGrowth)} | ${f(e.cardsPerPlayer)} | '
          '${e.legendsPerPlayer.toStringAsFixed(2)} | ${y(e.newcomerScore)} | ${f(e.transfersPerPlayer)} |');
    }
  }
  b
    ..writeln()
    ..writeln('Varsayımlar: başlangıç paketi gerçek dağılımla (2 KL, 5 DF, 5 OS, '
        '3 FV); galibiyet +100 coin; oyuncu coin yettikçe Standart Paket '
        '(500 coin, gerçek oranlar) alır; kaybeden önce yedeği olmayan '
        'mevkileri, sonra en güçlü kartları korur (canlı kural için en '
        'iyimser davranış). Kilitlenen: kadrosu eksik kaldığı ve coin '
        'kazanamadığı için bir daha maça giremeyen oyuncu.')
    ..writeln();

  File('KARSILASTIRMA.md').writeAsStringSync(b.toString());
  stdout.writeln('KARSILASTIRMA.md yazildi (${saat.elapsed.inSeconds} sn)');
}
