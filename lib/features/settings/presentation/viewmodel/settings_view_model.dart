import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Oyuncunun YEREL tercihleri.
///
/// ===================================================================
/// NEDEN SUNUCUDA DEĞİL?
/// ===================================================================
/// Buradaki ayarların hiçbiri oyunun kurallarını etkilemiyor: ses,
/// titreşim ve animasyon tamamen o cihazın nasıl davranacağıyla
/// ilgili. Sunucuya taşımak her açılışta bir ağ isteği daha demekti
/// ve uçak modunda ayarlar okunamazdı.
///
/// Kural etkileyen hiçbir şey buraya konulmamalı. Bir ayar maçın
/// sonucunu değiştirebiliyorsa, oyuncu telefonundaki dosyayı
/// düzenleyerek hile yapabilir demektir.
class SettingsViewModel extends ChangeNotifier {
  static const _anahtarSes = 'ayar_ses_efektleri';
  static const _anahtarMuzik = 'ayar_muzik';
  static const _anahtarTitresim = 'ayar_titresim';
  static const _anahtarAnimasyon = 'ayar_kart_animasyonlari';
  static const _anahtarSureUyarisi = 'ayar_sure_uyarisi';

  SharedPreferences? _depo;

  bool _sesEfektleri = true;
  bool _muzik = false;
  bool _titresim = true;
  bool _kartAnimasyonlari = true;
  bool _sureUyarisi = true;

  bool get soundEffects => _sesEfektleri;
  bool get music => _muzik;
  bool get vibration => _titresim;
  bool get cardAnimations => _kartAnimasyonlari;
  bool get turnWarning => _sureUyarisi;

  bool _yuklendi = false;
  bool get isLoaded => _yuklendi;

  /// Kayıtlı tercihleri okur.
  ///
  /// Depo açılamazsa (nadir; bozuk kurulum) varsayılanlarla devam
  /// ediyoruz. Ayarlar ekranının hiç açılmaması, hepsinin kapalı
  /// görünmesinden iyidir.
  Future<void> load() async {
    try {
      _depo = await SharedPreferences.getInstance();
      _sesEfektleri = _depo?.getBool(_anahtarSes) ?? true;
      _muzik = _depo?.getBool(_anahtarMuzik) ?? false;
      _titresim = _depo?.getBool(_anahtarTitresim) ?? true;
      _kartAnimasyonlari = _depo?.getBool(_anahtarAnimasyon) ?? true;
      _sureUyarisi = _depo?.getBool(_anahtarSureUyarisi) ?? true;
    } catch (_) {
      // Varsayılanlarla devam
    }
    _yuklendi = true;
    notifyListeners();
  }

  Future<void> setSoundEffects(bool acik) =>
      _yaz(_anahtarSes, acik, () => _sesEfektleri = acik);

  Future<void> setMusic(bool acik) =>
      _yaz(_anahtarMuzik, acik, () => _muzik = acik);

  Future<void> setVibration(bool acik) =>
      _yaz(_anahtarTitresim, acik, () => _titresim = acik);

  Future<void> setCardAnimations(bool acik) =>
      _yaz(_anahtarAnimasyon, acik, () => _kartAnimasyonlari = acik);

  Future<void> setTurnWarning(bool acik) =>
      _yaz(_anahtarSureUyarisi, acik, () => _sureUyarisi = acik);

  /// Önce arayüzü günceller, sonra diske yazar.
  ///
  /// Tersi yapılsaydı anahtarın hareketi disk yazımını bekleyip
  /// takılıyormuş gibi görünürdü. Yazma hatası olsa bile ayar bu
  /// oturum boyunca geçerli kalıyor.
  Future<void> _yaz(String anahtar, bool deger, VoidCallback uygula) async {
    uygula();
    notifyListeners();
    try {
      await _depo?.setBool(anahtar, deger);
    } catch (_) {
      // Diske yazılamadı; oturum içinde ayar yine de çalışıyor.
    }
  }
}
