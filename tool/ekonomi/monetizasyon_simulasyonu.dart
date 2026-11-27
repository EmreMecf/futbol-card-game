// Monetizasyon ekonomi simülasyonu (beklenen değer modeli, rastgelelik yok).
//
//   dart run tool/ekonomi/monetizasyon_simulasyonu.dart
//
// GİRDİLER mevcut kurallardan alınır (030 sandık kuralları, 056 elmas,
// 060 reklam varsayılanları). VARSAYIMLAR açıkça işaretli; değiştirip
// yeniden çalıştırılabilir. Amaç: ücretli oyuncunun güç akışının (altın,
// sandık, kart) ücretsiz oyuncudan AYRIŞMADIĞINI göstermek.

// ---- Kurallar (030 / 056 / 060) ----
const unlock = {'bronze': 0, 'silver': 7200, 'gold': 21600, 'legend': 43200};
const coins = {'bronze': 15.0, 'silver': 40.0, 'gold': 100.0, 'legend': 250.0}; // aralık ortası
const gemsPerChest = {'bronze': 2.0, 'silver': 3.5, 'gold': 7.5, 'legend': 20.0}; // 056 aralık ortası
const cardsPerChest = 3; // her sandık türü 3 yuva
const typeOdds = {
  'win': {'bronze': 520, 'silver': 350, 'gold': 110, 'legend': 20},
  'draw': {'bronze': 700, 'silver': 260, 'gold': 40, 'legend': 0},
  'loss': {'bronze': 800, 'silver': 180, 'gold': 20, 'legend': 0},
};
const secondsPerGem = 600; // 056: kalan her 10 dk 1 elmas
const standardPack = 500; // altın, 5 kart
const adCoins = 40; // 060 günlük ödül, günde en fazla 2
const adChestSeconds = 600; // 060 sandık hızlandırma, günde en fazla 1

// ---- VARSAYIMLAR ----
const matchesPerDay = 8; // VARSAYIM: orta aktif oyuncu
const winRate = 0.47, drawRate = 0.06; // VARSAYIM
const unlockHoursPerDay = 16.0; // VARSAYIM: uykuda sayaç başlatılamaz

class Profile {
  final String name;
  final int dailyRewardAds; // 0..2
  final int chestAds; // 0..1
  final int paidGemsPerMonth; // ücretli elmas (yalnız kozmetik)
  final bool unsplitCounterfactual; // KARŞI-OLGU: ücretli elmas altına çevrilebilseydi
  const Profile(this.name, {this.dailyRewardAds = 0, this.chestAds = 0, this.paidGemsPerMonth = 0, this.unsplitCounterfactual = false});
}

Map<String, double> _mix() {
  final lossRate = 1 - winRate - drawRate;
  final m = <String, double>{};
  for (final t in unlock.keys) {
    m[t] = (winRate * typeOdds['win']![t]! + drawRate * typeOdds['draw']![t]! + lossRate * typeOdds['loss']![t]!) / 1000;
  }
  return m;
}

Map<String, double> simulate(Profile p, int days) {
  final mix = _mix();
  final chestsOffered = matchesPerDay.toDouble();
  final bronze = chestsOffered * mix['bronze']!;
  final timed = chestsOffered - bronze;
  final avgUnlock = unlock.keys.where((t) => t != 'bronze').fold(0.0, (a, t) => a + mix[t]! * unlock[t]!) /
      (1 - mix['bronze']!);
  final avgCoins = unlock.keys.fold(0.0, (a, t) => a + mix[t]! * coins[t]!);
  final avgGems = unlock.keys.fold(0.0, (a, t) => a + mix[t]! * gemsPerChest[t]!);

  // Sayaçla açılabilen zamanlı sandık
  final capacity = unlockHoursPerDay * 3600 + p.chestAds * adChestSeconds;
  var openedTimed = (capacity / avgUnlock).clamp(0, timed).toDouble();
  // Ücretsiz elmasla fazladan açılan (kalan zamanlı sandıklar): elmas gelirini harca
  final gemCostPerChest = avgUnlock / secondsPerGem;
  final remaining = timed - openedTimed;
  final gemIncome = (bronze + openedTimed) * avgGems;
  final extra = (gemIncome / gemCostPerChest).clamp(0, remaining).toDouble();
  openedTimed += extra;

  final opened = bronze + openedTimed;
  var coinsPerDay = opened * avgCoins + p.dailyRewardAds * adCoins;
  // KARŞI-OLGU: ücretli elmas altına çevrilebilseydi (120 elmas → 3.600 altın)
  if (p.unsplitCounterfactual) coinsPerDay += p.paidGemsPerMonth / 30 * 30;
  final cards = opened * cardsPerChest + coinsPerDay / standardPack * 5;
  return {
    'altin': coinsPerDay * days,
    'sandik': opened * days,
    'kart': cards * days,
    'paket': coinsPerDay * days / standardPack,
  };
}

void main() {
  const profiller = [
    Profile('Reklamsız ücretsiz'),
    Profile('Günde 1 reklam', dailyRewardAds: 1),
    Profile('Günde 3 reklam', dailyRewardAds: 2, chestAds: 1),
    Profile('Düşük harcama (100 ü.elmas/ay)', paidGemsPerMonth: 100),
    Profile('Orta harcama (300 ü.elmas/ay)', paidGemsPerMonth: 300),
    Profile('Yüksek harcama (1400 ü.elmas/ay)', paidGemsPerMonth: 1400),
    Profile('Yalnız kozmetik alan', paidGemsPerMonth: 300),
    Profile('KARŞI-OLGU: ayrım olmasa, yüksek harcama', paidGemsPerMonth: 1400, unsplitCounterfactual: true),
  ];
  final taban = simulate(profiller.first, 30);
  print('Varsayım: günde $matchesPerDay maç, %${(winRate * 100).round()} galibiyet, günde ${unlockHoursPerDay.round()} sa sayaç.\n');
  for (final gun in [7, 30, 90]) {
    print('== $gun GÜN ==');
    print('${'Profil'.padRight(44)}${'altın'.padLeft(9)}${'sandık'.padLeft(8)}${'kart'.padLeft(8)}${'paket'.padLeft(7)}  güç farkı');
    for (final p in profiller) {
      final r = simulate(p, gun);
      final fark = (r['kart']! / (taban['kart']! / 30 * gun) - 1) * 100;
      print('${p.name.padRight(44)}${r['altin']!.round().toString().padLeft(9)}${r['sandik']!.toStringAsFixed(0).padLeft(8)}'
          '${r['kart']!.round().toString().padLeft(8)}${r['paket']!.toStringAsFixed(1).padLeft(7)}  ${fark >= 0 ? '+' : ''}${fark.toStringAsFixed(1)}%');
    }
    print('');
  }
}
