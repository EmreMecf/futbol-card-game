import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/utils/turkish_text.dart';

/// Türkçe büyük/küçük harf.
///
/// REGRESYON: Dart'ın toUpperCase()'i 'Giriş yap' metnini 'GIRIŞ YAP'
/// yapıyordu (İ yerine noktasız I). Bölüm başlıkları ve butonlar büyük
/// harfle yazıldığı için hata her ekranda görünüyordu.
void main() {
  test('noktalı i -> İ, noktasız ı -> I', () {
    expect('Giriş yap'.toUpperTr(), 'GİRİŞ YAP');
    expect('Kaleci'.toUpperTr(), 'KALECİ');
    expect('Kartı oyna'.toUpperTr(), 'KARTI OYNA');
    expect('Tipografi'.toUpperTr(), 'TİPOGRAFİ');
  });

  test('diğer Türkçe harfler doğru', () {
    expect('çğöşü'.toUpperTr(), 'ÇĞÖŞÜ');
  });

  test('neden gerekli: standart toUpperCase yanlış', () {
    expect('Giriş'.toUpperCase(), isNot('GİRİŞ'));
  });

  test('küçük harf: İ -> i, I -> ı (birleşik nokta kalmaz)', () {
    expect('GİRİŞ'.toLowerTr(), 'giriş');
    expect('KARTI'.toLowerTr(), 'kartı');
    expect('İSTANBUL'.toLowerTr().length, 'istanbul'.length);
  });
}
