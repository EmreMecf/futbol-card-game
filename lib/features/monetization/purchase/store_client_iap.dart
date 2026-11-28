import 'dart:io';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart' show BillingResponse;
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'store_client.dart';

StoreClient createStoreClient() => (Platform.isAndroid || Platform.isIOS) ? IapStoreClient() : const NoStoreClient();

/// `in_app_purchase` ile Google Play Billing / StoreKit.
///
/// TÜKETME SIRASI (Android): elmas paketleri `autoConsume: false` ile
/// satılır. Eklentinin otomatik tüketmesi, satın almayı uygulamaya
/// vermeden ÖNCE çalışır; sunucu o an doğrulayamazsa (geçici hata,
/// uygulama kapandı) ödeme bir daha gelmez ve elmas verilmezdi. Artık
/// ürün yalnız sunucu ödülü verdikten sonra [complete] içinde tüketilir.
class IapStoreClient implements StoreClient {
  final InAppPurchase _iap = InAppPurchase.instance;
  final Map<String, ProductDetails> _urunler = {};

  @override
  Future<bool> isAvailable() => _iap.isAvailable();

  @override
  Future<Map<String, StorePrice>> prices(Set<String> ids) async {
    if (ids.isEmpty) return const {};
    final r = await _iap.queryProductDetails(ids);
    for (final p in r.productDetails) {
      _urunler[p.id] = p;
    }
    return {for (final p in r.productDetails) p.id: StorePrice(p.price, p.rawPrice, p.currencyCode)};
  }

  @override
  Future<bool> buy(String id, {required bool consumable, required String accountId}) async {
    final p = _urunler[id] ?? (await _iap.queryProductDetails({id})).productDetails.firstOrNull;
    if (p == null) return false;
    final param = PurchaseParam(productDetails: p, applicationUserName: accountId);
    return consumable
        // Tüketme sunucu doğrulamasından sonra (complete) yapılır
        ? _iap.buyConsumable(purchaseParam: param, autoConsume: false)
        : _iap.buyNonConsumable(purchaseParam: param);
  }

  static StorePurchaseStatus _durum(PurchaseStatus s) => switch (s) {
    PurchaseStatus.pending => StorePurchaseStatus.pending,
    PurchaseStatus.purchased => StorePurchaseStatus.purchased,
    PurchaseStatus.restored => StorePurchaseStatus.restored,
    PurchaseStatus.error => StorePurchaseStatus.error,
    PurchaseStatus.canceled => StorePurchaseStatus.canceled,
  };

  static StorePurchase _cevir(PurchaseDetails d, {StorePurchaseStatus? status}) => StorePurchase(
    storeProductId: d.productID,
    status: status ?? _durum(d.status),
    purchaseToken: Platform.isAndroid ? d.verificationData.serverVerificationData : null,
    transactionId: Platform.isIOS ? d.purchaseID : null,
    needsCompletion: d.pendingCompletePurchase,
    raw: d,
  );

  @override
  Stream<List<StorePurchase>> get updates => _iap.purchaseStream.map((liste) => [for (final d in liste) _cevir(d)]);

  @override
  Future<void> complete(StorePurchase p, {bool consume = false}) async {
    final d = p.raw;
    if (d is! PurchaseDetails) return;
    if (consume && Platform.isAndroid && d.status != PurchaseStatus.pending) {
      // Tüketme teslimi de onaylar; ayrıca acknowledge gerekmez
      final r = await _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>().consumePurchase(d);
      if (r.responseCode == BillingResponse.ok) return;
      // Tüketilemediyse en azından onayla (Google 3 gün sonra iade etmesin);
      // ürün bir sonraki açılışta [unfinished] ile yeniden tüketilmeye çalışılır.
    }
    if (d.pendingCompletePurchase) await _iap.completePurchase(d);
  }

  @override
  Future<List<StorePurchase>> unfinished(Set<String> consumableStoreIds) async {
    if (!Platform.isAndroid) return const [];
    final r = await _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>().queryPastPurchases();
    return [
      for (final d in r.pastPurchases)
        // Onaylanmamış her işlem ya da hâlâ tüketilmemiş elmas paketi.
        // Onaylı tek seferlik ürünler (başlangıç paketi) atlanır: zaten teslim edildi.
        if (d.status != PurchaseStatus.pending && (d.pendingCompletePurchase || consumableStoreIds.contains(d.productID)))
          _cevir(d, status: StorePurchaseStatus.restored),
    ];
  }

  @override
  Future<void> restore() => _iap.restorePurchases();
}
