import 'package:freezed_annotation/freezed_annotation.dart';

import 'chemistry.dart';
import 'enums.dart';

part 'card_model.freezed.dart';
part 'card_model.g.dart';

/// Kart TANIMI (katalog kaydi).
///
/// Ornek: "Ronaldinho / Legend / 94 / Orta Saha"
/// Bir kartin oyundaki degismez ozellikleridir.
@freezed
abstract class CardModel with _$CardModel implements ChemistrySource {
  const CardModel._();

  const factory CardModel({
    required String cardId,
    required String fullName,
    required CardPosition position,
    required CardTier tier,
    required int power,
    String? slug,

    // ---- KIMYA OZELLIKLERI ----
    // Bu uc alan kartlarin birbirine baglanmasini saglar.
    String? nationality,
    String? league,
    String? club,

    /// Yapay zeka ile uretilmis 3D Pixar tarzi gorselin yolu
    String? imageUrl,
  }) = _CardModel;

  factory CardModel.fromJson(Map<String, dynamic> json) =>
      _$CardModelFromJson(json);

  /// Legend kartlar arayuzde ozel cerceve ile gosterilir
  bool get isLegend => tier.isLegend;

  /// Kart uzerinde gosterilecek kisa bilgi: "94 OS"
  String get badge => '$power ${position.shortLabel}';
}

/// Oyuncunun envanterindeki TEKIL kart ornegi.
///
/// NEDEN AYRI BIR SINIF?
/// Kartlar mac sonunda el degistirir. "Ali'de 3 Maradona var" demek
/// yetmez; her kartin kendi kimligi olmali ki hangi kartin kime gittigi
/// izlenebilsin. [userCardId] o fiziksel kartin kimligidir.
@freezed
abstract class InventoryCard with _$InventoryCard implements ChemistrySource {
  const InventoryCard._();

  const factory InventoryCard({
    required String userCardId,
    required String cardId,
    required String fullName,
    required CardPosition position,
    required CardTier tier,
    required int power,
    String? slug,

    // ---- KIMYA OZELLIKLERI ----
    String? nationality,
    String? league,
    String? club,

    String? imageUrl,

    /// Bu kart bir destede mi?
    @Default(false) bool inDeck,

    /// Devam eden bir macta kilitli mi?
    /// Kilitliyse desteden cikarilamaz, satilamaz.
    @Default(false) bool isLocked,
  }) = _InventoryCard;

  factory InventoryCard.fromJson(Map<String, dynamic> json) =>
      _$InventoryCardFromJson(json);

  bool get isLegend => tier.isLegend;
  String get badge => '$power ${position.shortLabel}';

  /// Kadroya eklenebilir mi?
  bool get isSelectable => !isLocked;

  /// Kart tanimina donustur (ortak widget'lar CardModel bekliyorsa)
  CardModel toCardModel() => CardModel(
        cardId: cardId,
        fullName: fullName,
        position: position,
        tier: tier,
        power: power,
        slug: slug,
        nationality: nationality,
        league: league,
        club: club,
        imageUrl: imageUrl,
      );
}
