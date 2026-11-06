// Birkac denge ayarini yan yana dener.
import 'package:tactics_prototype/tactics_prototype.dart';

TacticRules k({required int pres, required int kontra, required int kontraPres, required int duvar, required int duvarAcan, int pc = 3, int kc = 2, int dc = 1, int bas = 2, int maks = 5}) =>
    TacticRules(startEnergy: bas, energyPerRound: 1, maxEnergy: maks, pressCost: pc, counterCost: kc, wallCost: dc,
        pressBonus: pres, counterBaseBonus: kontra, counterVsPressBonus: kontraPres, wallDefendBonus: duvar, wallLeadBonus: duvarAcan);

void main() {
  String y(double x) => (x * 100).toStringAsFixed(1);
  final ayarlar = {
    'B': k(pres: 9, kontra: 2, kontraPres: 13, duvar: 6, duvarAcan: 2),
    'B pres maliyeti 4': k(pres: 9, kontra: 2, kontraPres: 13, duvar: 6, duvarAcan: 2, pc: 4),
    'B enerji tavani 4': k(pres: 9, kontra: 2, kontraPres: 13, duvar: 6, duvarAcan: 2, maks: 4),
    'B pres 4 + pres bonus 10': k(pres: 10, kontra: 2, kontraPres: 13, duvar: 6, duvarAcan: 2, pc: 4),
  };
  for (final e in ayarlar.entries) {
    final r = runBalance(rules: e.value, matchesPerPair: 2500, seed: 7);
    final m = r.matrix;
    final hata = r.checks.where((c) => !c.passed).map((c) => c.name).join('; ');
    print('${e.key}: cevirme ${y(r.stats.flips / r.stats.rounds)} | Akilli>Taktiksiz ${y(m['Akıllı']!['Taktiksiz']!)} '
        '| K>P ${y(m['Hep Kontra Atak']!['Hep Yüksek Pres']!)} D>K ${y(m['Hep Savunma Duvarı']!['Hep Kontra Atak']!)} '
        'P>D ${y(m['Hep Yüksek Pres']!['Hep Savunma Duvarı']!)} | Pres>Taktiksiz ${y(m['Hep Yüksek Pres']!['Taktiksiz']!)} '
        '| ${r.allPassed ? 'HEPSI OK' : 'TUTMAYAN: $hata'}');
  }
}
