import 'dart:io';

import 'package:in_app_purchase/in_app_purchase.dart';

import 'store_client.dart';

StoreClient createStoreClient() => (Platform.isAndroid || Platform.isIOS) ? IapStoreClient() : const NoStoreClient();

/// `in_app_purchase` ile Google Play Billing / StoreKit.
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
        ? _iap.buyConsumable(purchaseParam: param, autoConsume: true)
        : _iap.buyNonConsumable(purchaseParam: param);
  }

  @override
  Stream<List<StorePurchase>> get updates => _iap.purchaseStream.map((liste) => [
    for (final d in liste)
      StorePurchase(
        storeProductId: d.productID,
        status: switch (d.status) {
          PurchaseStatus.pending => StorePurchaseStatus.pending,
          PurchaseStatus.purchased => StorePurchaseStatus.purchased,
          PurchaseStatus.restored => StorePurchaseStatus.restored,
          PurchaseStatus.error => StorePurchaseStatus.error,
          PurchaseStatus.canceled => StorePurchaseStatus.canceled,
        },
        purchaseToken: Platform.isAndroid ? d.verificationData.serverVerificationData : null,
        transactionId: Platform.isIOS ? d.purchaseID : null,
        needsCompletion: d.pendingCompletePurchase,
        raw: d,
      ),
  ]);

  @override
  Future<void> complete(StorePurchase p) async {
    final d = p.raw;
    if (d is PurchaseDetails && d.pendingCompletePurchase) await _iap.completePurchase(d);
  }

  @override
  Future<void> restore() => _iap.restorePurchases();
}
