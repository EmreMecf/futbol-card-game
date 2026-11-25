import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'strings_en.dart';

/// Oyunun desteklediği diller.
enum AppLanguage {
  tr('tr', 'Türkçe'),
  en('en', 'English');

  const AppLanguage(this.code, this.nativeName);

  /// ISO dil kodu
  final String code;

  /// Dilin kendi dilindeki adı (seçim listesinde hep böyle yazılır)
  final String nativeName;

  Locale get locale => Locale(code);

  static AppLanguage? fromCode(String? code) {
    for (final l in values) {
      if (l.code == code) return l;
    }
    return null;
  }
}

/// UYGULAMA DİLİ
///
/// ===================================================================
/// NASIL ÇALIŞIR?
/// ===================================================================
/// Arayüz metinleri kodda Türkçe yazılır ve `.tr` ile işaretlenir:
///
///   Text('KARTI OYNA'.tr)
///   Text('{n} kart'.trArgs({'n': adet}))
///
/// Türkçe metin aynı zamanda ANAHTARDIR. Dil İngilizceyse anahtar
/// [kEnStrings] sözlüğünde aranır; bulunamazsa Türkçesi gösterilir (boş
/// ekran yerine). `test/l10n_test.dart` kodda `.tr` ile işaretli her
/// metnin İngilizcesi olduğunu denetler.
///
/// Dil değişince kök widget yeniden kurulur ([AppLanguageController] bir
/// [ValueNotifier]); bütün ekranlar yeni dille çizilir.
///
/// ===================================================================
/// İLK AÇILIŞ
/// ===================================================================
/// Oyuncu henüz seçmediyse cihaz dili Türkçeyse Türkçe, değilse
/// İngilizce açılır. Seçim cihazda saklanır (sunucuya gitmez).
///
/// Testler ve [load] çağrılmamış durumlar Türkçe başlar; mevcut testler
/// Türkçe metinleri aradığı için bu varsayılan değişmemeli.
class AppLanguageController extends ValueNotifier<AppLanguage> {
  AppLanguageController._() : super(AppLanguage.tr);

  /// Uygulama genelinde tek dil durumu
  static final AppLanguageController instance = AppLanguageController._();

  static const prefsKey = 'ayar_dil';

  /// Kaydedilmiş seçimi, yoksa cihaz dilini okur.
  Future<void> load({String? deviceLanguageCode}) async {
    AppLanguage? kayitli;
    try {
      final depo = await SharedPreferences.getInstance();
      kayitli = AppLanguage.fromCode(depo.getString(prefsKey));
    } catch (_) {
      // Depo açılamazsa cihaz diline göre devam
    }
    value = kayitli ?? languageForDevice(deviceLanguageCode ?? PlatformDispatcher.instance.locale.languageCode);
  }

  /// Oyuncunun seçimi: hemen uygulanır, sonra cihaza yazılır.
  Future<void> select(AppLanguage dil) async {
    value = dil;
    try {
      final depo = await SharedPreferences.getInstance();
      await depo.setString(prefsKey, dil.code);
    } catch (_) {
      // Yazılamadıysa bu oturum boyunca yine geçerli
    }
  }

  /// Cihaz dili Türkçeyse Türkçe, diğer bütün dillerde İngilizce
  static AppLanguage languageForDevice(String code) => code.toLowerCase() == 'tr' ? AppLanguage.tr : AppLanguage.en;
}

/// Şu anki dil
AppLanguage get currentLanguage => AppLanguageController.instance.value;

/// Şu an İngilizce mi?
bool get isEnglish => currentLanguage == AppLanguage.en;

/// Çeviri: Türkçe metin anahtardır.
extension Tr on String {
  /// Şu anki dildeki karşılık. Türkçede ya da çevirisi yoksa kendisi.
  String get tr {
    if (!isEnglish) return this;
    return kEnStrings[this] ?? this;
  }

  /// Yer tutuculu çeviri: `'{n} kart'.trArgs({'n': 3})`.
  ///
  /// Önce şablon çevrilir, sonra `{ad}` yerlerine değerler konur; böylece
  /// iki dilde sözcük sırası farklı olabilir.
  String trArgs(Map<String, Object?> args) {
    var s = tr;
    args.forEach((k, v) => s = s.replaceAll('{$k}', '${v ?? ''}'));
    return s;
  }
}

/// Testler için: anahtarın İngilizcesi var mı?
@visibleForTesting
bool hasEnglish(String key) => kEnStrings.containsKey(key);
