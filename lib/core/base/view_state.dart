/// Bir ekranin icinde bulunabilecegi durumlar.
enum ViewState {
  /// Bos / hazir
  idle,

  /// Ilk yukleme suruyor (tam ekran spinner gosterilir)
  loading,

  /// Arka planda bir islem suruyor (butonlar kilitlenir, icerik durur)
  busy,

  /// Hata olustu
  error,
}
