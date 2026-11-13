import 'package:shared_models/shared_models.dart';

import '../../../../core/base/base_view_model.dart';
import '../../../../core/base/view_state.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/result.dart';
import '../../cosmetics/equipped_cosmetics.dart';
import '../../domain/items_repository.dart';

/// ENVANTER (Ekonomi V2, FAZ 3). Her eylem bir idempotency anahtarı
/// alır; ağ hatasında aynı eylem aynı anahtarla tekrar denenir.
class ItemsViewModel extends BaseViewModel {
  final ItemsRepository _repository;
  ItemsViewModel(this._repository);

  ItemInventory? _envanter;
  ItemInventory? get inventory => _envanter;

  String? _islenen;
  String? get busySlug => _islenen;

  String? _hata;
  String? get actionError => _hata;

  String? _bilgi;
  String? get lastInfo => _bilgi;

  final Map<String, String> _anahtarlar = {};

  Future<void> load() async {
    final e = await run(() => _repository.fetchInventory(), loadingState: ViewState.loading);
    if (e != null) {
      _envanter = e;
      _kozmetikleriYay(e);
      safeNotify();
    }
  }

  Future<void> _tazele() async {
    final e = (await _repository.fetchInventory()).dataOrNull;
    if (e != null) {
      _envanter = e;
      _kozmetikleriYay(e);
    }
  }

  /// FAZ 6: giyilenler bütün ekranlara (profil, kartlar, arena, maç sonu)
  void _kozmetikleriYay(ItemInventory e) => EquippedCosmetics.current?.apply(e.enabled ? e.equipped : const {});

  /// Envanterden kullanılan item (şimdilik enerji içeceği)
  Future<bool> use(ItemDefinition d) => _eylem(d.slug, 'use:${d.slug}:${_envanter?.quantity(d.slug)}',
      (k) => _repository.use(d.slug, idempotencyKey: k), (sonuc) {
    _bilgi = d.category == 'energy_drink' && sonuc['energy'] != null
        ? 'Sandık hakkın ${sonuc['energy']} oldu.'
        : '${d.name} kullanıldı.';
  });

  Future<bool> equip(ItemDefinition d) =>
      _eylem(d.slug, 'equip:${d.slug}', (k) => _repository.equip(d.slug, idempotencyKey: k), (_) {
        _bilgi = '${d.name} giyildi.';
      });

  Future<bool> unequip(ItemDefinition d) => _eylem(d.slug, 'unequip:${d.cosmeticSlot}',
      (k) => _repository.unequip(d.cosmeticSlot!, idempotencyKey: k), (_) {
    _bilgi = '${d.name} çıkarıldı.';
  });

  Future<bool> _eylem<T>(String slug, String eylem, Future<Result<T>> Function(String) is_, void Function(T) ok) async {
    if (_islenen != null) return false;
    final anahtar = _anahtarlar.putIfAbsent(eylem, ApiClient.newIdempotencyKey);
    _islenen = slug;
    _hata = null;
    _bilgi = null;
    safeNotify();
    final s = await is_(anahtar);
    _islenen = null;
    final hata = s.errorOrNull;
    if (hata != null) {
      if (hata.type != AppErrorType.network) _anahtarlar.remove(eylem);
      _hata = itemErrorMessage(hata.technicalDetail, hata.message);
      safeNotify();
      return false;
    }
    _anahtarlar.remove(eylem);
    ok(s.dataOrNull as T);
    await _tazele();
    safeNotify();
    return true;
  }
}
