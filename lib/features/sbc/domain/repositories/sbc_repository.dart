import 'package:shared_models/shared_models.dart';

import '../../../../core/utils/result.dart';

/// Kadro kurma gorevleri (SBC) sozlesmesi.
abstract interface class SbcRepository {
  /// Aktif gorevler + tamamlanma durumu
  Future<Result<List<SbcChallenge>>> fetchChallenges();

  /// Envanterdeki eritilebilir kartlar
  Future<Result<List<InventoryCard>>> fetchInventory();

  /// Kadroyu SUNUCUDA dogrula (gondermeden once son kontrol)
  Future<Result<SbcEvaluation>> evaluate({
    required String challengeId,
    required List<String> userCardIds,
  });

  /// Kartlari erit, odulu al.
  ///
  /// GERI ALINAMAZ: Kartlar kalici olarak silinir.
  Future<Result<SbcSubmitResult>> submit({
    required String challengeId,
    required List<String> userCardIds,
  });
}
