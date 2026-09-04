import 'package:shared_models/shared_models.dart';

import '../../../../core/auth/session_manager.dart';
import '../../../../core/base/base_view_model.dart';
import '../../../../core/base/view_state.dart';
import '../../domain/repositories/store_repository.dart';

/// Magaza ekraninin beyni.
class StoreViewModel extends BaseViewModel {
  final StoreRepository _repository;
  final SessionManager _session;

  StoreViewModel(this._repository, this._session);

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
    final liste = await run(
      () => _repository.fetchPacks(),
      loadingState: ViewState.loading,
    );

    if (liste != null) {
      _paketler = liste;
      safeNotify();
    }
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
      await _session.updateUser(
        kullanici.copyWith(coins: acilis.coinsLeft),
      );
    }

    safeNotify();
    return true;
  }

  /// Acilis animasyonu bitince cagrilir
  void clearOpening() {
    _sonAcilis = null;
    safeNotify();
  }
}
