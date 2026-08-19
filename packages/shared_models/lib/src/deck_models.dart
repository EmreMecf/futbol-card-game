import 'package:freezed_annotation/freezed_annotation.dart';

import 'card_model.dart';
import 'enums.dart';
import 'game_rules.dart';

part 'deck_models.freezed.dart';
part 'deck_models.g.dart';

/// Deste ozeti (liste ekraninda gosterilir)
@freezed
abstract class DeckSummary with _$DeckSummary {
  const DeckSummary._();

  const factory DeckSummary({
    required String id,
    required String name,
    @Default(false) bool isActive,
    @Default(0) int cardCount,
  }) = _DeckSummary;

  factory DeckSummary.fromJson(Map<String, dynamic> json) =>
      _$DeckSummaryFromJson(json);

  /// Kadro tam mi? (11 kart)
  bool get isComplete => cardCount == GameRules.squadSize;
}

/// Kadro dogrulama sonucu.
///
/// [message] sunucudan gelen TURKCE aciklamadir; dogrudan kullaniciya
/// gosterilebilir. Ornek: "Kadroda tam 4 defans olmali (su an: 3)."
@freezed
abstract class DeckValidation with _$DeckValidation {
  const DeckValidation._();

  const factory DeckValidation({
    required bool isValid,
    String? message,
  }) = _DeckValidation;

  factory DeckValidation.fromJson(Map<String, dynamic> json) =>
      _$DeckValidationFromJson(json);

  /// Gecerliyse bos metin, degilse hata mesaji
  String get displayMessage => isValid ? 'Kadro hazir' : (message ?? 'Kadro gecersiz');
}

/// Kadro kurma ekraninin durumu.
///
/// SUNUCUYA GITMEYEN, sadece arayuzde yasayan bir yardimci sinif.
/// Oyuncu kart secerken "4 defanstan 3'unu sectin" gibi anlik geri
/// bildirim verebilmek icin kullanilir. Gercek dogrulama yine sunucuda.
@freezed
abstract class DeckBuilderState with _$DeckBuilderState {
  const DeckBuilderState._();

  const factory DeckBuilderState({
    @Default([]) List<InventoryCard> selectedCards,
  }) = _DeckBuilderState;

  /// Bir pozisyondan kac kart secildi?
  int countFor(CardPosition position) =>
      selectedCards.where((k) => k.position == position).length;

  /// O pozisyondan daha kart eklenebilir mi?
  bool canAdd(CardPosition position) =>
      countFor(position) < position.requiredCount;

  /// Kadro tamamlandi mi? (her pozisyon tam sayida)
  bool get isComplete => CardPosition.values.every(
        (p) => countFor(p) == p.requiredCount,
      );

  /// Eksikleri anlatan Turkce mesaj (tamamsa null)
  String? get missingMessage {
    final eksikler = <String>[];

    for (final p in CardPosition.values) {
      final mevcut = countFor(p);
      final gerekli = p.requiredCount;
      if (mevcut < gerekli) {
        eksikler.add('${gerekli - mevcut} ${p.label.toLowerCase()}');
      } else if (mevcut > gerekli) {
        return '${p.label} pozisyonunda fazla kart var '
            '($mevcut/$gerekli).';
      }
    }

    if (eksikler.isEmpty) return null;
    return 'Eksik: ${eksikler.join(', ')}';
  }

  /// Sunucuya gonderilecek kart kimlikleri
  List<String> get userCardIds =>
      selectedCards.map((k) => k.userCardId).toList();
}
