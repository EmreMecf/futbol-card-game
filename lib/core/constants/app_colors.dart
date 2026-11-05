import 'package:flutter/material.dart';

/// Uygulamanın renk paleti — FUTBOL CARD ARENA tasarım sistemi.
///
/// ===================================================================
/// KAYNAK: MASTER PROMPT (MD) BÖLÜM 3
/// ===================================================================
/// MD'deki dokuz ana renk aşağıda AYNEN kullanılıyor. MD'de karşılığı
/// olmayan birkaç ton (kenarlık, koyu yeşil, uyarı) bu renklerden
/// TÜRETİLDİ ve yanlarında "türetildi" notu var.
///
/// ===================================================================
/// İSİMLER NEDEN DEĞİŞMEDİ?
/// ===================================================================
/// `AppColors.primary`, `surface`, `textSecondary`... uygulamada 500'ü
/// aşkın yerde kullanılıyor. İsimleri koruyup sadece DEĞERLERİ
/// değiştirince bütün ekranlar tek seferde yeni palete geçiyor ve
/// hiçbir ekran kırılmıyor. MD'deki adlar ([emerald], [cyan]...) ayrıca
/// eklendi; yeni kod onları kullanabilir.
///
/// ===================================================================
/// OKUNABİLİRLİK (WCAG kontrast oranı, 4.5 ve üstü = normal metin için yeterli)
/// ===================================================================
///   textPrimary   / background  18.24
///   textSecondary / surface      6.92
///   emerald       / surface      6.99
///   danger        / surface      4.71
///   purple        / surface      4.19  -> SADECE büyük yazı / ikon
///
/// DİKKAT — BUTON YAZISI: Emerald üstüne BEYAZ yazı 2.54 (okunmaz).
/// Yeşil zeminli butonlarda yazı [onPrimary] (koyu) olmalı: 7.72.
class AppColors {
  const AppColors._();

  // ==================================================================
  // MD PALETİ (birebir)
  // ==================================================================
  static const Color obsidian = Color(0xFF0A0C10);
  static const Color deepNavy = Color(0xFF111827);
  static const Color midnightBlue = Color(0xFF0F172A);
  static const Color emerald = Color(0xFF10B981);
  static const Color cyan = Color(0xFF22D3EE);
  static const Color championGold = Color(0xFFD4AF37);
  static const Color victoryGold = Color(0xFFFBBF24);
  static const Color dangerRed = Color(0xFFEF4444);
  static const Color epicPurple = Color(0xFF8B5CF6);

  // ==================================================================
  // ANLAMSAL ADLAR (uygulama bunları kullanır)
  // ==================================================================

  // ---- Ana renkler ----
  /// Saha yeşili: birincil eylem, aktif sekme, başarı vurgusu
  static const Color primary = emerald;

  /// Türetildi: emerald'ın koyusu (basılı buton, gölge)
  static const Color primaryDark = Color(0xFF047857);

  /// Yeşil zemin üstündeki yazı. Beyaz DEĞİL — bkz. sınıf açıklaması.
  static const Color onPrimary = obsidian;

  /// Kupa altını: coin, ödül, kazanma anı
  static const Color accent = victoryGold;

  /// Metalik / premium altın: çerçeve, rozet, lig armaları
  static const Color gold = championGold;

  // ---- Arka planlar (koyudan açığa) ----
  static const Color background = obsidian;

  /// Masaüstü kenar çubuğu: zeminden bir tık açık
  static const Color sidebar = midnightBlue;

  static const Color surface = deepNavy;

  /// Türetildi: deepNavy'nin açığı. Kenarlık, ayraç, pasif iz.
  static const Color surfaceLight = Color(0xFF1F2A3D);

  // ---- Metin ----
  static const Color textPrimary = Color(0xFFF5F7FA);

  /// Türetildi: lacivert ailesine uyan gri (slate-400)
  static const Color textSecondary = Color(0xFF94A3B8);

  // ---- Durum ----
  static const Color success = emerald;
  static const Color danger = dangerRed;

  /// Türetildi: MD'de uyarı rengi yok. Victory Gold'a çok yakın
  /// olmasın diye daha turuncu bir amber seçildi; aksi halde "uyarı"
  /// ile "ödül" aynı renkte görünürdü.
  static const Color warning = Color(0xFFF59E0B);

  /// Bilgi: canlı/aktif durum, bağlantı, sayaç
  static const Color info = cyan;

  // ==================================================================
  // KART SEVİYE RENKLERİ
  // ==================================================================
  // NOT: Bunlar rozet, filtre ve yazı rengi içindir. Kartın kendi
  // metalik çerçevesi CardTierTheme'de ayrı tanımlıdır (FAZ 3'te
  // yeniden tasarlanacak).
  static const Color tierBronze = Color(0xFFC08457);
  static const Color tierSilver = Color(0xFFCBD5E1);
  static const Color tierGold = championGold;
  static const Color tierDiamond = cyan;
  static const Color tierLegend = epicPurple;

  /// Legend: mor -> altın (MD: "mor-altın ışık")
  static const LinearGradient legendGradient = LinearGradient(
    colors: [epicPurple, Color(0xFFC084FC), victoryGold],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
