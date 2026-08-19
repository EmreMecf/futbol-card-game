import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/utils/result.dart';
import 'package:futbol_card/core/error/app_exception.dart';

/// ADIM 2 icin ornek birim testi.
/// Gercek ekran testleri ADIM 3 ve 4'te modeller hazir olunca yazilacak.
void main() {
  group('Result sarmalayicisi', () {
    test('basarili islem Success dondurur', () async {
      final sonuc = await Result.guard<int>(() async => 42);

      expect(sonuc.isSuccess, isTrue);
      expect(sonuc.dataOrNull, 42);
      expect(sonuc.errorOrNull, isNull);
    });

    test('hata firlatan islem Failure dondurur', () async {
      final sonuc = await Result.guard<int>(
        () async => throw Exception('test hatasi'),
      );

      expect(sonuc.isFailure, isTrue);
      expect(sonuc.dataOrNull, isNull);
      expect(sonuc.errorOrNull, isA<AppException>());
    });
  });
}
