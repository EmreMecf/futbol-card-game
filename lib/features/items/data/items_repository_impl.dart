import 'package:shared_models/shared_models.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/result.dart';
import '../domain/items_repository.dart';

class ItemsRepositoryImpl implements ItemsRepository {
  final ApiClient _api;
  ItemsRepositoryImpl(this._api);

  @override
  Future<Result<ItemInventory>> fetchInventory() =>
      Result.guard(() async => ItemInventory.fromJson(await _api.get('/items')));

  @override
  Future<Result<Map<String, dynamic>>> use(String slug,
          {Map<String, dynamic> target = const {}, required String idempotencyKey}) =>
      Result.guard(() => _api.postIdempotent('/items/$slug/use', anahtar: idempotencyKey, govde: {'target': target}));

  @override
  Future<Result<void>> equip(String slug, {required String idempotencyKey}) =>
      Result.guard(() async => _api.postIdempotent('/items/$slug/equip', anahtar: idempotencyKey));

  @override
  Future<Result<void>> unequip(String slot, {required String idempotencyKey}) =>
      Result.guard(() async => _api.postIdempotent('/items/unequip/$slot', anahtar: idempotencyKey));
}
