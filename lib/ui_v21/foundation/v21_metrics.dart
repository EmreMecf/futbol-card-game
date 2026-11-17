/// V2.1 ölçüleri (390×844 tasarım tuvali, piksel).
///
/// Ana sayfa ölçüleri `assets/v21/screens/home.png` üzerinden 4× büyütülerek
/// ölçüldü. Ekranlar bu sabitleri [V21Scale.s] ile çarpar.
abstract final class V21Metrics {
  /// Tasarım tuvali
  static const double designWidth = 390;
  static const double designHeight = 844;

  /// Telefon içeriği tablette en fazla bu kadar yayılır
  static const double maxContentWidth = 520;

  // ---- Köşe yarıçapları ----
  static const double radiusS = 6;
  static const double radiusM = 12;
  static const double radiusL = 16;
  static const double radiusPill = 999;

  // ---- Boşluk ölçeği ----
  static const double space2 = 2;
  static const double space4 = 4;
  static const double space6 = 6;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space24 = 24;

  // ---- Üst başlık ----
  /// Seviye dairesi çapı (12..56 → 44)
  static const double levelBadge = 44;
  static const double headerHeight = 58;
  static const double headerSidePadding = 12;

  // ---- Kaynak hapı ----
  static const double resourcePillHeight = 35;

  // ---- Lig rozeti (62..315 × 72..143) ----
  static const double leagueBadgeWidth = 253;
  static const double leagueBadgeHeight = 72;
  static const double leagueBadgeLeft = 62;

  // ---- Ana düğme (35..355 × 560..642) ----
  static const double primaryButtonHeight = 82;
  static const double primaryButtonSide = 35;

  /// Altın düğmenin 3B alt dudağı
  static const double buttonLip = 7;

  // ---- Sandık şeridi ----
  static const double chestSlotHeight = 91;
  static const double chestSlotGap = 6;
  static const double chestRowSide = 12;
  static const double chestLabelHeight = 12;

  // ---- Alt menü ----
  static const double navHeight = 80;

  /// Etkin karonun menü çizgisinin üstüne taşan kısmı (752 vs 764)
  static const double navActiveRise = 12;
  static const double navActiveWidth = 84;
}
