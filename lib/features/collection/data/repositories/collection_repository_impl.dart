import 'package:shared_models/shared_models.dart';

import '../../../../core/utils/result.dart';
import '../../domain/repositories/collection_repository.dart';
import '../datasources/collection_remote_datasource.dart';

class CollectionRepositoryImpl implements CollectionRepository {
  final CollectionRemoteDataSource _remote;

  CollectionRepositoryImpl(this._remote);

  @override
  Future<Result<List<InventoryCard>>> fetchInventory() {
    return Result.guard(() async {
      final cevap = await _remote.inventory();
      final ham = cevap['cards'] as List? ?? const [];

      // PAYLASILAN model: sunucu ayni sinifin toJson'unu gonderiyor.
      return ham
          .map((k) => InventoryCard.fromJson(k as Map<String, dynamic>))
          .toList();
    });
  }

  @override
  Future<Result<List<CardModel>>> fetchCatalog() {
    return Result.guard(() async {
      final cevap = await _remote.catalog();
      final ham = cevap['cards'] as List? ?? const [];
      return ham
          .map((k) => CardModel.fromJson(k as Map<String, dynamic>))
          .toList();
    });
  }

  @override
  Future<Result<int>> devGrantAllCards() {
    return Result.guard(() async {
      final cevap = await _remote.grantAllCards();
      return (cevap['total'] as num?)?.toInt() ?? 0;
    });
  }
}
