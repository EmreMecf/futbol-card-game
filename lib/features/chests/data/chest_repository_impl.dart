import 'package:shared_models/shared_models.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/result.dart';
import '../domain/chest_repository.dart';

class ChestRepositoryImpl implements ChestRepository {
  final ApiClient _api;
  ChestRepositoryImpl(this._api);

  @override
  Future<Result<ChestInventory>> fetchInventory() =>
      Result.guard(() async => ChestInventory.fromJson(await _api.get('/chests')));

  @override
  Future<Result<ChestOdds>> fetchOdds({int? version}) => Result.guard(() async =>
      ChestOdds.fromJson(await _api.get('/chests/odds', sorgu: {'version': ?version})));

  @override
  Future<Result<SourceChest>> fetchMatchChest(String matchId) => Result.guard(() async =>
      SourceChest.fromJson(await _api.get('/chests/source', sorgu: {'type': 'match', 'id': matchId})));

  @override
  Future<Result<Chest>> startUnlock(String chestId, {required String idempotencyKey}) => Result.guard(
      () async => Chest.fromJson(await _api.postIdempotent('/chests/$chestId/unlock', anahtar: idempotencyKey)));

  @override
  Future<Result<ChestOpenResult>> open(String chestId, {required String idempotencyKey}) => Result.guard(() async =>
      ChestOpenResult.fromJson(await _api.postIdempotent('/chests/$chestId/open', anahtar: idempotencyKey)));

  @override
  Future<Result<Chest>> claimMailbox(String chestId, {required String idempotencyKey}) => Result.guard(() async =>
      Chest.fromJson(await _api.postIdempotent('/chests/mailbox/$chestId/claim', anahtar: idempotencyKey)));

  @override
  Future<Result<EmergencySquadStatus>> fetchEmergencySquad() => Result.guard(
      () async => EmergencySquadStatus.fromJson(await _api.get('/economy/emergency-squad')));

  @override
  Future<Result<EmergencySquadClaim>> claimEmergencySquad({required String idempotencyKey}) =>
      Result.guard(() async => EmergencySquadClaim.fromJson(
          await _api.postIdempotent('/economy/emergency-squad/claim', anahtar: idempotencyKey)));
}
