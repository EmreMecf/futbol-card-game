import 'package:shared_models/shared_models.dart';

import '../../../../core/utils/result.dart';

/// Kadro duzenleme islemlerinin sozlesmesi.
abstract interface class DeckRepository {
  /// Oyuncunun tum desteleri
  Future<Result<List<DeckSummary>>> fetchDecks();

  /// Bir destedeki kartlar
  Future<Result<List<InventoryCard>>> fetchDeckCards(String deckId);

  /// Destedeki kartlar, formasyondaki SLOT numaralariyla birlikte.
  /// Kimya hesabi icin kartlarin nerede durdugunu bilmek gerekiyor.
  Future<Result<Map<int, InventoryCard>>> fetchDeckSlots(String deckId);

  /// Tum envanter (kadroya eklenebilecek kartlar)
  Future<Result<List<InventoryCard>>> fetchInventory();

  /// Kadro 4-4-2 kuralina uyuyor mu
  Future<Result<DeckValidation>> validateDeck(String deckId);

  /// Destenin kartlarini TOPTAN degistirir.
  ///
  /// Sunucu her karti tek tek dogrular: kart bu oyuncuya ait mi,
  /// baska bir macta kilitli mi. Istemciye guvenilmez.
  Future<Result<DeckValidation>> saveDeck({
    required String deckId,
    required List<String> userCardIds,
    bool setActive = true,
  });

  /// Yeni deste olustur
  Future<Result<DeckSummary>> createDeck(String name);

  /// Kaydedilmis kadronun SUNUCUDAKI kimya dokumu.
  ///
  /// Uygulama kadro kurarken kimyayi yerel olarak da hesapliyor
  /// (anlik onizleme icin); bu ise sunucunun gercek degeri.
  Future<Result<DeckChemistry>> fetchChemistry(String deckId);
}
