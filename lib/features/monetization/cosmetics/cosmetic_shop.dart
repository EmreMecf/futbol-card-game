import 'package:material_ui/material_ui.dart' show ChangeNotifier;

import '../../../core/auth/session_manager.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/l10n/app_language.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/result.dart';
import '../../items/cosmetics/equipped_cosmetics.dart';
import '../../items/domain/items_repository.dart';
import '../monetization_models.dart';

/// 062 — elmasla satılan sabit içerikli kozmetik (rastgele ürün yok)
class CosmeticOffer {
  final String id;
  final String itemSlug;
  final String name;
  final String description;
  final String slot;
  final int priceGems;
  final bool featured;
  final bool owned;
  final bool equipped;
  const CosmeticOffer({
    required this.id,
    required this.itemSlug,
    required this.name,
    required this.description,
    required this.slot,
    required this.priceGems,
    this.featured = false,
    this.owned = false,
    this.equipped = false,
  });

  factory CosmeticOffer.fromJson(Map<String, dynamic> j) => CosmeticOffer(
    id: j['id'].toString(),
    itemSlug: j['item_slug'].toString(),
    name: j['name']?.toString() ?? '',
    description: j['description']?.toString() ?? '',
    slot: j['slot']?.toString() ?? '',
    priceGems: (j['price_gems'] as num?)?.toInt() ?? 0,
    featured: j['featured'] == true,
    owned: j['owned'] == true,
    equipped: j['equipped'] == true,
  );
}

class CosmeticShopApi {
  final ApiClient api;
  CosmeticShopApi(this.api);

  Future<Map<String, dynamic>> shop() =>
      api.get('/shop/cosmetics', sorgu: {'platform': clientPlatform, 'app_version': kAppVersion});

  Future<Map<String, dynamic>> buy(String offerId, String requestKey) => api.post(
    '/shop/cosmetics/buy',
    govde: {'offer_id': offerId, 'request_key': requestKey, 'platform': clientPlatform, 'app_version': kAppVersion},
  );
}

/// Sunucu hata kodu → mesaj
String cosmeticShopError(String? code) => switch (code) {
  'not_enough_gems' => 'Yeterli elmasın yok.'.tr,
  'already_owned' => 'Bu kozmetiğe zaten sahipsin.'.tr,
  'offer_not_available' || 'offer_not_found' => 'Bu teklif şu an satışta değil.'.tr,
  'shop_disabled' => 'Kozmetik mağazası şu an kapalı.'.tr,
  _ => 'Satın alma tamamlanamadı, tekrar dene.'.tr,
};

/// 062 — KOZMETİK MAĞAZA.
///
///   * Liste, fiyat ve sahiplik SUNUCUDAN; istemci yalnız teklif kimliği
///     ve istek anahtarı gönderir.
///   * Ağ hatasında aynı teklif aynı anahtarla yeniden denenir: sunucu
///     ikinci kez harcamaz.
///   * Sunucu kapalı derse (bayrak) mağaza hiç görünmez.
class CosmeticShopController extends ChangeNotifier {
  final CosmeticShopApi _api;
  final SessionManager? _session;
  final ItemsRepository? _items;

  CosmeticShopController(this._api, {SessionManager? session, ItemsRepository? items})
    // ignore: prefer_initializing_formals
    : _session = session,
      // ignore: prefer_initializing_formals
      _items = items;

  bool _acik = false;
  bool get enabled => _acik;

  bool _yukleniyor = false;
  bool get loading => _yukleniyor;

  List<CosmeticOffer> _teklifler = const [];
  List<CosmeticOffer> get offers => _teklifler;

  int _gems = 0;
  int _paidGems = 0;

  /// Harcanabilir toplam (önce ücretsiz, sonra ücretli harcanır)
  int get totalGems => _gems + _paidGems;
  int get freeGems => _gems;
  int get paidGems => _paidGems;

  String? _islenen;
  String? get busyOffer => _islenen;

  String? _hata;
  String? get error => _hata;

  final Map<String, String> _anahtarlar = {};
  bool _kapandi = false;

  void _bildir() {
    if (!_kapandi) notifyListeners();
  }

  Future<void> load() async {
    _yukleniyor = true;
    _bildir();
    final j = (await Result.guard(_api.shop)).dataOrNull;
    _yukleniyor = false;
    if (j == null || j['enabled'] != true) {
      _acik = false;
      _teklifler = const [];
      _bildir();
      return;
    }
    _gems = (j['gems'] as num?)?.toInt() ?? 0;
    _paidGems = (j['paid_gems'] as num?)?.toInt() ?? 0;
    _teklifler = [
      for (final o in j['offers'] as List? ?? const []) CosmeticOffer.fromJson(Map<String, dynamic>.from(o as Map)),
    ];
    _acik = true;
    _bildir();
  }

  bool canAfford(CosmeticOffer o) => totalGems >= o.priceGems;

  /// Satın al; başarılıysa true
  Future<bool> buy(CosmeticOffer o) async {
    if (_islenen != null || o.owned) return false;
    final anahtar = _anahtarlar.putIfAbsent(o.id, ApiClient.newIdempotencyKey);
    _islenen = o.id;
    _hata = null;
    _bildir();
    final r = await Result.guard(() => _api.buy(o.id, anahtar));
    _islenen = null;
    final hata = r.errorOrNull;
    if (hata != null) {
      // Ağ hatasında anahtar korunur: tekrar denemede çift harcama olmaz
      if (hata.type != AppErrorType.network) _anahtarlar.remove(o.id);
      _hata = cosmeticShopError(hata.technicalDetail);
      _bildir();
      return false;
    }
    _anahtarlar.remove(o.id);
    final j = r.dataOrNull ?? const {};
    final u = _session?.user;
    final gems = (j['gems'] as num?)?.toInt();
    final paid = (j['paid_gems'] as num?)?.toInt();
    if (u != null && gems != null) {
      await _session!.updateUser(u.copyWith(gems: gems, paidGems: paid ?? u.paidGems));
    }
    await load();
    return true;
  }

  /// Sahip olunan kozmetiği giy (envanter ucuyla)
  Future<bool> equip(CosmeticOffer o) async {
    final items = _items;
    if (items == null || _islenen != null) return false;
    _islenen = o.id;
    _hata = null;
    _bildir();
    final r = await items.equip(o.itemSlug, idempotencyKey: ApiClient.newIdempotencyKey());
    _islenen = null;
    if (r.errorOrNull != null) {
      _hata = itemErrorMessage(r.errorOrNull!.technicalDetail, r.errorOrNull!.message);
      _bildir();
      return false;
    }
    await EquippedCosmetics.current?.refresh();
    await load();
    return true;
  }

  @override
  void dispose() {
    _kapandi = true;
    super.dispose();
  }
}
