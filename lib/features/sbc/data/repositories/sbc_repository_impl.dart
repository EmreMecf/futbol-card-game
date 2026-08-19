import 'package:shared_models/shared_models.dart';

import '../../../../core/utils/result.dart';
import '../../domain/repositories/sbc_repository.dart';
import '../datasources/sbc_remote_datasource.dart';

class SbcRepositoryImpl implements SbcRepository {
  final SbcRemoteDataSource _remote;

  SbcRepositoryImpl(this._remote);

  @override
  Future<Result<List<SbcChallenge>>> fetchChallenges() {
    return Result.guard(() async {
      final cevap = await _remote.challenges();
      final ham = cevap['challenges'] as List? ?? const [];
      return ham
          .map((g) => SbcChallenge.fromJson(g as Map<String, dynamic>))
          .toList();
    });
  }

  @override
  Future<Result<List<InventoryCard>>> fetchInventory() {
    return Result.guard(() async {
      final cevap = await _remote.inventory();
      final ham = cevap['cards'] as List? ?? const [];
      return ham
          .map((k) => InventoryCard.fromJson(k as Map<String, dynamic>))
          .toList();
    });
  }

  @override
  Future<Result<SbcEvaluation>> evaluate({
    required String challengeId,
    required List<String> userCardIds,
  }) {
    return Result.guard(() async {
      return SbcEvaluation.fromJson(
        await _remote.evaluate(challengeId, userCardIds),
      );
    });
  }

  @override
  Future<Result<SbcSubmitResult>> submit({
    required String challengeId,
    required List<String> userCardIds,
  }) {
    return Result.guard(() async {
      return SbcSubmitResult.fromJson(
        await _remote.submit(challengeId, userCardIds),
      );
    });
  }
}
