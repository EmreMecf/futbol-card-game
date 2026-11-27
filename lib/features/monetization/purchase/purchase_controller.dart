import 'dart:async';

import 'package:material_ui/material_ui.dart' show ChangeNotifier;

import '../../../core/auth/session_manager.dart';
import '../../../core/l10n/app_language.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/result.dart';
import '../monetization_models.dart';
import 'store_client.dart';

/// Sunucu kataloğundaki ürün + mağazadaki gerçek fiyat
class ShopProduct {
  final String id;
  final String category;
  final String storeProductId;
  final bool consumable;
  final String name;
  final String description;
  final int paidGems;
  final bool owned;
  final StorePrice? price;

  /// 062: içerikteki kozmetikler (başlangıç paketi çerçevesi)
  final List<String> itemSlugs;
  const ShopProduct({
    required this.id,
    required this.category,
    required this.storeProductId,
    required this.consumable,
    required this.name,
    required this.description,
    this.paidGems = 0,
    this.owned = false,
    this.price,
    this.itemSlugs = const [],
  });

  factory ShopProduct.fromJson(Map<String, dynamic> j, StorePrice? price) => ShopProduct(
    id: j['id'].toString(),
    category: j['category']?.toString() ?? '',
    storeProductId: j['store_product_id'].toString(),
    consumable: j['product_type'] == 'consumable',
    name: j['name']?.toString() ?? '',
    description: j['description']?.toString() ?? '',
    paidGems: (j['contents'] is Map ? (j['contents']['paid_gems'] as num?)?.toInt() : null) ?? 0,
    owned: j['problem'] == 'already_owned',
    price: price,
    itemSlugs: [
      if (j['contents'] is Map && j['contents']['items'] is List)
        for (final i in j['contents']['items'] as List)
          if (i is Map && i['slug'] != null) i['slug'].toString(),
    ],
  );

  /// Mağaza fiyatı yoksa satılamaz (fiyat uydurulmaz)
  bool get purchasable => price != null && !owned;
}

class PurchaseApi {
  final ApiClient api;
  PurchaseApi(this.api);

  Future<Map<String, dynamic>> catalog() =>
      api.get('/purchases/catalog', sorgu: {'platform': clientPlatform, 'app_version': kAppVersion});

  Future<Map<String, dynamic>> verify(StorePurchase p) => api.post(
    '/purchases/verify',
    govde: {
      'platform': clientPlatform,
      'product_id': p.storeProductId,
      'purchase_token': ?p.purchaseToken,
      'transaction_id': ?p.transactionId,
    },
  );
}

enum PurchaseFlowState { idle, loading, purchasing, pending, verifying, success, failed, cancelled }

/// 061 — SATIN ALMA AKIŞI.
///
///   * Ürün listesi SUNUCUDAN, fiyat MAĞAZADAN (yerel para birimi). İkisi
///     birden yoksa ürün gösterilmez.
///   * Mağaza "satın alındı" deyince ödül VERİLMEZ: işlem sunucuya
///     gönderilir, sunucu mağaza API'siyle doğrular ve ödülü verir.
///     Mağazaya "tamamlandı" ancak bundan sonra denir; böylece uygulama
///     yarıda kapansa da işlem açılışta yeniden gelir ve kurtarılır.
///   * Bekleyen ödeme (ör. operatör faturası) ödül vermez; tamamlanınca
///     mağaza yeniden bildirir.
class PurchaseController extends ChangeNotifier {
  final PurchaseApi _api;
  final StoreClient _store;
  final SessionManager? _session;
  StreamSubscription<List<StorePurchase>>? _abone;

  PurchaseController(this._api, this._store, {SessionManager? session})
    // ignore: prefer_initializing_formals
    : _session = session;

  bool _acik = false;

  /// Satın alma bu oyuncuya açık mı (sunucu bayrağı + mağaza hazır)
  bool get enabled => _acik;

  List<ShopProduct> _urunler = const [];
  List<ShopProduct> get products => _urunler;

  PurchaseFlowState _durum = PurchaseFlowState.idle;
  PurchaseFlowState get state => _durum;

  String? _mesaj;
  String? get message => _mesaj;

  String? _islenen;
  String? get busyProduct => _islenen;

  void _git(PurchaseFlowState s, [String? m]) {
    _durum = s;
    _mesaj = m;
    notifyListeners();
  }

  /// Katalog + fiyatlar; ayrıca bekleyen/yarım kalmış işlemleri dinler
  Future<void> load() async {
    _abone ??= _store.updates.listen(_guncellemeler);
    _git(PurchaseFlowState.loading);
    final k = (await Result.guard(_api.catalog)).dataOrNull;
    final hazir = await _store.isAvailable();
    if (k == null || k['enabled'] != true || !hazir) {
      _acik = false;
      _urunler = const [];
      _git(PurchaseFlowState.idle);
      return;
    }
    final ham = [for (final p in k['products'] as List? ?? const []) Map<String, dynamic>.from(p as Map)];
    final fiyatlar = await _store.prices({for (final p in ham) p['store_product_id'].toString()});
    _urunler = [
      for (final p in ham)
        if (fiyatlar.containsKey(p['store_product_id'])) ShopProduct.fromJson(p, fiyatlar[p['store_product_id']]),
    ];
    _acik = _urunler.isNotEmpty;
    _git(PurchaseFlowState.idle);
  }

  Future<void> buy(ShopProduct p) async {
    final kullanici = _session?.user;
    if (!p.purchasable || _islenen != null || kullanici == null) return;
    _islenen = p.id;
    _git(PurchaseFlowState.purchasing);
    final basladi = await _store.buy(p.storeProductId, consumable: p.consumable, accountId: kullanici.id);
    if (!basladi) {
      _islenen = null;
      _git(PurchaseFlowState.failed, 'Satın alma başlatılamadı.'.tr);
    }
    // Sonuç mağaza akışından (_guncellemeler) gelir
  }

  Future<void> restore() => _store.restore();

  Future<void> _guncellemeler(List<StorePurchase> liste) async {
    for (final p in liste) {
      switch (p.status) {
        case StorePurchaseStatus.pending:
          _git(PurchaseFlowState.pending, 'Ödeme onay bekliyor. Onaylanınca elmasların hesabına geçecek.'.tr);
        case StorePurchaseStatus.canceled:
          _islenen = null;
          _git(PurchaseFlowState.cancelled, 'Satın alma iptal edildi.'.tr);
          await _store.complete(p);
        case StorePurchaseStatus.error:
          _islenen = null;
          _git(PurchaseFlowState.failed, 'Satın alma tamamlanamadı. Ücret alınmadıysa tekrar deneyebilirsin.'.tr);
          await _store.complete(p);
        case StorePurchaseStatus.purchased:
        case StorePurchaseStatus.restored:
          await _dogrula(p);
      }
    }
  }

  Future<void> _dogrula(StorePurchase p) async {
    _git(PurchaseFlowState.verifying, 'Satın alma doğrulanıyor…'.tr);
    final r = await Result.guard(() => _api.verify(p));
    final cevap = r.dataOrNull;
    final hata = r.errorOrNull;
    if (cevap != null) {
      final durum = cevap['status'];
      if (durum == 'pending') {
        _islenen = null;
        _git(PurchaseFlowState.pending, 'Ödeme onay bekliyor. Onaylanınca elmasların hesabına geçecek.'.tr);
        return;
      }
      // Sunucu ödülü verdi (ya da zaten vermişti): artık mağazaya "tamam" de
      await _store.complete(p);
      _islenen = null;
      final elmas = (cevap['paid_gems'] as num?)?.toInt();
      final u = _session?.user;
      if (u != null && elmas != null) await _session!.updateUser(u.copyWith(paidGems: elmas));
      // Önce kataloğu yenile (sahiplik), sonra sonucu yaz: load() durumu
      // sıfırladığı için ters sırada başarı mesajı hemen kayboluyordu.
      await load();
      if (durum == 'failed') {
        _git(PurchaseFlowState.failed, 'Bu ürün zaten alınmış; ücret iadesi için destekle iletişime geç.'.tr);
      } else {
        _git(PurchaseFlowState.success, 'Satın alma tamamlandı!'.tr);
      }
      return;
    }
    _islenen = null;
    // Geçici hata: mağazaya "tamam" DENMEZ; işlem bir sonraki açılışta
    // yeniden gelir ve doğrulama tekrar denenir (ödeme kaybolmaz).
    final kalici =
        hata != null &&
        const {
          'invalid_receipt',
          'account_mismatch',
          'purchase_cancelled',
          'wrong_product',
          'wrong_app',
          'purchase_belongs_to_another_account',
        }.contains(hata.technicalDetail);
    if (kalici) await _store.complete(p);
    _git(
      PurchaseFlowState.failed,
      kalici
          ? 'Satın alma doğrulanamadı.'.tr
          : 'Satın alma şu an doğrulanamadı; ödemen kaybolmaz, uygulama açılınca yeniden denenecek.'.tr,
    );
  }

  /// Mağaza güncellemesini doğrudan işle (testler ve geri yükleme)
  Future<void> handleUpdates(List<StorePurchase> l) => _guncellemeler(l);

  @override
  void dispose() {
    _abone?.cancel();
    super.dispose();
  }
}
