// DİL DESTEĞİ (Türkçe / English)
//
// 1. Kodda `.tr` / `.trArgs` (ve ortak paketteki `.dt`) ile işaretli her
//    metnin İngilizcesi var ve yer tutucuları aynı.
// 2. Modellerdeki etiketler (mevki, nadirlik, taktik, oyun tarzı) çevrilir.
// 3. Sunucu metinleri: tam eşleşme, şablon ve yalnız bilinen alanlar.
// 4. Dil seçimi saklanır; ilk açılışta cihaz diline göre seçilir.
// 5. Arayüz dosyalarında işaretlenmemiş Türkçe metin kalmadı.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/l10n/app_language.dart';
import 'package:futbol_card/core/l10n/server_text.dart';
import 'package:futbol_card/core/l10n/strings_en.dart';
import 'package:futbol_card/ui_v21/utilities/v21_format.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dart kaynak metnindeki kaçışları çözer
String _coz(String ham) => ham.replaceAllMapped(
      RegExp(r'\\(.)'),
      (m) => switch (m.group(1)) { 'n' => '\n', 't' => '\t', final c => c! },
    );

final _isaretli = RegExp(r'''(?<![\w$])(['"])((?:(?!\1)[^\\\n]|\\.)*)\1\.(tr|trArgs|dt|dtArgs)\b''');

Iterable<File> _dartDosyalari(String klasor) => Directory(klasor)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart') && !f.path.endsWith('.freezed.dart'))
    .where((f) => !f.path.replaceAll('\\', '/').contains('/l10n/'));

Set<String> _yerTutucular(String s) => RegExp(r'\{\w+\}').allMatches(s).map((m) => m.group(0)!).toSet();

void main() {
  tearDown(() => AppLanguageController.instance.value = AppLanguage.tr);

  test('işaretli her metnin İngilizcesi var, yer tutucuları aynı', () {
    final eksik = <String>[];
    final uyumsuz = <String>[];
    for (final klasor in ['lib', 'packages/shared_models/lib']) {
      for (final f in _dartDosyalari(klasor)) {
        for (final m in _isaretli.allMatches(f.readAsStringSync())) {
          final anahtar = _coz(m.group(2)!);
          final en = kEnStrings[anahtar];
          if (en == null) {
            eksik.add('${f.path}: $anahtar');
          } else if (!_yerTutucular(anahtar).containsAll(_yerTutucular(en)) ||
              !_yerTutucular(en).containsAll(_yerTutucular(anahtar))) {
            uyumsuz.add('$anahtar -> $en');
          }
        }
      }
    }
    expect(eksik, isEmpty, reason: 'İngilizcesi eksik metinler');
    expect(uyumsuz, isEmpty, reason: 'yer tutucusu farklı çeviriler');
  });

  test('Türkçede metin aynen, İngilizcede çevirisi; yer tutucular dolar', () {
    expect('KARTI OYNA'.tr, 'KARTI OYNA');
    expect('MASADA {pot}'.trArgs({'pot': 3}), 'MASADA 3');
    AppLanguageController.instance.value = AppLanguage.en;
    expect('AYARLAR'.tr, 'SETTINGS');
    expect('MASADA {pot}'.trArgs({'pot': 3}), 'ON THE TABLE 3');
    // Çevirisi olmayan metin kaybolmaz
    expect('Bilinmeyen bir metin'.tr, 'Bilinmeyen bir metin');
  });

  test('model etiketleri (mevki, nadirlik, taktik, oyun tarzı) çevrilir', () {
    final eski = displayText;
    addTearDown(() => displayText = eski);
    displayText = (s) => s.tr;

    final etiketler = <String>[
      for (final p in CardPosition.values) ...[p.label, p.shortLabel],
      for (final t in CardTier.values) t.label,
      for (final t in MatchTactic.values) ...[t.label, if (t.hint.isNotEmpty) t.hint],
      for (final p in Playstyle.values) p.label,
      for (final o in MatchOutcome.values) ...[o.label, o.shortLabel],
      for (final a in const CardAttributes(shooting: 1, pace: 1, dribbling: 1, acceleration: 1, defending: 1, physical: 1).entries)
        a.label,
    ];
    final eksik = [for (final e in etiketler) if (!hasEnglish(e)) e];
    expect(eksik, isEmpty);

    AppLanguageController.instance.value = AppLanguage.en;
    expect(CardPosition.goalkeeper.label, 'Goalkeeper');
    expect(MatchTactic.highPress.label, 'High Press');
    expect(MatchOutcome.win.label, 'Win');
  });

  group('sunucu metinleri', () {
    test('Türkçede dokunulmaz', () {
      final veri = {'message': 'Yeterli altin yok.'};
      expect(identical(ServerText.translateJson(veri), veri), isTrue);
    });

    test('tam eşleşme ve şablon', () {
      AppLanguageController.instance.value = AppLanguage.en;
      expect(ServerText.translate('Sira sizde degil.'), "It's not your turn.");
      expect(ServerText.translate('Yeterli elmas yok. Gerekli: 12, mevcut: 3'), 'Not enough gems. Needed: 12, you have: 3');
      expect(ServerText.translate('Sezon 4'), 'Season 4');
      expect(ServerText.translate('Hic bilinmeyen mesaj'), 'Hic bilinmeyen mesaj');
    });

    test('yalnız bilinen alanlar çevrilir; kullanıcı adı ve kodlar korunur', () {
      AppLanguageController.instance.value = AppLanguage.en;
      final sonuc = ServerText.translateJson(<String, dynamic>{
        'username': 'Kadrom',
        'slug': 'Kadrom',
        'missions': [
          {'title': '3 sandık aç', 'description': 'Bu hafta 3 sandık aç.', 'slug': 'weekly_chests_3'},
        ],
        'name': 'Kadrom',
      }) as Map<String, dynamic>;
      expect(sonuc['username'], 'Kadrom');
      expect(sonuc['slug'], 'Kadrom');
      expect(sonuc['name'], 'My Squad');
      final gorev = (sonuc['missions'] as List).single as Map<String, dynamic>;
      expect(gorev['title'], 'Open 3 chests');
      expect(gorev['description'], 'Open 3 chests this week.');
      expect(gorev['slug'], 'weekly_chests_3');
    });
  });

  group('dil seçimi', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('ilk açılış: cihaz Türkçeyse Türkçe, değilse İngilizce', () async {
      await AppLanguageController.instance.load(deviceLanguageCode: 'tr');
      expect(currentLanguage, AppLanguage.tr);
      await AppLanguageController.instance.load(deviceLanguageCode: 'de');
      expect(currentLanguage, AppLanguage.en);
    });

    test('seçim saklanır ve cihaz dilinden önce gelir', () async {
      await AppLanguageController.instance.select(AppLanguage.en);
      AppLanguageController.instance.value = AppLanguage.tr;
      await AppLanguageController.instance.load(deviceLanguageCode: 'tr');
      expect(currentLanguage, AppLanguage.en);
    });
  });

  test('İngilizcede büyük harf Türkçe kurala uymaz', () {
    expect(V21Format.upper('kadro'), 'KADRO');
    expect(V21Format.upper('giriş'), 'GİRİŞ');
    AppLanguageController.instance.value = AppLanguage.en;
    expect(V21Format.upper('win'), 'WIN');
  });

  test('arayüz dosyalarında işaretlenmemiş Türkçe metin yok', () {
    // Bilerek ham bırakılanlar: günlük kayıtları, eşleştirme kalıpları ve
    // okunurken çevrilen etiketler (alanı `_label`, getter'ı `.tr`).
    const izinli = {
      'Güce göre (yüksekten düşüğe)', 'Güce göre (düşükten yükseğe)', 'Seviyeye göre', 'İsme göre',
      'Bağlı', 'Bağlanıyor…', 'Yeniden bağlanıyor…', 'Bağlantı yok', 'Bu bölüm henüz açık değil.',
      'Tümü', 'pelé', 'ı', 'İ', 'EN DÜŞÜKLER', 'BOŞALT', 'YENİ MAÇ',
    };
    final turkce = RegExp(r'[ÇĞİÖŞÜçğıöşü]');
    final metin = RegExp(r"""'((?:[^'\\\n]|\\.)*)'(?!\.tr)""");
    final kalan = <String>[];
    for (final f in _dartDosyalari('lib')) {
      final satirlar = f.readAsLinesSync();
      for (var i = 0; i < satirlar.length; i++) {
        final s = satirlar[i].trimLeft();
        if (s.startsWith('//') || s.startsWith('import ')) continue;
        final onceki = i > 0 ? satirlar[i - 1] : '';
        if (s.contains('AppLogger.') || onceki.contains('AppLogger.')) continue;
        for (final m in metin.allMatches(satirlar[i])) {
          final t = _coz(m.group(1)!);
          if (!turkce.hasMatch(t) || izinli.contains(t)) continue;
          // `${...}` içindeki iç metinler ayrıca yakalanır
          if (t.contains(r'${')) continue;
          kalan.add('${f.path}:${i + 1}: $t');
        }
      }
    }
    expect(kalan, isEmpty);
  });
}
