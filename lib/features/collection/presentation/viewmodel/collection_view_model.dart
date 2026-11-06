import 'dart:async';

import 'package:shared_models/shared_models.dart';

import '../../../../core/base/base_view_model.dart';
import '../../../../core/base/view_state.dart';
import '../../../../core/storage/favorites_store.dart';
import '../../../../core/utils/turkish_text.dart';
import '../../domain/repositories/collection_repository.dart';

/// Koleksiyonun siralama secenekleri
enum CollectionSort {
  powerDesc('Güce göre (yüksek → düşük)'),
  powerAsc('Güce göre (düşük → yüksek)'),
  tierDesc('Seviyeye göre'),
  nameAsc('İsme göre');

  final String label;
  const CollectionSort(this.label);
}

/// Koleksiyon ekraninin beyni.
///
/// TASARIM NOTU - FILTRELEME NEREDE YAPILIYOR?
/// Kartlarin tamami tek istekle geliyor (100-200 kart cok kucuk bir
/// veri). Filtreleme ve siralama BELLEKTE yapiliyor; her filtre
/// degisiminde sunucuya gitmiyoruz. Boylece filtreler aninda tepki
/// veriyor ve sunucu yuku olmuyor.
///
/// Koleksiyon binlerce karta cikarsa sunucu tarafi sayfalama (pagination)
/// gerekir; o zamana kadar bu yaklasim hem daha hizli hem daha basit.
class CollectionViewModel extends BaseViewModel {
  final CollectionRepository _repository;

  /// Favoriler bu cihazda saklanıyor. Bkz. [FavoritesStore].
  final FavoritesStore _favoriler;

  CollectionViewModel(this._repository, [FavoritesStore? favoriler])
      : _favoriler = favoriler ?? FavoritesStore();

  List<InventoryCard> _tumKartlar = [];

  /// Ham liste (filtresiz)
  List<InventoryCard> get allCards => _tumKartlar;

  // ---- FILTRELER ----
  CardTier? _seviyeFiltresi;
  CardPosition? _pozisyonFiltresi;
  String _arama = '';
  CollectionSort _siralama = CollectionSort.powerDesc;
  bool _sadeceFavoriler = false;

  /// Sadece favoriler mi gösteriliyor?
  bool get favoritesOnly => _sadeceFavoriler;

  CardTier? get tierFilter => _seviyeFiltresi;
  CardPosition? get positionFilter => _pozisyonFiltresi;
  String get search => _arama;
  CollectionSort get sort => _siralama;

  /// Herhangi bir filtre aktif mi?
  bool get hasActiveFilter =>
      _seviyeFiltresi != null ||
      _pozisyonFiltresi != null ||
      _arama.isNotEmpty ||
      _sadeceFavoriler;

  // ------------------------------------------------------------------
  // FILTRELENMIS LISTE
  // ------------------------------------------------------------------
  List<InventoryCard> get filteredCards {
    // Arama Türkçe küçük harfe çevrilerek yapılıyor: 'İsmail' araması
    // toLowerCase() ile 'i̇smail' (birleşik nokta) olup eşleşmiyordu.
    final aranan = _arama.toLowerTr();

    final liste = _tumKartlar.where((k) {
      if (_sadeceFavoriler && !_favoriler.isFavorite(k.cardId)) return false;
      if (_seviyeFiltresi != null && k.tier != _seviyeFiltresi) return false;
      if (_pozisyonFiltresi != null && k.position != _pozisyonFiltresi) {
        return false;
      }
      if (_arama.isNotEmpty) {
        final metin = '${k.fullName} ${k.club ?? ''} ${k.nationality ?? ''}'
            .toLowerTr();
        if (!metin.contains(aranan)) return false;
      }
      return true;
    }).toList();

    liste.sort(switch (_siralama) {
      CollectionSort.powerDesc => (a, b) => b.power.compareTo(a.power),
      CollectionSort.powerAsc => (a, b) => a.power.compareTo(b.power),
      CollectionSort.tierDesc => (a, b) {
          final fark = b.tier.rank.compareTo(a.tier.rank);
          return fark != 0 ? fark : b.power.compareTo(a.power);
        },
      CollectionSort.nameAsc => (a, b) => a.fullName.compareTo(b.fullName),
    });

    return liste;
  }

  // ------------------------------------------------------------------
  // ISTATISTIKLER (ust bantta gosterilir)
  // ------------------------------------------------------------------
  int get totalCards => _tumKartlar.length;

  /// Seviye basina kart sayisi
  Map<CardTier, int> get tierCounts {
    final sayim = <CardTier, int>{for (final t in CardTier.values) t: 0};
    for (final k in _tumKartlar) {
      sayim[k.tier] = (sayim[k.tier] ?? 0) + 1;
    }
    return sayim;
  }

  /// Pozisyon basina kart sayisi
  Map<CardPosition, int> get positionCounts {
    final sayim = <CardPosition, int>{
      for (final p in CardPosition.values) p: 0,
    };
    for (final k in _tumKartlar) {
      sayim[k.position] = (sayim[k.position] ?? 0) + 1;
    }
    return sayim;
  }

  // ------------------------------------------------------------------
  // FAVORİLER
  // ------------------------------------------------------------------
  bool isFavorite(InventoryCard kart) => _favoriler.isFavorite(kart.cardId);

  /// Koleksiyonda şu an bulunan favori kart sayısı.
  ///
  /// Depodaki toplamdan farklı olabilir: favori bir oyuncuyu maçta
  /// kaptırdıysan işaret durur ama kart koleksiyonda yoktur.
  int get favoriteCount =>
      _tumKartlar.where((k) => _favoriler.isFavorite(k.cardId)).length;

  /// Favoriyi açar/kapatır.
  ///
  /// `false` dönerse sınıra ([FavoritesStore.maxFavorites]) ulaşıldı ve
  /// favori EKLENMEDİ; ekran oyuncuya söylemeli.
  Future<bool> toggleFavorite(InventoryCard kart) async {
    final onceden = _favoriler.isFavorite(kart.cardId);
    final simdi = await _favoriler.toggle(kart.cardId);
    safeNotify();
    // Kaldırma her zaman başarılı; ekleme sınıra takılabilir
    return onceden || simdi;
  }

  void setFavoritesOnly(bool acik) {
    _sadeceFavoriler = acik;
    safeNotify();
  }

  /// Koleksiyondaki en guclu kart
  InventoryCard? get bestCard {
    if (_tumKartlar.isEmpty) return null;
    return _tumKartlar.reduce((a, b) {
      if (a.tier.rank != b.tier.rank) {
        return a.tier.rank > b.tier.rank ? a : b;
      }
      return a.power >= b.power ? a : b;
    });
  }

  /// Zorunlu formasyon (1-4-4-2) kurulabiliyor mu?
  bool get canBuildSquad => CardPosition.values.every(
        (p) => (positionCounts[p] ?? 0) >= p.requiredCount,
      );

  // ------------------------------------------------------------------
  // VERI YUKLEME
  // ------------------------------------------------------------------
  Future<void> load({bool showLoading = true}) async {
    // Favoriler kartları BEKLETMEZ: cihaz deposu yavaşsa oyuncu
    // kalpler yüzünden koleksiyonunu göremezdi. Kartlar hemen gelir,
    // favori işaretleri yüklenince ekran tazelenir.
    unawaited(_favoriler.load().then((_) => safeNotify()));

    final kartlar = await run(
      () => _repository.fetchInventory(),
      showLoading: showLoading,
      loadingState: ViewState.loading,
    );

    if (kartlar != null) {
      _tumKartlar = kartlar;
      safeNotify();
    }
  }

  /// SADECE GELISTIRME: katalogdaki tum kartlari hesaba ekler
  Future<bool> devGrantAllCards() async {
    final sonuc = await run(() => _repository.devGrantAllCards());
    if (sonuc == null) return false;

    await load(showLoading: false);
    return true;
  }

  // ------------------------------------------------------------------
  // FILTRE AYARLARI
  // ------------------------------------------------------------------
  void setTierFilter(CardTier? tier) {
    // Ayni seviyeye tekrar basilirsa filtreyi kaldir
    _seviyeFiltresi = _seviyeFiltresi == tier ? null : tier;
    safeNotify();
  }

  void setPositionFilter(CardPosition? position) {
    _pozisyonFiltresi = _pozisyonFiltresi == position ? null : position;
    safeNotify();
  }

  void setSearch(String metin) {
    _arama = metin.trim();
    safeNotify();
  }

  void setSort(CollectionSort siralama) {
    _siralama = siralama;
    safeNotify();
  }

  void clearFilters() {
    _seviyeFiltresi = null;
    _pozisyonFiltresi = null;
    _arama = '';
    _sadeceFavoriler = false;
    safeNotify();
  }
}
