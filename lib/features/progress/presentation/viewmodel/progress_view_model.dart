import 'package:shared_models/shared_models.dart';

import '../../../../core/auth/session_manager.dart';
import '../../../../core/base/base_view_model.dart';
import '../../../../core/base/view_state.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/network/api_client.dart';
import '../../../items/domain/items_repository.dart';
import '../../domain/progress_repository.dart';

/// Futbolcu gelişimi (Ekonomi V2, FAZ 2).
///
/// K1 (onaylı): seviye dereceli maçta kart gücünü DEĞİŞTİRMEZ; ustalık
/// göstergesidir ve 5./10. seviyede tek seferlik ödül verir.
///
/// Her eylem bir idempotency anahtarı alır; ağ hatasında aynı eylem aynı
/// anahtarla tekrar denenir (altın iki kez düşmez, kopya iki kez
/// dönüşmez).
class ProgressViewModel extends BaseViewModel {
  final ProgressRepository _repository;
  final SessionManager? _session;

  // ignore: prefer_initializing_formals
  ProgressViewModel(this._repository, {SessionManager? session, ItemsRepository? items})
      // ignore: prefer_initializing_formals
      : _session = session,
        // ignore: prefer_initializing_formals
        _items = items;

  /// FAZ 3: ustalık kitabı kullanımı (kayıtlı değilse seçenek yok)
  final ItemsRepository? _items;
  bool get canUseItems => _items != null;

  ProgressOverview? _ozet;
  ProgressOverview? get overview => _ozet;
  bool get isEnabled => _ozet?.enabled ?? false;

  /// Filtre: yalnız seviye atlayabilecekler
  bool _yalnizHazir = false;
  bool get onlyReady => _yalnizHazir;

  String? _islenen;
  String? get busyCardId => _islenen;

  String? _hata;
  String? get actionError => _hata;

  LevelUpResult? _sonAtlama;
  LevelUpResult? get lastLevelUp => _sonAtlama;

  final Map<String, String> _anahtarlar = {};

  List<PlayerProgressItem> get visibleItems {
    final o = _ozet;
    if (o == null) return const [];
    final liste = o.items.where((i) => i.isOwned).toList()
      ..sort((a, b) {
        // Hazır olanlar önce, sonra seviye, sonra güç
        final ha = o.isSuggested(a) ? 1 : 0;
        final hb = o.isSuggested(b) ? 1 : 0;
        if (ha != hb) return hb - ha;
        if (a.level != b.level) return b.level - a.level;
        return b.power - a.power;
      });
    return _yalnizHazir ? liste.where(o.isSuggested).toList() : liste;
  }

  void setOnlyReady(bool v) {
    _yalnizHazir = v;
    safeNotify();
  }

  Future<void> load() async {
    final o = await run(() => _repository.fetchOverview(), loadingState: ViewState.loading);
    if (o != null) {
      _ozet = o;
      safeNotify();
    }
  }

  Future<void> _tazele() async {
    final o = (await _repository.fetchOverview()).dataOrNull;
    if (o != null) _ozet = o;
  }

  Future<bool> levelUp(PlayerProgressItem item, {bool useJokers = false, bool useDiscount = false}) async {
    if (_islenen != null) return false;
    // Anahtar HEDEF seviyeye bağlı: aynı seviye için tekrar = aynı anahtar
    final eylem = 'level:${item.cardId}:${item.level + 1}:$useJokers:$useDiscount';
    final anahtar = _anahtarlar.putIfAbsent(eylem, ApiClient.newIdempotencyKey);
    _islenen = item.cardId;
    _hata = null;
    safeNotify();
    final s = await _repository.levelUp(item.cardId,
        useJokers: useJokers, useDiscount: useDiscount, idempotencyKey: anahtar);
    _islenen = null;
    final hata = s.errorOrNull;
    if (hata != null) {
      if (hata.type != AppErrorType.network) _anahtarlar.remove(eylem);
      _hata = progressErrorMessage(hata.technicalDetail, hata.message);
      safeNotify();
      return false;
    }
    _anahtarlar.remove(eylem);
    _sonAtlama = s.dataOrNull;
    await _altinGuncelle(_sonAtlama?.coinsAfter);
    await _tazele();
    safeNotify();
    return true;
  }

  Future<bool> convert(PlayerProgressItem item, int count) async {
    if (_islenen != null || count < 1) return false;
    final eylem = 'convert:${item.cardId}:${item.ownedCopies}:$count';
    final anahtar = _anahtarlar.putIfAbsent(eylem, ApiClient.newIdempotencyKey);
    _islenen = item.cardId;
    _hata = null;
    safeNotify();
    final s = await _repository.convert(item.cardId, count, idempotencyKey: anahtar);
    _islenen = null;
    final hata = s.errorOrNull;
    if (hata != null) {
      if (hata.type != AppErrorType.network) _anahtarlar.remove(eylem);
      _hata = progressErrorMessage(hata.technicalDetail, hata.message);
      safeNotify();
      return false;
    }
    _anahtarlar.remove(eylem);
    await _tazele();
    safeNotify();
    return true;
  }

  /// Ustalık kitabı: bu seviye için gereken kopyayı verir (altın yine ödenir)
  Future<bool> useBook(PlayerProgressItem item) async {
    final depo = _items;
    if (_islenen != null || depo == null) return false;
    final eylem = 'book:${item.cardId}:${item.level}:${item.copies}';
    final anahtar = _anahtarlar.putIfAbsent(eylem, ApiClient.newIdempotencyKey);
    _islenen = item.cardId;
    _hata = null;
    safeNotify();
    final s = await depo.use('mastery_book_${item.tier.name}', target: {'card_id': item.cardId}, idempotencyKey: anahtar);
    _islenen = null;
    final hata = s.errorOrNull;
    if (hata != null) {
      if (hata.type != AppErrorType.network) _anahtarlar.remove(eylem);
      _hata = progressErrorMessage(hata.technicalDetail, hata.message);
      safeNotify();
      return false;
    }
    _anahtarlar.remove(eylem);
    await _tazele();
    safeNotify();
    return true;
  }

  void clearLastLevelUp() {
    _sonAtlama = null;
    safeNotify();
  }

  Future<void> _altinGuncelle(int? altin) async {
    final k = _session?.user;
    if (k != null && altin != null) await _session!.updateUser(k.copyWith(coins: altin));
  }
}
