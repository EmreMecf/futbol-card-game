import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/config/app_config.dart';

/// FAZ 7 — Yayın derlemesinin sunucu adresi denetimi.
void main() {
  group('releaseConfigProblem', () {
    test('https üretim adresi kabul edilir', () {
      expect(AppConfig.releaseConfigProblem('https://api.futbolcard.com'),
          isNull);
    });

    test('şifresiz http reddedilir (Android/iOS yayında engelli)', () {
      expect(AppConfig.releaseConfigProblem('http://api.futbolcard.com'),
          contains('https'));
    });

    test('yerel adresler reddedilir (telefonda localhost telefonun kendisi)',
        () {
      for (final a in [
        'https://localhost:8080',
        'https://127.0.0.1',
        'https://10.0.2.2:8080',
      ]) {
        expect(AppConfig.releaseConfigProblem(a), isNotNull, reason: a);
      }
    });

    test('geliştiricinin varsayılan .env adresi yayında reddedilir', () {
      expect(AppConfig.releaseConfigProblem('http://localhost:8080'),
          isNotNull);
    });

    test('bozuk adres reddedilir', () {
      expect(AppConfig.releaseConfigProblem('api'), isNotNull);
    });
  });
}
