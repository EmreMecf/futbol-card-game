import 'package:bcrypt/bcrypt.dart';

/// Sifre hash'leme ve dogrulama.
///
/// NEDEN BCRYPT?
/// Sifreler asla duz metin saklanmaz. Ustelik SHA-256 gibi hizli
/// algoritmalar da yetmez; saldirgan saniyede milyarlarca deneme
/// yapabilir. bcrypt kasitli olarak YAVASTIR ve her sifre icin farkli
/// bir "tuz" (salt) uretir, boylece ayni sifreye sahip iki kullanicinin
/// hash'i bile farkli olur.
class PasswordService {
  /// Maliyet faktoru. Her +1, hesaplama suresini iki katina cikarir.
  /// 12 su an icin dengeli bir deger (yaklasik 250ms).
  static const int _cost = 12;

  static String hash(String plainPassword) {
    return BCrypt.hashpw(plainPassword, BCrypt.gensalt(logRounds: _cost));
  }

  static bool verify(String plainPassword, String hashed) {
    try {
      return BCrypt.checkpw(plainPassword, hashed);
    } catch (_) {
      // Bozuk hash kaydi -> giris basarisiz
      return false;
    }
  }
}
