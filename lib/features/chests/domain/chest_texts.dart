import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Sandık envanteri başka bir yerden değişti (ör. günlük sandık alındı):
/// değeri artırınca açık sandık ekranları sunucudan yenilenir.
final ValueNotifier<int> chestInventoryChanged = ValueNotifier<int>(0);

/// Süre metni: "2 sa 15 dk"; [clock] ile "1:23:45"
String chestDuration(Duration d, {bool clock = false}) {
  if (clock) {
    final s = d.inHours, dk = d.inMinutes % 60, sn = d.inSeconds % 60;
    String iki(int n) => n.toString().padLeft(2, '0');
    return s > 0 ? '$s:${iki(dk)}:${iki(sn)}' : '${iki(dk)}:${iki(sn)}';
  }
  if (d.inSeconds <= 0) return 'Anında';
  if (d.inHours >= 1 && d.inMinutes % 60 == 0) return '${d.inHours} sa';
  if (d.inHours >= 1) return '${d.inHours} sa ${d.inMinutes % 60} dk';
  return '${math.max(1, d.inMinutes)} dk';
}

/// Nadirlik adı
String tierNameTr(String tier) => switch (tier) {
      'bronze' => 'Bronz',
      'silver' => 'Gümüş',
      'gold' => 'Altın',
      'diamond' => 'Elmas',
      'legend' => 'Efsane',
      _ => tier,
    };

/// Joker parça özeti: "Bronz ×2 · Gümüş ×1"
String jokerSummary(Map<String, int> jokers) =>
    jokers.entries.where((e) => e.value > 0).map((e) => '${tierNameTr(e.key)} ×${e.value}').join(' · ');

/// 038: ek item özeti: "Sandık anahtarı · Ustalık kitabı (Elmas)"
String extrasSummary(Map<String, int> extras) => extras.entries.where((e) => e.value > 0).map((e) {
      final ad = switch (e.key) {
        'chest_key' => 'Sandık anahtarı',
        final k when k.startsWith('mastery_book_') => 'Ustalık kitabı (${tierNameTr(k.substring(13))})',
        final k => k,
      };
      return e.value > 1 ? '$ad ×${e.value}' : ad;
    }).join(' · ');
