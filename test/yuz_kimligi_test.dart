import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/shared/widgets/avatar2d/avatar_spec.dart';
import 'package:futbol_card/shared/widgets/ref_card/ref_player_card.dart';
import 'package:shared_models/shared_models.dart';

/// KABUL TESTİ (madde 6–7): bir futbolcunun 2D yüzü koleksiyonda,
/// kadroda, maçta ve pakette AYNI kimliği kullanır.
///
/// Kural: AvatarSpec.generate(cardId, kitSeed: kulüp ?? uyruk)
///
/// Eskiden maç hamlesi (MatchMove) kartın katalog kimliğini taşımadığı
/// için RAKİP kartın yüzü ada göre üretiliyordu → koleksiyondaki
/// yüzden farklıydı. Sunucu artık hamleyle card_id, club, nationality
/// gönderiyor (yalnız görsel kimlik; kural hesabı değişmedi).
void main() {
  const kartId = '7f6d2c1e-0000-4000-8000-000000000042';

  final envanter = InventoryCard.fromJson({
    'user_card_id': 'uc-1',
    'card_id': kartId,
    'slug': 'pele',
    'full_name': 'Pele',
    'position': 'FWD',
    'tier': 'legend',
    'power': 98,
    'club': null,
    'nationality': 'BRA',
  });

  // Sunucunun /match/<id>/moves cevabındaki rakip hamlesi
  final hamle = MatchMove.fromJson({
    'round_number': 3,
    'user_id': 'rakip',
    'position': 'FWD',
    'tier': 'legend',
    'power': 98,
    'user_card_id': 'rakibin-kopyasi',
    'full_name': 'Pele',
    'card_id': kartId,
    'club': null,
    'nationality': 'BRA',
  });

  test('hamle görsel kimliği taşır (card_id, kulüp/uyruk)', () {
    expect(hamle.cardId, kartId);
    expect(hamle.kitSeed, 'BRA', reason: 'kulüp yoksa uyruk: koleksiyondaki kural');
  });

  test('koleksiyondaki kart ile masadaki rakip kartı AYNI yüz', () {
    final koleksiyon = RefPlayerCard(
      name: envanter.fullName,
      position: envanter.position,
      tier: envanter.tier,
      power: envanter.power,
      seed: envanter.cardId,
      kitSeed: envanter.club ?? envanter.nationality,
      width: 120,
    ).resolvedSpec;
    final masa = AvatarSpec.generate(hamle.cardId!, kitSeed: hamle.kitSeed);
    expect(masa, koleksiyon);
  });

  test('eski davranış (ada göre tohum) gerçekten farklı yüz üretiyordu', () {
    // Regresyon kanıtı: düzeltme olmasaydı test bunu yakalardı
    final adaGore = AvatarSpec.generate(hamle.fullName!);
    final dogru = AvatarSpec.generate(kartId, kitSeed: 'BRA');
    expect(adaGore == dogru, isFalse);
  });

  test('eski sunucu kimlik göndermezse çökmez (ada düşer)', () {
    final eski = MatchMove.fromJson({'round_number': 1, 'user_id': 'r', 'full_name': 'Pele'});
    expect(eski.cardId, isNull);
    expect(eski.kitSeed, isNull);
  });
}
