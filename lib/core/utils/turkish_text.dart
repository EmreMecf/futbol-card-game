/// Türkçe büyük/küçük harf dönüşümü.
///
/// ===================================================================
/// SORUN
/// ===================================================================
/// Dart'ın `toUpperCase()` fonksiyonu dil bilmez ve İngilizce kuralı
/// uygular:
///
///   'Giriş yap'.toUpperCase()   -> 'GIRIŞ YAP'    ❌  (doğrusu GİRİŞ)
///   'Kaleci'.toUpperCase()      -> 'KALECI'       ❌  (doğrusu KALECİ)
///   'Tipografi'.toUpperCase()   -> 'TIPOGRAFI'    ❌
///
/// Türkçede noktalı "i"nin büyüğü "İ", noktasız "ı"nın büyüğü "I".
/// Bölüm başlıkları ve butonlar büyük harfle yazıldığı için bu hata
/// uygulamanın HER EKRANINDA görünüyordu.
///
/// ===================================================================
/// NE ZAMAN KULLANILMALI?
/// ===================================================================
/// ✅ Türkçe arayüz metinleri: bölüm başlığı, buton, mevki adı
/// ❌ Yabancı özel isimler: oyuncu adı ("Sergio Marin" -> "SERGİO MARİN"
///    olurdu), "Diamond", "Legend", ülke kodları. Bunlarda normal
///    `toUpperCase()` doğru.
extension TurkishText on String {
  /// Türkçe kurala göre büyük harf: i -> İ, ı -> I
  String toUpperTr() =>
      replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();

  /// Türkçe kurala göre küçük harf: İ -> i, I -> ı
  String toLowerTr() =>
      replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
}
