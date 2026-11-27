import 'store_client_stub.dart' if (dart.library.io) 'store_client_iap.dart' as impl;

/// 061 — Mağaza istemcisi arayüzü (Google Play / App Store). Uygulama
/// mağaza SDK'sına doğrudan bağlı değildir; testte sahte uygulama verilir.
abstract class StoreClient {
  Future<bool> isAvailable();

  /// Mağaza kimliği → yerel para birimiyle fiyat. FİYAT YALNIZ BURADAN gelir.
  Future<Map<String, StorePrice>> prices(Set<String> storeProductIds);

  /// Satın almayı başlat. [accountId] oyuncu kimliği: Android'de
  /// obfuscatedAccountId, iOS'ta appAccountToken olur; sunucu eşleşmeyi denetler.
  Future<bool> buy(String storeProductId, {required bool consumable, required String accountId});

  /// Mağazadan gelen satın alma güncellemeleri (uygulama kapanıp açılınca
  /// tamamlanmamış işlemler de buradan yeniden gelir)
  Stream<List<StorePurchase>> get updates;

  /// Mağazaya "teslim edildi" de (yalnız SUNUCU ödülü verdikten sonra)
  Future<void> complete(StorePurchase p);

  Future<void> restore();

  static StoreClient create() => impl.createStoreClient();
}

class StorePrice {
  final String price; // "₺79,99"
  final double rawPrice;
  final String currency;
  const StorePrice(this.price, this.rawPrice, this.currency);
}

enum StorePurchaseStatus { pending, purchased, restored, error, canceled }

class StorePurchase {
  final String storeProductId;
  final StorePurchaseStatus status;

  /// Google: satın alma jetonu
  final String? purchaseToken;

  /// Apple: işlem kimliği
  final String? transactionId;
  final bool needsCompletion;

  /// SDK nesnesi (complete için)
  final Object? raw;

  const StorePurchase({
    required this.storeProductId,
    required this.status,
    this.purchaseToken,
    this.transactionId,
    this.needsCompletion = false,
    this.raw,
  });
}

/// Mağazası olmayan ortam (web, masaüstü, test)
class NoStoreClient implements StoreClient {
  const NoStoreClient();
  @override
  Future<bool> isAvailable() async => false;
  @override
  Future<Map<String, StorePrice>> prices(Set<String> ids) async => const {};
  @override
  Future<bool> buy(String id, {required bool consumable, required String accountId}) async => false;
  @override
  Stream<List<StorePurchase>> get updates => const Stream.empty();
  @override
  Future<void> complete(StorePurchase p) async {}
  @override
  Future<void> restore() async {}
}
