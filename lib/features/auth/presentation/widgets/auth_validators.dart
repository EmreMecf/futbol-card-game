/// Giriş ve kayıt formlarının doğrulama kuralları.
///
/// ===================================================================
/// SUNUCUYLA AYNI KURALLAR
/// ===================================================================
/// Asıl kontrol sunucuda (`server/lib/routes/auth_routes.dart`) ve
/// veritabanında (`users.username` 3-20 karakter kısıtı). Buradaki
/// kontroller sadece oyuncuya HEMEN geri bildirim vermek için.
///
/// İki taraf farklılaşırsa oyuncu formu geçer ama sunucudan hata alır;
/// bu yüzden sınırlar sabit olarak burada tutuluyor ve testle
/// kilitleniyor. Sunucu kuralı değişirse bu dosya da değişmeli.
///
/// Önceden bu kurallar giriş ve kayıt ekranlarında AYRI AYRI kopya
/// olarak duruyordu.
class AuthValidators {
  const AuthValidators._();

  static const int minPasswordLength = 6;
  static const int minUsernameLength = 3;
  static const int maxUsernameLength = 20;

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'E-posta adresini gir.';
    if (!v.contains('@') || !v.contains('.')) {
      return 'Geçerli bir e-posta adresi gir.';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Şifreni gir.';
    if (value.length < minPasswordLength) {
      return 'Şifre en az $minPasswordLength karakter olmalı.';
    }
    return null;
  }

  static String? username(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Bir kullanıcı adı seç.';
    if (v.length < minUsernameLength) {
      return 'Kullanıcı adı en az $minUsernameLength karakter olmalı.';
    }
    if (v.length > maxUsernameLength) {
      return 'Kullanıcı adı en fazla $maxUsernameLength karakter olabilir.';
    }
    return null;
  }
}
