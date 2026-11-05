import 'package:futbol_card_server/config/env.dart';
import 'package:test/test.dart';

/// Uretim guvenlik kapisi.
///
/// Depo herkese acik; gelistirme anahtari ve DB sifresi HERKESIN
/// bildigi degerler. Bu testler, sunucunun bu degerlerle uretimde
/// ACILMAYACAGINI garanti eder.
void main() {
  const guvenliAnahtar = 'Zq8v3Lr1Kx9pTm4Wn7Yb2Hc6Df0Gs5Ja';
  const guvenliSifre = 'uretim-icin-gercek-sifre';

  test('gecerli ayarlarla sorun yok', () {
    final sorunlar = Env.productionProblems({
      'JWT_SECRET': guvenliAnahtar,
      'DB_PASSWORD': guvenliSifre,
    });
    expect(sorunlar, isEmpty);
  });

  test('hicbir ayar yoksa iki sorun', () {
    expect(Env.productionProblems({}), hasLength(2));
  });

  test('gelistirme JWT anahtari reddedilir', () {
    final sorunlar = Env.productionProblems({
      'JWT_SECRET': Env.devJwtSecret,
      'DB_PASSWORD': guvenliSifre,
    });
    expect(sorunlar.single, contains('JWT_SECRET'));
  });

  test('gelistirme DB sifresi reddedilir', () {
    final sorunlar = Env.productionProblems({
      'JWT_SECRET': guvenliAnahtar,
      'DB_PASSWORD': Env.devDbPassword,
    });
    expect(sorunlar.single, contains('DB_PASSWORD'));
  });

  test('kisa JWT anahtari reddedilir', () {
    final sorunlar = Env.productionProblems({
      'JWT_SECRET': 'kisa-anahtar',
      'DB_PASSWORD': guvenliSifre,
    });
    expect(sorunlar.single, contains('cok kisa'));
  });

  test('bos deger ayarlanmamis sayilir', () {
    final sorunlar = Env.productionProblems({
      'JWT_SECRET': '',
      'DB_PASSWORD': '',
    });
    expect(sorunlar, hasLength(2));
  });
}
