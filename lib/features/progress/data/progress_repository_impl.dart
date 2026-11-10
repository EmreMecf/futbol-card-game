import 'package:shared_models/shared_models.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/result.dart';
import '../domain/progress_repository.dart';

class ProgressRepositoryImpl implements ProgressRepository {
  final ApiClient _api;
  ProgressRepositoryImpl(this._api);

  @override
  Future<Result<ProgressOverview>> fetchOverview() =>
      Result.guard(() async => ProgressOverview.fromJson(await _api.get('/progress')));

  @override
  Future<Result<LevelUpResult>> levelUp(String cardId,
          {required bool useJokers, bool useDiscount = false, required String idempotencyKey}) =>
      Result.guard(() async => LevelUpResult.fromJson(await _api.postIdempotent('/progress/$cardId/level-up',
          anahtar: idempotencyKey, govde: {'use_jokers': useJokers, 'use_discount': useDiscount})));

  @override
  Future<Result<ConvertCopiesResult>> convert(String cardId, int count, {required String idempotencyKey}) =>
      Result.guard(() async => ConvertCopiesResult.fromJson(
          await _api.postIdempotent('/progress/$cardId/convert', anahtar: idempotencyKey, govde: {'count': count})));
}
