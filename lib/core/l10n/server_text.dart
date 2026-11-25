import 'app_language.dart';
import 'server_strings_en.dart';
import 'strings_en.dart';

/// SUNUCUDAN GELEN METİNLERİN ÇEVİRİSİ
///
/// Oyun kuralları ve içerik (görev adı, SBC açıklaması, eşya adı, hata
/// mesajı) veritabanında Türkçe yazılı ve sunucu onları olduğu gibi
/// gönderir. Oyuncu İngilizce seçtiyse bu metinler uygulamaya girerken
/// çevrilir:
///
///   1. Tam eşleşme: [kEnStrings] ve [kEnServerStrings]
///   2. Şablon: içinde sayı/ad geçen mesajlar ("Yeterli elmas yok.
///      Gerekli: 12, mevcut: 3"). Şablonlar [kEnServerPatterns] içinde;
///      Türkçe şablondaki `%`, `%s` ya da `{ad}` yerleri yakalanır ve
///      İngilizce şablondaki `{1}`, `{2}`... yerlerine sırayla konur.
///
/// Bilinmeyen metin olduğu gibi kalır (Türkçe görünür, kaybolmaz).
class ServerText {
  ServerText._();

  /// Yanıtlarda çevrilen alanlar. Kullanıcı adı, kart adı, kod gibi
  /// alanlar listede yok; onlara hiç dokunulmaz.
  static const translatedKeys = {
    'message',
    'notice',
    'name',
    'title',
    'description',
    'label',
    'hint',
    'reason',
    'league_name',
    'type_name',
    'text',
    'error_message',
    'detail',
  };

  static List<(RegExp, String)>? _desenler;

  static List<(RegExp, String)> get _patterns =>
      _desenler ??= [for (final e in kEnServerPatterns.entries) (_regex(e.key), e.value)];

  static RegExp _regex(String sablon) {
    final parcalar = sablon.split(RegExp(r'%s|%|\{\w+\}'));
    final govde = parcalar.map(RegExp.escape).join('(.+?)');
    return RegExp('^$govde\$', dotAll: true);
  }

  /// Tek bir metin
  static String translate(String s) {
    if (!isEnglish || s.isEmpty) return s;
    final tam = kEnServerStrings[s] ?? kEnStrings[s];
    if (tam != null) return tam;
    for (final (re, en) in _patterns) {
      final m = re.firstMatch(s);
      if (m == null) continue;
      var sonuc = en;
      for (var i = 1; i <= m.groupCount; i++) {
        sonuc = sonuc.replaceAll('{$i}', translate(m.group(i) ?? ''));
      }
      return sonuc;
    }
    return s;
  }

  /// JSON yanıtını gezer, [translatedKeys] alanlarındaki metinleri çevirir.
  /// Türkçede hiçbir şey yapmaz (aynı nesneyi döndürür).
  static dynamic translateJson(dynamic veri) {
    if (!isEnglish) return veri;
    return _gez(veri, null);
  }

  static dynamic _gez(dynamic v, String? anahtar) {
    // jsonDecode türlerini koru: Map<String, dynamic> ve List<dynamic>
    if (v is Map<String, dynamic>) {
      return <String, dynamic>{for (final e in v.entries) e.key: _gez(e.value, e.key)};
    }
    if (v is Map) {
      return v.map((k, x) => MapEntry(k, _gez(x, k is String ? k : null)));
    }
    if (v is List) return <dynamic>[for (final x in v) _gez(x, anahtar)];
    if (v is String && anahtar != null && translatedKeys.contains(anahtar)) return translate(v);
    return v;
  }
}
