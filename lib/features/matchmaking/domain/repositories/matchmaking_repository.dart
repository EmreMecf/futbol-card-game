import 'package:shared_models/shared_models.dart';

import '../../../../core/utils/result.dart';

/// Eslestirme islemlerinin sozlesmesi.
abstract interface class MatchmakingRepository {
  /// Aktif destelerimi getirir (maca hangi kadroyla girecegim)
  Future<Result<List<DeckSummary>>> fetchDecks();

  /// Destedeki kartlar (koruma secimi icin gerekli)
  Future<Result<List<InventoryCard>>> fetchDeckCards(String deckId);

  /// Kadro 4-4-2 kuralina uyuyor mu
  Future<Result<DeckValidation>> validateDeck(String deckId);

  /// Mac ara / kuyruga gir.
  /// [protectedCardIds] maca girerken korumaya alinan kartlar.
  Future<Result<MatchFindResult>> findMatch({
    required String deckId,
    List<String> protectedCardIds,
  });

  /// Antrenman maçı başlat (041): bota karşı, ödülsüz ve puansız
  Future<Result<MatchFindResult>> startTraining({required String deckId});

  /// Öğreticinin sıradaki adımını başlat (042): bota karşı kısa maç
  Future<Result<MatchFindResult>> startTutorial({required String deckId});

  /// Kuyruktan cik
  Future<Result<MatchFindResult>> cancelMatchmaking();

  /// Devam eden mac var mi?
  Future<Result<String?>> activeMatchId();
}
