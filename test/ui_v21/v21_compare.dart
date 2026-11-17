import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

/// Referans PNG ile Flutter çıktısını bölge bölge karşılaştırır ve
/// `docs/ui_v21/compare/` altına yan yana görsel + fark ısı haritası yazar.
Future<Map<String, double>?> compareWithReference(
  RenderRepaintBoundary boundary, {
  required String screen,
  required String title,
  required Map<String, (int, int)> regions,
}) async {
  final flutterImg = await boundary.toImage();
  final refImg = await loadReference(screen);
  const w = 390, h = 844;
  final a = (await flutterImg.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
  final b = (await refImg.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();

  final heat = Uint8List(w * h * 4);
  final result = <String, double>{};
  var total = 0.0;
  for (var i = 0; i < w * h; i++) {
    final d = _px(a, b, i * 4);
    total += d;
    _heat(heat, i * 4, d);
  }
  result['overall'] = total / (w * h);
  for (final e in regions.entries) {
    var sum = 0.0;
    var big = 0;
    for (var y = e.value.$1; y < e.value.$2; y++) {
      for (var x = 0; x < w; x++) {
        final d = _px(a, b, (y * w + x) * 4);
        sum += d;
        if (d > 40) big++;
      }
    }
    final n = (e.value.$2 - e.value.$1) * w;
    result[e.key] = sum / n;
    result['${e.key} >40 %'] = big * 100 / n;
  }

  final side = _sideBySide([b, a, heat], w, h);
  final out = Directory('docs/ui_v21/compare')..createSync(recursive: true);
  await _writePng(await fromPixels(side, w * 3, h), '${out.path}/${screen}_390x844_side_by_side.png');
  await _writePng(flutterImg, '${out.path}/${screen}_390x844_flutter.png');
  final lines = [
    '# V2.1 $title — referans karşılaştırması (390×844)',
    '',
    'Kanal başına ortalama mutlak fark (0-255) ve farkı 40\'tan büyük piksel oranı.',
    '',
    '| Bölge | Ortalama fark | >40 piksel % |',
    '|---|---:|---:|',
    for (final k in regions.keys)
      '| $k | ${result[k]!.toStringAsFixed(1)} | ${result['$k >40 %']!.toStringAsFixed(1)} |',
    '| **Tüm ekran** | **${result['overall']!.toStringAsFixed(1)}** | |',
  ];
  File('${out.path}/${screen}_390x844_report.md').writeAsStringSync('${lines.join('\n')}\n');
  return result;
}

/// Öğe karşılaştırması: [crops] her biri referans ekrandan bir dikdörtgen
/// ve aynı boyutta çizilmiş Flutter görüntüsü. Satır satır (referans |
/// flutter | fark, 2×) bir sayfa ve tablo yazar; öğe başına ortalama farkı
/// döndürür.
Future<Map<String, double>> compareElements(
  List<({String name, String screen, ui.Rect rect, ui.Image image})> crops, {
  required String outName,
  required String title,
}) async {
  final result = <String, double>{};
  const scale = 2;
  final rows = <(Uint8List, int, int)>[];
  for (final c in crops) {
    final ref = await loadReference(c.screen);
    final rb = (await ref.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
    final fb = (await c.image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
    final w = c.rect.width.round(), h = c.rect.height.round();
    final x0 = c.rect.left.round(), y0 = c.rect.top.round();
    final refCrop = Uint8List(w * h * 4);
    final heat = Uint8List(w * h * 4);
    var sum = 0.0;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final si = ((y0 + y) * ref.width + (x0 + x)) * 4;
        final di = (y * w + x) * 4;
        refCrop.setRange(di, di + 4, rb, si);
        final d = _px(refCrop, fb, di);
        sum += d;
        _heat(heat, di, d);
      }
    }
    result[c.name] = sum / (w * h);
    rows.add((_scale(_sideBySide([refCrop, fb, heat], w, h), w * 3, h, scale), w * 3 * scale, h * scale));
  }
  // Satırları alt alta diz (en geniş satıra göre)
  final width = rows.map((r) => r.$2).reduce((a, b) => a > b ? a : b);
  const gap = 6;
  final height = rows.fold<int>(0, (s, r) => s + r.$3 + gap);
  final sheet = Uint8List(width * height * 4);
  for (var i = 3; i < sheet.length; i += 4) {
    sheet[i] = 255;
  }
  var oy = 0;
  for (final (px, w, h) in rows) {
    for (var y = 0; y < h; y++) {
      sheet.setRange(((oy + y) * width) * 4, ((oy + y) * width + w) * 4, px, y * w * 4);
    }
    oy += h + gap;
  }
  final out = Directory('docs/ui_v21/compare')..createSync(recursive: true);
  await _writePng(await fromPixels(sheet, width, height), '${out.path}/${outName}_elements.png');
  final lines = [
    '# V2.1 $title — öğe karşılaştırması',
    '',
    'Her öğe, referans PNG\'deki aynı dikdörtgenin üstüne aynı yerde çizildi. Kanal başına ortalama mutlak fark (0-255).',
    'Görsel: `${outName}_elements.png` (satır başına referans | Flutter | fark, 2×).',
    '',
    '| Öğe | Kaynak (ekran, x,y,g,y) | Ortalama fark |',
    '|---|---|---:|',
    for (final c in crops)
      '| ${c.name} | ${c.screen} ${c.rect.left.round()},${c.rect.top.round()},${c.rect.width.round()},${c.rect.height.round()} | ${result[c.name]!.toStringAsFixed(1)} |',
  ];
  File('${out.path}/${outName}_elements_report.md').writeAsStringSync('${lines.join('\n')}\n');
  return result;
}

final _refCache = <String, ui.Image>{};

/// `assets/v21/screens/<screen>.png` (önbellekli)
Future<ui.Image> loadReference(String screen) async {
  final hit = _refCache[screen];
  if (hit != null) return hit;
  final codec = await ui.instantiateImageCodec(File('assets/v21/screens/$screen.png').readAsBytesSync());
  final img = (await codec.getNextFrame()).image;
  _refCache[screen] = img;
  return img;
}

double _px(Uint8List a, Uint8List b, int i) =>
    ((a[i] - b[i]).abs() + (a[i + 1] - b[i + 1]).abs() + (a[i + 2] - b[i + 2]).abs()) / 3;

void _heat(Uint8List heat, int i, double d) {
  final v = (d * 2).clamp(0, 255).toInt();
  heat[i] = v;
  heat[i + 1] = (v * 0.3).toInt();
  heat[i + 2] = 255 - v;
  heat[i + 3] = 255;
}

Uint8List _sideBySide(List<Uint8List> parts, int w, int h) {
  final n = parts.length;
  final out = Uint8List(w * n * h * 4);
  for (var y = 0; y < h; y++) {
    for (var p = 0; p < n; p++) {
      out.setRange((y * w * n + p * w) * 4, (y * w * n + p * w + w) * 4, parts[p], y * w * 4);
    }
  }
  return out;
}

Uint8List _scale(Uint8List px, int w, int h, int s) {
  final out = Uint8List(w * s * h * s * 4);
  for (var y = 0; y < h * s; y++) {
    for (var x = 0; x < w * s; x++) {
      final si = ((y ~/ s) * w + (x ~/ s)) * 4;
      out.setRange((y * w * s + x) * 4, (y * w * s + x) * 4 + 4, px, si);
    }
  }
  return out;
}

Future<void> _writePng(ui.Image img, String path) async =>
    File(path).writeAsBytesSync((await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());

Future<ui.Image> fromPixels(Uint8List px, int w, int h) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(px);
  final desc = ui.ImageDescriptor.raw(buffer, width: w, height: h, pixelFormat: ui.PixelFormat.rgba8888);
  final codec = await desc.instantiateCodec();
  return (await codec.getNextFrame()).image;
}
