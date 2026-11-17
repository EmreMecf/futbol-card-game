/// V2.1 metin biçimleri (Türkçe).
abstract final class V21Format {
  /// 2450 → "2.450"
  static String thousands(int value) {
    final negative = value < 0;
    final digits = value.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return negative ? '-$buffer' : buffer.toString();
  }

  /// Sayaç: 1:23:45 (saat yoksa 23:45)
  static String countdown(Duration d) {
    final total = d.isNegative ? 0 : d.inSeconds;
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  /// Kısa süre: 21600 sn → "6 sa", 2700 sn → "45 dk", 0 → "Anında"
  static String shortDuration(int seconds) {
    if (seconds <= 0) return 'Anında';
    if (seconds >= 3600 && seconds % 3600 == 0) return '${seconds ~/ 3600} sa';
    if (seconds >= 3600) {
      final h = seconds ~/ 3600;
      final m = (seconds % 3600) ~/ 60;
      return '$h sa $m dk';
    }
    return '${(seconds / 60).ceil()} dk';
  }

  /// Türkçe büyük harf (i → İ, ı → I)
  static String upper(String s) => s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
}
