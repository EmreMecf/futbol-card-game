import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/error/app_exception.dart';
import 'package:futbol_card/core/network/api_client.dart';
import 'package:futbol_card/features/monetization/purchase/purchase_controller.dart';
import 'package:futbol_card/features/monetization/purchase/store_client.dart';

/// 061: satın alma akışı — ödül yalnız sunucu doğrulayınca, mağazaya
/// "tamam" yalnız sunucu cevap verince (geçici hatada işlem korunur).

class _NoApi implements ApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class FakePurchaseApi extends PurchaseApi {
  FakePurchaseApi() : super(_NoApi());

  bool enabled = true;
  Map<String, dynamic>? verifyResult = {'status': 'granted', 'paid_gems': 100};
  String? verifyError;
  int verifyCalls = 0;

  @override
  Future<Map<String, dynamic>> catalog() async => {
    'enabled': enabled,
    'products': [
      {
        'id': 'gems_starter_100',
        'category': 'gems',
        'store_product_id': 'gems_100',
        'product_type': 'consumable',
        'name': 'Başlangıç',
        'contents': {'paid_gems': 100},
      },
      {
        'id': 'gems_popular_300',
        'category': 'gems',
        'store_product_id': 'gems_300',
        'product_type': 'consumable',
        'name': 'Popüler',
        'contents': {'paid_gems': 300},
      },
    ],
  };

  @override
  Future<Map<String, dynamic>> verify(StorePurchase p) async {
    verifyCalls++;
    if (verifyError != null) throw AppException(message: 'x', technicalDetail: verifyError);
    return verifyResult!;
  }
}

class FakeStore implements StoreClient {
  bool available = true;
  final completed = <StorePurchase>[];
  final _c = StreamController<List<StorePurchase>>.broadcast();

  @override
  Future<bool> isAvailable() async => available;
  @override
  Future<Map<String, StorePrice>> prices(Set<String> ids) async => {
    // gems_300 mağazada yok: fiyat uydurulmaz, ürün gösterilmez
    if (ids.contains('gems_100')) 'gems_100': const StorePrice('₺39,99', 39.99, 'TRY'),
  };
  @override
  Future<bool> buy(String id, {required bool consumable, required String accountId}) async => true;
  @override
  Stream<List<StorePurchase>> get updates => _c.stream;
  @override
  Future<void> complete(StorePurchase p) async => completed.add(p);
  @override
  Future<void> restore() async {}
}

const _alindi = StorePurchase(
  storeProductId: 'gems_100',
  status: StorePurchaseStatus.purchased,
  purchaseToken: 'tok',
  needsCompletion: true,
);

void main() {
  late FakePurchaseApi api;
  late FakeStore store;
  late PurchaseController c;

  setUp(() {
    api = FakePurchaseApi();
    store = FakeStore();
    c = PurchaseController(api, store);
  });

  test('katalog: yalnız mağaza fiyatı olan ürünler, gerçek fiyatla', () async {
    await c.load();
    expect(c.enabled, isTrue);
    expect(c.products.map((p) => p.id), ['gems_starter_100']);
    expect(c.products.single.price!.price, '₺39,99');
    expect(c.products.single.paidGems, 100);
  });

  test('sunucu bayrağı kapalı ya da mağaza yoksa satış görünmez', () async {
    api.enabled = false;
    await c.load();
    expect(c.enabled, isFalse);
    api.enabled = true;
    store.available = false;
    await c.load();
    expect(c.enabled, isFalse);
    expect(c.products, isEmpty);
  });

  test('satın alındı → sunucu doğrular → mağazaya tamam denir', () async {
    await c.handleUpdates([_alindi]);
    expect(api.verifyCalls, 1);
    expect(store.completed, hasLength(1));
    expect(c.state, PurchaseFlowState.success);
  });

  test('geçici doğrulama hatasında mağazaya tamam DENMEZ (ödeme kaybolmaz)', () async {
    api.verifyError = 'store_unavailable';
    await c.handleUpdates([_alindi]);
    expect(store.completed, isEmpty);
    expect(c.state, PurchaseFlowState.failed);
  });

  test('kalıcı hata (geçersiz makbuz) işlemi kapatır', () async {
    api.verifyError = 'invalid_receipt';
    await c.handleUpdates([_alindi]);
    expect(store.completed, hasLength(1));
    expect(c.state, PurchaseFlowState.failed);
  });

  test('sunucu "pending" derse ödül yok, mağazaya tamam denmez', () async {
    api.verifyResult = {'status': 'pending'};
    await c.handleUpdates([_alindi]);
    expect(store.completed, isEmpty);
    expect(c.state, PurchaseFlowState.pending);
  });

  test('bekleyen ödeme sunucuya gitmez; iptal mağazada kapanır', () async {
    await c.handleUpdates([
      const StorePurchase(storeProductId: 'gems_100', status: StorePurchaseStatus.pending),
    ]);
    expect(api.verifyCalls, 0);
    expect(c.state, PurchaseFlowState.pending);
    await c.handleUpdates([
      const StorePurchase(storeProductId: 'gems_100', status: StorePurchaseStatus.canceled),
    ]);
    expect(api.verifyCalls, 0);
    expect(store.completed, hasLength(1));
    expect(c.state, PurchaseFlowState.cancelled);
  });

  test('oturum yoksa satın alma başlamaz', () async {
    await c.load();
    await c.buy(c.products.single);
    expect(c.busyProduct, isNull);
    expect(c.state, PurchaseFlowState.idle);
  });
}
