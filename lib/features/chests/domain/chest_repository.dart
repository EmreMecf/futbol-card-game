import 'package:shared_models/shared_models.dart';

import '../../../core/utils/result.dart';

/// Sandık ve ödül enerjisi verisi (Ekonomi V2, FAZ 1).
///
/// Değiştirici her çağrı bir [idempotencyKey] alır: aynı kullanıcı
/// eylemi (ör. "Aç" düğmesi) ağ hatası sonrası tekrar denenirse AYNI
/// anahtar gönderilir, sunucu işlemi ikinci kez yapmaz.
abstract class ChestRepository {
  Future<Result<ChestInventory>> fetchInventory();
  Future<Result<ChestOdds>> fetchOdds({int? version});
  Future<Result<SourceChest>> fetchMatchChest(String matchId);
  Future<Result<Chest>> startUnlock(String chestId, {required String idempotencyKey});
  Future<Result<ChestOpenResult>> open(String chestId, {required String idempotencyKey});
  Future<Result<Chest>> claimMailbox(String chestId, {required String idempotencyKey});
  Future<Result<EmergencySquadStatus>> fetchEmergencySquad();
  Future<Result<EmergencySquadClaim>> claimEmergencySquad({required String idempotencyKey});
}
