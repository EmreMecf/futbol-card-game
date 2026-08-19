import 'package:shared_models/shared_models.dart';

import '../../../../core/utils/result.dart';

/// Koleksiyon (envanter) islemlerinin sozlesmesi.
abstract interface class CollectionRepository {
  /// Oyuncunun sahip oldugu tum kartlar
  Future<Result<List<InventoryCard>>> fetchInventory();

  /// Oyundaki tum kart katalogu (sahip olunmayanlar dahil)
  Future<Result<List<CardModel>>> fetchCatalog();

  /// SADECE GELISTIRME: katalogdaki tum kartlari hesaba ekler
  Future<Result<int>> devGrantAllCards();
}
