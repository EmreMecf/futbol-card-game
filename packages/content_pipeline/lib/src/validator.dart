import 'package:shared_models/shared_models.dart';

import 'blocklist.dart';
import 'catalog_slot.dart';
import 'generator.dart';

/// Yapay zekâdan gelirse DOĞRUDAN reddedilen oyun değeri alanları.
const kForbiddenGameFields = <String>{
  'power', 'guc', 'rating', 'overall', 'ovr', 'tier', 'seviye', 'rarity',
  'nadirlik', 'shooting', 'pace', 'physical', 'defending', 'dribbling',
  'acceleration', 'attributes', 'stats', 'chemistry', 'kimya', 'price',
  'value', 'drop_weight',
};

class ValidationResult {
  final List<String> errors;
  final List<String> warnings;

  /// Hatasızsa temizlenmiş kimlik (yoksa null)
  final Map<String, dynamic>? clean;

  const ValidationResult(this.errors, this.warnings, this.clean);

  bool get ok => errors.isEmpty;
}

/// Yapay zekâ çıktısının BÜTÜN alanlarını denetler.
///
/// Kurallar veritabanındaki CHECK kısıtlarıyla aynı (025); ayrıca gerçek
/// kişi/marka benzerliği ve mevki–tarz uyumu denetlenir. Geçemeyen hiçbir
/// çıktı kataloğa yazılmaz.
class CharacterValidator {
  static final _adDeseni = RegExp(r"^[A-Za-zÀ-ÖØ-öø-ÿĀ-žçğıİöşüÇĞÖŞÜ][A-Za-zÀ-ÖØ-öø-ÿĀ-žçğıİöşüÇĞÖŞÜ'\-]*$");

  ValidationResult validate(
    Map<String, dynamic> raw,
    CatalogSlot slot, {
    List<String> existingNames = const [],
  }) {
    final hata = <String>[];
    final uyari = <String>[];

    // ---- 1) Oyun değeri gönderildi mi? (en önemli kural) ----
    void oyunDegeriAra(Map m, String yol) {
      for (final e in m.entries) {
        final k = e.key.toString().toLowerCase();
        if (kForbiddenGameFields.contains(k)) {
          hata.add('Yapay zekâ oyun değeri gönderdi ($yol${e.key}); reddedildi. '
              'Güç ve özellikleri yalnızca Denge Motoru belirler.');
        }
        if (e.value is Map) oyunDegeriAra(e.value as Map, '$yol${e.key}.');
      }
    }

    oyunDegeriAra(raw, '');

    // ---- 2) Alan kümesi tam olarak beklenen ----
    for (final k in raw.keys) {
      if (!kIdentityFields.contains(k) && !kForbiddenGameFields.contains(k.toLowerCase())) {
        hata.add('Beklenmeyen alan: $k');
      }
    }
    for (final k in kIdentityFields) {
      if (!raw.containsKey(k)) hata.add('Eksik alan: $k');
    }
    if (hata.isNotEmpty) return ValidationResult(hata, uyari, null);

    String? metin(String k, int min, int max) {
      final v = raw[k];
      if (v is! String) {
        hata.add('$k metin olmalı');
        return null;
      }
      final t = v.trim();
      if (t.length < min || t.length > max) {
        hata.add('$k uzunluğu $min-$max olmalı (şu an ${t.length})');
      }
      return t;
    }

    // ---- 3) Ad ----
    final ad = metin('given_name', 2, 20);
    final soyad = metin('family_name', 2, 24);
    for (final (alan, d) in [('given_name', ad), ('family_name', soyad)]) {
      if (d != null && !_adDeseni.hasMatch(d)) {
        hata.add('$alan sadece harf, kesme ve tire içerebilir');
      }
    }
    if (ad != null && soyad != null) {
      final tam = '$ad $soyad';
      final yasakli = findBlockedTerms(tam);
      if (yasakli.isNotEmpty) {
        hata.add('Ad gerçek kişi/markayla eşleşiyor: ${yasakli.join(', ')}');
      }
      final benzer = closestRealPerson(tam);
      if (benzer != null) hata.add('Ad gerçek bir kişiye çok benziyor: $benzer');
      final n = normalizeName(tam);
      for (final v in existingNames) {
        final s = similarity(n, normalizeName(v));
        if (s == 1) {
          hata.add('Bu ad katalogda zaten var: $v');
        } else if (s >= 0.85) {
          uyari.add('Katalogdaki "$v" adına çok benziyor (%${(s * 100).round()})');
        }
      }
    }

    // ---- 4) Mevki ve tarz ----
    final ikincilKod = raw['secondary_position'];
    CardPosition? ikincil;
    if (ikincilKod != null) {
      try {
        ikincil = CardPosition.fromCode(ikincilKod.toString());
        if (ikincil == slot.position) hata.add('İkincil mevki ana mevkiyle aynı olamaz');
      } on ArgumentError {
        hata.add('Geçersiz ikincil mevki: $ikincilKod');
      }
    }
    final tarz = Playstyle.tryParse(raw['playstyle']?.toString());
    if (tarz == null) {
      hata.add('Geçersiz oyun tarzı: ${raw['playstyle']}');
    } else if (tarz.position != slot.position) {
      hata.add('${tarz.label} tarzı ${slot.position.label} mevkisine uymuyor');
    }

    // ---- 5) Kişilik ----
    final kisilik = raw['personality'];
    if (kisilik is! List || kisilik.length < 2 || kisilik.length > 5 ||
        kisilik.any((e) => e is! String || e.trim().length < 2 || e.trim().length > 24)) {
      hata.add('personality 2-5 adet, 2-24 karakterlik metin olmalı');
    }

    // ---- 6) Metinler ----
    final kisa = metin('bio_short', 20, 160);
    final uzun = metin('bio_long', 80, 1200);
    final gorsel = metin('visual_prompt', 40, 1500);
    for (final (alan, t) in [('bio_short', kisa), ('bio_long', uzun), ('visual_prompt', gorsel)]) {
      if (t == null) continue;
      final y = findBlockedTerms(t);
      if (y.isNotEmpty) hata.add('$alan gerçek kişi/marka içeriyor: ${y.join(', ')}');
    }

    // ---- 7) Görünüş ----
    final gorunus = raw['appearance'];
    if (gorunus is! Map) {
      hata.add('appearance nesne olmalı');
    } else {
      const alanlar = ['skin_tone', 'hair', 'face', 'build', 'accessory', 'shirt_number'];
      for (final a in alanlar) {
        if (!gorunus.containsKey(a)) hata.add('appearance.$a eksik');
      }
      for (final k in gorunus.keys) {
        if (!alanlar.contains(k)) hata.add('appearance içinde beklenmeyen alan: $k');
      }
      final no = gorunus['shirt_number'];
      if (no is! int || no < 1 || no > 99) hata.add('Forma numarası 1-99 olmalı');
      for (final a in alanlar.where((a) => a != 'shirt_number')) {
        final v = gorunus[a];
        if (v is! String || v.trim().length < 2 || v.trim().length > 80) {
          hata.add('appearance.$a 2-80 karakterlik metin olmalı');
        } else {
          final y = findBlockedTerms(v);
          if (y.isNotEmpty) hata.add('appearance.$a gerçek marka içeriyor: ${y.join(', ')}');
        }
      }
    }

    // ---- 8) Animasyon profili ----
    const profiller = ['sakin', 'dengeli', 'gosterisci', 'lider'];
    if (!profiller.contains(raw['animation_profile'])) {
      hata.add('Geçersiz animasyon profili: ${raw['animation_profile']}');
    }

    if (hata.isNotEmpty) return ValidationResult(hata, uyari, null);
    return ValidationResult(hata, uyari, {
      ...raw,
      'given_name': ad,
      'family_name': soyad,
      'bio_short': kisa,
      'bio_long': uzun,
      'visual_prompt': gorsel,
      'personality': [for (final p in kisilik as List) (p as String).trim()],
    });
  }
}
