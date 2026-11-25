import 'package:shared_models/shared_models.dart';

import '../../../../core/audio/game_audio.dart';
import '../../../../core/auth/session_manager.dart';
import '../../../../core/base/base_view_model.dart';
import '../../../../core/base/view_state.dart';
import '../../../../core/error/app_exception.dart';
import '../../domain/repositories/store_repository.dart';
import '../../../../core/l10n/app_language.dart';

/// Magaza ekraninin beyni.
class StoreViewModel extends BaseViewModel {
  final StoreRepository _repository;
  final SessionManager _session;

  StoreViewModel(
    this._repository,
    this._session, {
    Future<DailyShopStatus?> Function()? dailyOffer,
    Future<PackOpenResult> Function()? buyDailyOffer,
  })  // ignore: prefer_initializing_formals
      : _teklifSor = dailyOffer,
        // ignore: prefer_initializing_formals
        _teklifAl = buyDailyOffer;

  // 044: GÜNÜN TEKLİFİ (kayıt yoksa ya da anahtar kapalıysa yok)
  final Future<DailyShopStatus?> Function()? _teklifSor;
  final Future<PackOpenResult> Function()? _teklifAl;
  DailyShopStatus? _teklif;
  DailyShopStatus? get dailyOffer => (_teklif?.enabled ?? false) ? _teklif : null;
  bool get canBuyDailyOffer {
    final t = dailyOffer;
    return t != null && !t.boughtToday && coins >= t.discountedPrice && _acilanPaket == null;
  }

  List<PackType> _paketler = [];
  List<PackType> get packs => _paketler;

  /// Acilan paketin sonucu (acilis animasyonu icin)
  PackOpenResult? _sonAcilis;
  PackOpenResult? get lastOpening => _sonAcilis;

  /// Su an hangi paket aciliyor? (buton kilidi icin)
  String? _acilanPaket;
  String? get openingPackSlug => _acilanPaket;

  /// Oyuncunun coin'i
  int get coins => _session.user?.coins ?? 0;

  bool canAfford(PackType paket) => coins >= paket.priceCoins;

  /// Vitrinde one cikarilacak TEK paket.
  ///
  /// Elle bir "featured" bayragi tutmak yerine veriden turetiliyor:
  /// Legend cikma ihtimali EN YUKSEK olan satin alinabilir paket.
  /// Boylece yeni bir paket eklendiginde vitrin kendiliginden
  /// guncelleniyor.
  ///
  /// Hepsini one cikarmak hicbirini one cikarmamakla ayni sey; bu
  /// yuzden yalnizca bir tane donuyor.
  String? get featuredSlug {
    PackType? enIyi;
    var enYuksek = 0;

    for (final p in _paketler) {
      if (!p.isPurchasable || p.priceCoins <= 0) continue;
      final legend = p.legendOdds?.weight ?? 0;
      if (legend > enYuksek) {
        enYuksek = legend;
        enIyi = p;
      }
    }
    return enIyi?.slug;
  }

  Future<void> load() async {
    final liste = await run(() => _repository.fetchPacks(), loadingState: ViewState.loading);

    if (liste != null) {
      _paketler = liste;
      safeNotify();
    }
    await loadDailyOffer();
  }

  Future<void> loadDailyOffer() async {
    final sor = _teklifSor;
    if (sor == null) return;
    _teklif = await sor();
    safeNotify();
  }

  /// 044: günün teklifini al; başarılıysa [lastOpening] dolar (aynı açılış).
  Future<bool> buyDailyOffer() async {
    final al = _teklifAl;
    if (al == null || !canBuyDailyOffer) return false;
    _acilanPaket = dailyOffer!.packSlug;
    _sonAcilis = null;
    safeNotify();
    try {
      _sonAcilis = await al();
    } catch (e) {
      _acilanPaket = null;
      setError(AppException(message: 'Günün teklifi alınamadı. Tekrar dene.'.tr, technicalDetail: '$e', type: AppErrorType.gameRule));
      safeNotify();
      return false;
    }
    _acilanPaket = null;
    GameAudio.sfx(Sfx.purchase);
    final kullanici = _session.user;
    final acilis = _sonAcilis;
    if (kullanici != null && acilis != null) {
      await _session.updateUser(kullanici.copyWith(coins: acilis.coinsLeft));
    }
    await loadDailyOffer();
    safeNotify();
    return true;
  }

  /// Paketi acar. Basariliysa [lastOpening] doldurulur.
  Future<bool> openPack(PackType paket) async {
    if (_acilanPaket != null) return false;

    // Sunucu zaten kontrol ediyor; burasi sadece gereksiz istek atmamak icin
    if (!canAfford(paket)) {
      return false;
    }

    _acilanPaket = paket.slug;
    _sonAcilis = null;
    safeNotify();

    final sonuc = await _repository.openPack(paket.slug);
    _acilanPaket = null;

    final hata = sonuc.errorOrNull;
    if (hata != null) {
      setError(hata);
      safeNotify();
      return false;
    }

    _sonAcilis = sonuc.dataOrNull;

    // Coin degisti; oturumu guncelle ki ust bantta dogru gorunsun
    final kullanici = _session.user;
    final acilis = _sonAcilis;
    if (kullanici != null && acilis != null) {
      await _session.updateUser(kullanici.copyWith(coins: acilis.coinsLeft));
    }

    safeNotify();
    GameAudio.sfx(Sfx.purchase);
    return true;
  }

  /// Acilis animasyonu bitince cagrilir
  void clearOpening() {
    _sonAcilis = null;
    safeNotify();
  }
}
