/// Uygulama genelinde kullanilan tek tip hata sinifi.
///
/// Amac: Supabase, Dio ve Dart'in kendi hatalarini tek bir yapiya indirgemek.
/// Boylece arayuz katmani "hangi paketten geldi" diye ugrasmaz, sadece
/// [message] alanini kullaniciya gosterir.
class AppException implements Exception {
  /// Kullaniciya gosterilecek TURKCE mesaj
  final String message;

  /// Teknik detay (loglama icin, kullaniciya gosterilmez)
  final String? technicalDetail;

  /// Hata tipi (arayuzun farkli davranmasi gerekirse)
  final AppErrorType type;

  const AppException({
    required this.message,
    this.type = AppErrorType.unknown,
    this.technicalDetail,
  });

  /// Internet baglantisi yok
  const AppException.network()
      : message =
            'Internet baglantiniz yok gibi gorunuyor. Lutfen kontrol edin.',
        type = AppErrorType.network,
        technicalDetail = null;

  /// Oturum gecersiz / suresi dolmus
  const AppException.unauthorized()
      : message = 'Oturumunuzun suresi doldu. Lutfen tekrar giris yapin.',
        type = AppErrorType.unauthorized,
        technicalDetail = null;

  @override
  String toString() => 'AppException($type): $message';
}

enum AppErrorType {
  /// Sunucu bir oyun kuralini reddetti (ornek: "Sira sizde degil.")
  gameRule,

  /// Kimlik dogrulama sorunu
  unauthorized,

  /// Ag / baglanti sorunu
  network,

  /// Sunucu tarafi beklenmeyen hata
  server,

  /// Siniflandirilamayan
  unknown,
}
