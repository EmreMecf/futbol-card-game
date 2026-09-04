import 'package:flutter/material.dart';

/// Uygulamanin renk paleti.
/// Stadyum atmosferi: koyu lacivert zemin + saha yesili + kupa altini.
class AppColors {
  const AppColors._();

  // Ana renkler
  static const Color primary = Color(0xFF00A651); // Saha yesili
  static const Color primaryDark = Color(0xFF00703C);
  static const Color accent = Color(0xFFFFC72C); // Kupa altini

  // Arka planlar
  static const Color background = Color(0xFF0B1120);
  static const Color surface = Color(0xFF16203A);
  static const Color surfaceLight = Color(0xFF1F2C4D);

  /// Masaustu kenar cubugu: ana zeminden bir tik acik ki
  /// icerik alaniyla arasindaki sinir cizgi olmadan da okunsun.
  static const Color sidebar = Color(0xFF0E1628);

  // Metin
  static const Color textPrimary = Color(0xFFF5F7FA);
  static const Color textSecondary = Color(0xFF9AA5B8);

  // Durum renkleri
  static const Color success = Color(0xFF29CC7A);
  static const Color danger = Color(0xFFE5484D);
  static const Color warning = Color(0xFFFFB020);

  // ---- KART SEVIYE RENKLERI ----
  static const Color tierBronze = Color(0xFFB0764F);
  static const Color tierSilver = Color(0xFFC0C6CF);
  static const Color tierGold = Color(0xFFE8B923);
  static const Color tierDiamond = Color(0xFF57D4F0);
  static const Color tierLegend = Color(0xFFB44BFF);

  /// Legend kartlarin isildayan cercevesi icin degrade
  static const LinearGradient legendGradient = LinearGradient(
    colors: [Color(0xFFB44BFF), Color(0xFFFF6BD6), Color(0xFFFFC72C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
