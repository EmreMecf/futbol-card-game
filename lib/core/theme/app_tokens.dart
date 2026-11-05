import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// TASARIM TOKEN'LARI — boşluk, köşe, süre, gölge, degrade.
///
/// ===================================================================
/// KURAL
/// ===================================================================
/// Ekranlarda serbest sayı YAZILMAZ:
///
///   ❌ padding: EdgeInsets.all(14)
///   ✅ padding: EdgeInsets.all(AppSpacing.md)
///
/// Bir değer değiştirilmek istendiğinde (örneğin bütün köşeler biraz
/// daha yuvarlak olsun) tek satır değişir ve bütün oyun birlikte
/// güncellenir. Serbest sayılarla bu, yüzlerce dosyada arama demektir.
///
/// Yeni bir değere gerçekten ihtiyaç varsa önce buraya eklenir.

// ====================================================================
// BOŞLUK — 4'ün katları
// ====================================================================
/// 4 piksellik ızgara. Göz, düzenli aralıkları "derli toplu" algılar;
/// 13, 17, 22 gibi rastgele değerler yan yana gelince ekran dağınık
/// görünür.
class AppSpacing {
  const AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// Telefon ekranının yan kenar boşluğu
  static const double screenEdge = lg;

  /// En küçük dokunma hedefi (Material ve Apple yönergeleri: 44-48).
  /// Bundan küçük butonlara parmakla isabet ettirmek zorlaşır.
  static const double minTouchTarget = 48;
}

// ====================================================================
// KÖŞE YARIÇAPI
// ====================================================================
class AppRadius {
  const AppRadius._();

  /// Rozet, küçük etiket
  static const double sm = 8;

  /// Buton, giriş alanı, filtre
  static const double md = 12;

  /// Panel, kart kutusu
  static const double lg = 16;

  /// Büyük vitrin paneli (ana sayfa hero, sonuç ekranı)
  static const double xl = 20;

  /// Hap (pill) biçimi
  static const double pill = 999;

  static BorderRadius circular(double r) => BorderRadius.circular(r);
}

// ====================================================================
// ANİMASYON SÜRELERİ — MD Bölüm 9
// ====================================================================
/// Her süre MD'deki aralığın içinde seçildi. Aralığın ortası değil,
/// "hızlı ama fark edilir" ucuna yakın değerler tercih edildi: rekabetçi
/// oyunlarda bekletmek, göz alıcılıktan daha çok rahatsız eder.
class AppDurations {
  const AppDurations._();

  /// Buton tepkisi (MD: 120-200 ms)
  static const Duration button = Duration(milliseconds: 140);

  /// Kart seçimi: büyüme + ışıklanma (MD: 200-350 ms)
  static const Duration cardSelect = Duration(milliseconds: 240);

  /// Kartı masaya oynama (MD: 300-500 ms)
  static const Duration cardPlay = Duration(milliseconds: 380);

  /// Panel / ekran geçişi (MD: 250-400 ms)
  static const Duration panel = Duration(milliseconds: 300);

  /// Kart çatışması sahnesi (MD: 1.5-3 sn)
  static const Duration clash = Duration(milliseconds: 2200);

  /// Paket açılışı / walkout (MD: 3-6 sn). WalkoutScreen ile aynı.
  static const Duration packOpen = Duration(milliseconds: 4600);

  /// İlerleme çubuğu dolması
  static const Duration progress = Duration(milliseconds: 600);
}

// ====================================================================
// GÖLGE VE IŞIK
// ====================================================================
class AppShadows {
  const AppShadows._();

  /// Paneli zeminden ayıran yumuşak gölge
  static const List<BoxShadow> panel = [
    BoxShadow(color: Color(0x73000000), blurRadius: 18, offset: Offset(0, 8)),
  ];

  /// Seçili / aktif öğenin etrafındaki ışık
  static List<BoxShadow> glow(Color renk, {double siddet = 1}) => [
    BoxShadow(
      color: renk.withValues(alpha: 0.35 * siddet),
      blurRadius: 22 * siddet,
      spreadRadius: 1,
    ),
  ];
}

// ====================================================================
// DEGRADELER
// ====================================================================
class AppGradients {
  const AppGradients._();

  /// Birincil eylem butonu ("MAÇA BAŞLA"): yukarıdan aşağı parlak ->
  /// koyu altın. Üstteki açık ton ışığın tepeden vurduğu metal hissini
  /// veriyor.
  static const LinearGradient cta = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFE9A8), AppColors.victoryGold, Color(0xFFB45309)],
    stops: [0.0, 0.45, 1.0],
  );

  /// CTA butonunun altındaki "kalınlık" (3B basma efekti)
  static const Color ctaEdge = Color(0xFF78350F);

  /// İkincil eylem: koyu saha yeşili
  static const LinearGradient secondary = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF065F46), Color(0xFF064E3B)],
  );

  /// Panel: üst sol hafif açık -> alt sağ koyu (cam yüzey hissi)
  static const LinearGradient panel = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF172238), AppColors.deepNavy],
  );

  /// İlerleme çubukları
  static const LinearGradient progressEmerald = LinearGradient(
    colors: [Color(0xFF059669), Color(0xFF34D399)],
  );
  static const LinearGradient progressPurple = LinearGradient(
    colors: [AppColors.epicPurple, Color(0xFFC4B5FD)],
  );
  static const LinearGradient progressGold = LinearGradient(
    colors: [AppColors.championGold, AppColors.victoryGold],
  );
  static const LinearGradient progressCyan = LinearGradient(
    colors: [Color(0xFF0891B2), AppColors.cyan],
  );
}
