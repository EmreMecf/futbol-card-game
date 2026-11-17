// V2.1 HTML prototipindeki gömülü PNG ekranlarını assets/v21/screens altına
// çıkarır ve design/reference/v21_screens_manifest.json dosyasını yazar.
//
// Kullanım (proje kökünden):
//   dart run tool/v21/extract_reference.dart \
//     design/reference/FutbolCard_V21_Telefon_HTML_Prototip.html
//
// Uzaktan (Higgsfield/CloudFront) yüklenen ekranlar indirilmez; manifestte
// `remote` alanıyla listelenir.
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final source = args.isNotEmpty ? args.first : 'design/reference/FutbolCard_V21_Telefon_HTML_Prototip.html';
  const outDir = 'assets/v21/screens';
  const manifestPath = 'design/reference/v21_screens_manifest.json';

  final lines = File(source).readAsLinesSync();
  final viewsLine = lines.firstWhere((l) => l.trimLeft().startsWith('const VIEWS='));
  final hotspotsLine = lines.firstWhere((l) => l.trimLeft().startsWith('const HOTSPOTS='));

  final views = jsonDecode(_jsonPart(viewsLine, 'const VIEWS=')) as List;
  final hotspots = jsonDecode(_jsonPart(hotspotsLine, 'const HOTSPOTS=')) as Map<String, dynamic>;

  Directory(outDir).createSync(recursive: true);
  final rows = <Map<String, Object?>>[];
  for (final raw in views.cast<Map<String, dynamic>>()) {
    final id = raw['id'] as String;
    final src = raw['src'] as String;
    final row = <String, Object?>{
      for (final e in raw.entries)
        if (e.key != 'src') e.key: e.value,
    };
    const prefix = 'data:image/png;base64,';
    if (src.startsWith(prefix)) {
      final bytes = base64Decode(src.substring(prefix.length));
      final path = '$outDir/$id.png';
      File(path).writeAsBytesSync(bytes);
      row['asset'] = path;
      row['width'] = _u32(bytes, 16);
      row['height'] = _u32(bytes, 20);
      row['bytes'] = bytes.length;
    } else {
      row['remote'] = src;
    }
    row['hotspots'] = hotspots[id] ?? const [];
    rows.add(row);
    stdout.writeln(
      '$id\t${row['kind']}\t${row['width'] ?? '-'}x'
      '${row['height'] ?? '-'}\t${row['title']}',
    );
  }
  File(manifestPath).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(rows));
  stdout.writeln('Manifest: $manifestPath (${rows.length} ekran)');
}

String _jsonPart(String line, String marker) {
  var s = line.trim().substring(marker.length);
  if (s.endsWith(';')) s = s.substring(0, s.length - 1);
  return s;
}

int _u32(List<int> b, int o) => (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];
