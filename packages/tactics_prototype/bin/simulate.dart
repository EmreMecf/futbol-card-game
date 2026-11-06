import 'dart:io';

import 'package:tactics_prototype/tactics_prototype.dart';

/// Denge simülasyonunu çalıştırır ve RAPOR.md dosyasını yazar.
///
///   dart run bin/simulate.dart            (her çift 2000 maç)
///   dart run bin/simulate.dart 5000       (daha kesin, daha yavaş)
void main(List<String> args) {
  final adet = args.isEmpty ? 2000 : int.parse(args.first);
  final saat = Stopwatch()..start();

  final rapor = runBalance(matchesPerPair: adet);
  File('RAPOR.md').writeAsStringSync(renderReport(rapor));

  stdout.writeln('${rapor.stats.rounds} tur, ${saat.elapsedMilliseconds} ms');
  for (final c in rapor.checks) {
    stdout.writeln('${c.passed ? 'OK  ' : (c.required ? 'HATA' : 'ACIK')} '
        '${c.name}: ${c.value} (hedef ${c.target})');
  }
  stdout.writeln(rapor.allRequiredPassed
      ? 'SONUC: zorunlu hedefler tuttu; acik (izlenen) sorun: '
          '${rapor.openIssues.length}'
      : 'SONUC: zorunlu hedefler TUTMADI');
  exitCode = rapor.allRequiredPassed ? 0 : 1;
}
