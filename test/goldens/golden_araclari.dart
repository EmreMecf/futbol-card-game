import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Golden testleri için ortak araçlar.
///
/// NEDEN SADECE WINDOWS?
/// Golden görüntüleri piksel piksel karşılaştırılır. Yazı tipi çizimi
/// işletim sistemine göre birkaç piksel değişir; ayrıca referans
/// ekranlardaki emojiler Windows'un Segoe UI Emoji yazı tipiyle çizildi.
/// CI (Ubuntu) bu yazı tipine sahip değil. Bu yüzden golden testleri
/// yazı tipi dosyaları bulunamazsa ATLANIR (sebebi yazılarak); "geçti"
/// sayılmaz.
///
/// Güncelleme: flutter test test/goldens --update-goldens
const _emojiFont = 'C:/Windows/Fonts/seguiemj.ttf';
const _ikonFont = 'C:/dev/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';

/// Golden yazı tipleri yoksa atlama sebebi, varsa null
String? get goldenSkipReason {
  if (!File(_emojiFont).existsSync()) return 'Segoe UI Emoji yok (golden sadece Windows)';
  if (!File(_ikonFont).existsSync()) return 'MaterialIcons yazı tipi bulunamadı';
  return null;
}

bool _yuklendi = false;

Future<void> loadGoldenFonts() async {
  if (_yuklendi) return;
  Future<void> yukle(String aile, Iterable<String> yollar) async {
    final l = FontLoader(aile);
    for (final y in yollar) {
      l.addFont(Future.value(ByteData.sublistView(File(y).readAsBytesSync())));
    }
    await l.load();
  }

  final fontlar = Directory('assets/fonts').listSync().whereType<File>().map((f) => f.path).toList();
  await yukle('BarlowCondensed', fontlar.where((f) => f.contains('Barlow') && f.endsWith('.ttf')));
  await yukle('Nunito', fontlar.where((f) => f.contains('Nunito') && f.endsWith('.ttf')));
  await yukle('MaterialIcons', [_ikonFont]);
  await yukle('Segoe UI Emoji', [_emojiFont]);
  _yuklendi = true;
}

/// Kullanıcının istediği test boyutları
const kGoldenSizes = <Size>[
  Size(320, 568),
  Size(360, 640),
  Size(390, 844),
  Size(412, 915),
  Size(768, 1024),
  Size(1366, 768),
];

String sizeName(Size s) => '${s.width.toInt()}x${s.height.toInt()}';
