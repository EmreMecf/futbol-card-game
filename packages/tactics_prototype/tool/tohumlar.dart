// Farkli tohumlarla dengenin saglamligini olcer (sans eseri mi tuttu?).
import 'package:tactics_prototype/tactics_prototype.dart';

void main(List<String> args) {
  final adet = args.isEmpty ? 3000 : int.parse(args.first);
  String y(double x) => (x * 100).toStringAsFixed(1);
  for (final seed in [1, 2, 3, 4]) {
    final r = runBalance(matchesPerPair: adet, seed: seed);
    final m = r.matrix;
    print('tohum $seed: K>P ${y(m['Hep Kontra Atak']!['Hep Yüksek Pres']!)}  '
        'D>K ${y(m['Hep Savunma Duvarı']!['Hep Kontra Atak']!)}  '
        'P>D ${y(m['Hep Yüksek Pres']!['Hep Savunma Duvarı']!)}  '
        'Akilli>Taktiksiz ${y(m['Akıllı']!['Taktiksiz']!)}  '
        'cevirme ${y(r.stats.flips / r.stats.rounds)}  tumu=${r.allPassed}');
  }
}
