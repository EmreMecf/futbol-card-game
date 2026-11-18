import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// V2.1 testleri için yazı tipi yükleme ve boyutlar.
///
/// Golden karşılaştırması yalnız Windows'ta yapılır (yazı tipi çizimi
/// işletim sistemine göre birkaç piksel değişir; mevcut golden'lar da
/// Windows'ta üretildi). Taşma/yerleşim denetimleri her platformda çalışır.
///
/// NOT: `test/goldens/golden_araclari.dart` MaterialIcons yolunu
/// `C:/dev/flutter/...` olarak sabit yazıyor; bu makinede Flutter
/// `%USERPROFILE%/dev/flutter` altında olduğu için oradaki golden'lar
/// ATLANIYOR. V2.1 testleri yolu FLUTTER_ROOT'tan bulur.
String? get v21GoldenSkipReason {
  if (!Platform.isWindows) return 'Golden yalnız Windows (yazı tipi çizimi)';
  if (_materialIcons() == null) return 'MaterialIcons yazı tipi bulunamadı';
  return null;
}

String? _materialIcons() {
  final roots = <String>[
    ?Platform.environment['FLUTTER_ROOT'],
    // flutter_tester: <flutter>/bin/cache/artifacts/engine/<platform>/flutter_tester
    File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path,
  ];
  for (final r in roots) {
    final f = File('$r/bin/cache/artifacts/material_fonts/materialicons-regular.otf');
    if (f.existsSync()) return f.path;
    final g = File('$r/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (g.existsSync()) return g.path;
  }
  return null;
}

bool _loaded = false;

/// Barlow Condensed, Nunito ve MaterialIcons'u test motoruna yükler
/// (yüklenmezse metinler kutu olarak çizilir).
Future<void> loadV21Fonts() async {
  if (_loaded) return;
  Future<void> load(String family, Iterable<String> paths) async {
    final loader = FontLoader(family);
    for (final p in paths) {
      loader.addFont(Future.value(ByteData.sublistView(File(p).readAsBytesSync())));
    }
    await loader.load();
  }

  final fonts = Directory('assets/fonts').listSync().whereType<File>().map((f) => f.path).toList();
  await load('BarlowCondensed', fonts.where((f) => f.contains('Barlow') && f.endsWith('.ttf')));
  await load('Nunito', fonts.where((f) => f.contains('Nunito') && f.endsWith('.ttf')));
  final icons = _materialIcons();
  if (icons != null) await load('MaterialIcons', [icons]);
  _loaded = true;
}

/// Oyun yalnız telefon ve tablette, her ikisinde de DİKEY çalışır (web ve
/// masaüstü yok; yön main.dart, Info.plist ve AndroidManifest'te kilitli).
/// 4 telefon + 3 dikey tablet: iPad mini/9.7" (768×1024), iPad Air /
/// 10. nesil (820×1180), iPad Pro 12.9" (1024×1366).
const kV21Sizes = <Size>[
  Size(320, 568),
  Size(360, 640),
  Size(390, 844),
  Size(412, 915),
  Size(768, 1024),
  Size(820, 1180),
  Size(1024, 1366),
];

/// Yalnız taşma denetlenen ek boyutlar: katlanır telefon, yatay telefon,
/// yatay tablet ve masaüstü web. Görüntüleri depoda tutulmaz.
const kV21ExtraSizes = <Size>[
  Size(280, 653),
  Size(600, 960),
  Size(844, 390),
  Size(915, 412),
  Size(1024, 768),
  Size(1180, 820),
  Size(1280, 720),
  Size(1366, 768),
  Size(1440, 900),
  Size(1920, 1080),
  Size(2560, 1440),
];

/// Taşma denetiminin çalıştığı bütün boyutlar
const kV21AllSizes = <Size>[...kV21Sizes, ...kV21ExtraSizes];

/// Bu boyutun görüntüsü karşılaştırılır mı? (V21_TUM_GOLDEN=1: hepsi)
bool v21GoldenFor(Size s) => kV21Sizes.contains(s) || Platform.environment['V21_TUM_GOLDEN'] == '1';

String v21SizeName(Size s) => '${s.width.toInt()}x${s.height.toInt()}';
