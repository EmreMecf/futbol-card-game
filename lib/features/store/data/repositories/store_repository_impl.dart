import 'package:shared_models/shared_models.dart';

import '../../../../core/utils/result.dart';
import '../../domain/repositories/store_repository.dart';
import '../datasources/store_remote_datasource.dart';

class StoreRepositoryImpl implements StoreRepository {
  final StoreRemoteDataSource _remote;

  StoreRepositoryImpl(this._remote);

  @override
  Future<Result<List<PackType>>> fetchPacks() {
    return Result.guard(() async {
      final cevap = await _remote.packs();
      final ham = cevap['packs'] as List? ?? const [];
      return ham
          .map((p) => PackType.fromJson(p as Map<String, dynamic>))
          .toList();
    });
  }

  @override
  Future<Result<PackOpenResult>> openPack(String slug) {
    return Result.guard(() async {
      return PackOpenResult.fromJson(await _remote.open(slug));
    });
  }
}
