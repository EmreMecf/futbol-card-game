/// EKRANDA GÖSTERİLEN METİNLERİN ÇEVİRİ KANCASI
///
/// Modellerdeki etiketler (mevki adı, taktik açıklaması, görev şartı...)
/// Türkçe yazılır ve bu kancadan geçerek okunur. Sunucu kancaya dokunmaz:
/// metinler Türkçe kalır. Uygulama açılışta kendi çevirisini bağlar
/// (`displayText = (s) => s.tr;`), böylece aynı etiket oyuncunun
/// dilinde görünür.
///
/// Türkçe metin anahtardır; çevirisi yoksa kendisi gösterilir.
String Function(String turkish) displayText = _aynen;

String _aynen(String s) => s;

/// Yer tutuculu metin: `displayTextArgs('{n} kart', {'n': 3})`.
/// Önce şablon çevrilir, sonra `{ad}` yerlerine değerler konur.
String displayTextArgs(String template, Map<String, Object?> args) {
  var s = displayText(template);
  args.forEach((k, v) => s = s.replaceAll('{$k}', '${v ?? ''}'));
  return s;
}

/// Kısa yazım: `'Kaleci'.dt`, `'{n} kart'.dtArgs({'n': 3})`
extension DisplayTextX on String {
  String get dt => displayText(this);
  String dtArgs(Map<String, Object?> args) => displayTextArgs(this, args);
}
