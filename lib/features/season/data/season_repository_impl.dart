import 'package:shared_models/shared_models.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/result.dart';
import '../domain/season_repository.dart';

class SeasonRepositoryImpl implements SeasonRepository {
  final ApiClient _api;
  SeasonRepositoryImpl(this._api);

  @override
  Future<Result<SeasonOverview>> fetchOverview() =>
      Result.guard(() async => SeasonOverview.fromJson(await _api.get('/season')));

  @override
  Future<Result<MissionsOverview>> fetchMissions() =>
      Result.guard(() async => MissionsOverview.fromJson(await _api.get('/season/missions')));

  @override
  Future<Result<MatchSeasonXp>> fetchMatchXp(String matchId) =>
      Result.guard(() async => MatchSeasonXp.fromJson(await _api.get('/season/match/$matchId')));

  @override
  Future<Result<Map<String, dynamic>>> claim(int tier, String track, {required String idempotencyKey}) =>
      Result.guard(() => _api.postIdempotent('/season/claim',
          anahtar: idempotencyKey, govde: {'tier': tier, 'track': track}));

  @override
  Future<Result<Map<String, dynamic>>> claimAll({required String idempotencyKey}) =>
      Result.guard(() => _api.postIdempotent('/season/claim-all', anahtar: idempotencyKey));
}
