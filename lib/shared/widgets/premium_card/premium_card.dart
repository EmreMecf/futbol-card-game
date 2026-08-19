/// FIFA/EA FC seviyesinde futbolcu karti widget'lari.
///
/// Kullanim:
/// ```dart
/// PremiumPlayerCard.fromInventory(kart, width: 180)
/// ```
///
/// PERFORMANS UYARISI:
/// Koleksiyon gibi cok kartli listelerde `interactive: false` ver.
/// Aksi halde her kart kendi animasyonunu calistirir ve arayuz takilir.
library;

export 'card_frame_painter.dart';
export 'card_tier_theme.dart';
export 'card_tilt.dart';
export 'holographic_shine.dart';
export 'premium_player_card.dart';
