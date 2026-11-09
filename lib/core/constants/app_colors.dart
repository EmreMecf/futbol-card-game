import 'package:flutter/material.dart';

import '../theme/ref_tokens.dart';

/// Uygulamanın ESKİ renk adları — artık referans HTML paletine bağlı.
///
/// ===================================================================
/// FAZ 8: TEK PALET
/// ===================================================================
/// Tasarımın tek kaynağı `design-reference/futbol-card-arena.html`
/// ve onun renkleri [Ref] sınıfında. Henüz satır satır yeniden
/// yazılmamış ekranlar (giriş, ayarlar, lig değişikliği, walkout...)
/// `AppColors` adlarını kullanıyor. İsimler korunup DEĞERLER referansa
/// bağlandı; böylece bütün ekranlar aynı paleti kullanıyor ve hiçbir
/// ekran kırılmıyor. Yeni kod doğrudan [Ref] kullanmalı.
///
/// OKUNABİLİRLİK (WCAG kontrast oranı, 4.5 ve üstü = normal metin):
///   text  / bg     17.61
///   muted / panel   7.07
///   accent / panel 10.41
///   red   / panel   5.87
///
/// DİKKAT — BUTON YAZISI: yeşil zemin üstünde yazı koyu ([onPrimary], 11.22).
class AppColors {
  const AppColors._();

  // ==================================================================
  // ESKİ MD ADLARI (referans karşılıklarına bağlı)
  // ==================================================================
  static const Color obsidian = Ref.bg;
  static const Color deepNavy = Ref.panel;
  static const Color midnightBlue = Ref.panel;
  static const Color emerald = Ref.accent;
  static const Color cyan = Color(0xFF72DFFF); // referans Elmas nadirliği
  static const Color championGold = Ref.gold;
  static const Color victoryGold = Ref.gold;
  static const Color dangerRed = Ref.red;
  static const Color epicPurple = Ref.purple;

  // ==================================================================
  // ANLAMSAL ADLAR (uygulama bunları kullanır)
  // ==================================================================

  /// Birincil eylem, aktif sekme, başarı vurgusu (--accent)
  static const Color primary = Ref.accent;

  /// Basılı buton, gölge (referans .bar dolgusunun koyu ucu)
  static const Color primaryDark = Color(0xFF0BBF88);

  /// Yeşil zemin üstündeki yazı. Beyaz DEĞİL — bkz. sınıf açıklaması.
  static const Color onPrimary = Ref.bg;

  /// Altın: coin, ödül, kazanma anı (--gold)
  static const Color accent = Ref.gold;

  /// Çerçeve, rozet, lig armaları
  static const Color gold = Ref.gold;

  // ---- Arka planlar ----
  static const Color background = Ref.bg;
  static const Color sidebar = Ref.panel;
  static const Color surface = Ref.panel;

  /// Kenarlık, ayraç, pasif iz (referans .bar izi)
  static const Color surfaceLight = Ref.barTrack;

  // ---- Metin ----
  static const Color textPrimary = Ref.text;
  static const Color textSecondary = Ref.muted;

  // ---- Durum ----
  static const Color success = Ref.accent;
  static const Color danger = Ref.red;

  /// Uyarı: altından ayrışsın diye turuncu kalır
  static const Color warning = Color(0xFFF59E0B);

  /// Bilgi: canlı/aktif durum, bağlantı, sayaç (--blue)
  static const Color info = Ref.blue;

  // ==================================================================
  // KART SEVİYE RENKLERİ (referans .collectible nadirlik renkleri)
  // ==================================================================
  static const Color tierBronze = Color(0xFFBF8766);
  static const Color tierSilver = Color(0xFFB8CEDB);
  static const Color tierGold = Color(0xFFF3CE70);
  static const Color tierDiamond = Color(0xFF72DFFF);
  static const Color tierLegend = Color(0xFFD18AFF);

  /// Efsane: mor -> altın
  static const LinearGradient legendGradient = LinearGradient(
    colors: [Ref.purple, Color(0xFFD18AFF), Ref.gold],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
