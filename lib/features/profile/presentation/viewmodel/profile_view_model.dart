import 'package:shared_models/shared_models.dart';

import '../../../../core/auth/session_manager.dart';
import '../../../../core/base/base_view_model.dart';
import '../../../../core/storage/favorites_store.dart';
import '../../../collection/domain/repositories/collection_repository.dart';
import '../../domain/achievements.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../leaderboard/domain/repositories/leaderboard_repository.dart';
import '../../../match/domain/repositories/match_repository.dart';

/// Profil ekranının verisi.
///
/// İki kaynaktan besleniyor:
///   1. [SessionManager] — kullanıcının anlık sayaçları (coin, puan,
///      galibiyet). Bunlar zaten oturumda tutuluyor.
///   2. [MatchRepository] — bitmiş maçların listesi. Bu veri sadece
///      profil ekranında gerektiği için burada çekiliyor, oturuma
///      yüklenmiyor.
class ProfileViewModel extends BaseViewModel {
  final MatchRepository _matchRepository;
  final AuthRepository _authRepository;
  final LeaderboardRepository _leaderboardRepository;
  final SessionManager _session;

  /// Favori kartlar için (isteğe bağlı: yoksa bölüm gösterilmez)
  final CollectionRepository? _collectionRepository;
  final FavoritesStore? _favoriler;

  ProfileViewModel(
    this._matchRepository,
    this._authRepository,
    this._leaderboardRepository,
    this._session, {
    CollectionRepository? collectionRepository,
    FavoritesStore? favorites,
  }) // Yeni "özel adlı parametre" yazımı projede başka hiçbir yerde
    // kullanılmıyor; okunurluk için alışılmış yazım korunuyor.
    // ignore: prefer_initializing_formals
    : _collectionRepository = collectionRepository,
       _favoriler = favorites;

  // ------------------------------------------------------------------
  // BAŞARIMLAR
  // ------------------------------------------------------------------
  /// Gerçek sayaçlardan hesaplanan, ödülsüz başarımlar.
  /// Bkz. [Achievement] — neyin bilerek eklenmediği orada yazıyor.
  List<Achievement> get achievements =>
      Achievement.evaluate(_session.user, _rutbe);

  int get unlockedAchievementCount =>
      achievements.where((a) => a.isUnlocked).length;

  // ------------------------------------------------------------------
  // FAVORİ KARTLAR
  // ------------------------------------------------------------------
  List<InventoryCard> _favoriKartlar = const [];

  /// Koleksiyondaki favori kartlar (en iyiden kötüye, en fazla 6).
  ///
  /// Aynı oyuncudan birden fazla kopya varsa bir kez gösterilir:
  /// favori, oyuncuya (cardId) bağlı.
  List<InventoryCard> get favoriteCards => _favoriKartlar;

  /// Favori bölümü gösterilebilir mi? (bağımlılıklar verilmiş mi)
  bool get supportsFavorites =>
      _collectionRepository != null && _favoriler != null;

  static const int maxFavoritesShown = 6;

  PlayerRank? _rutbe;

  /// Oyuncunun lig basamagi. Sunucu hesapliyor.
  PlayerRank? get rank => _rutbe;

  List<MatchHistoryEntry> _gecmis = const [];
  List<MatchHistoryEntry> get history => _gecmis;

  UserModel? get user => _session.user;

  int get protectionSlots => _session.protectionSlots;

  /// Toplam oynanan maç
  int get totalMatches {
    final k = user;
    if (k == null) return 0;
    return k.wins + k.losses + k.draws;
  }

  /// Kazanma oranı (0.0 - 1.0). Hiç maç yoksa 0.
  double get winRate {
    final toplam = totalMatches;
    if (toplam == 0) return 0;
    return (user?.wins ?? 0) / toplam;
  }

  /// Çekilen maçlarda toplam kaç kart kazanıldı?
  ///
  /// Oyuncunun yüksek risk modunda ne kadar kazandığını tek sayıda
  /// gösteriyor. Sadece son sayfadaki maçları kapsar.
  int get cardsWonTotal => _gecmis.fold(0, (t, m) => t + m.cardsWon);

  int get cardsLostTotal => _gecmis.fold(0, (t, m) => t + m.cardsLost);

  /// Ekran açılırken çağrılır.
  Future<void> initialize() async {
    // Sayaçlar sessizce tazeleniyor: oturumda zaten bir değer var,
    // spinner göstermek ekranı gereksiz yere boşaltırdı.
    await _tazeleSayaclar();
    // Rütbe, geçmiş ve favoriler birbirini beklemesin
    await Future.wait([loadRank(), loadHistory(), loadFavorites()]);
  }

  Future<void> loadRank() async {
    final sonuc = await run(
      () => _leaderboardRepository.fetchMyRank(),
      showLoading: false,
    );
    if (sonuc != null) _rutbe = sonuc;
    safeNotify();
  }

  Future<void> _tazeleSayaclar() async {
    await run(() => _authRepository.fetchProfile(), showLoading: false);
    safeNotify();
  }

  Future<void> loadHistory() async {
    final liste = await run(
      () => _matchRepository.fetchMatchHistoryList(limit: 20),
    );

    if (liste != null) _gecmis = liste;
    safeNotify();
  }

  Future<void> loadFavorites() async {
    final repo = _collectionRepository;
    final depo = _favoriler;
    if (repo == null || depo == null) return;

    await depo.load();
    final kartlar = await run(() => repo.fetchInventory(), showLoading: false);
    if (kartlar == null) return;

    final gorulen = <String>{};
    final favoriler =
        kartlar
            .where((k) => depo.isFavorite(k.cardId))
            .where((k) => gorulen.add(k.cardId)) // aynı oyuncu bir kez
            .toList()
          ..sort((a, b) {
            final s = b.tier.rank.compareTo(a.tier.rank);
            return s != 0 ? s : b.power.compareTo(a.power);
          });

    _favoriKartlar = favoriler.take(maxFavoritesShown).toList();
    safeNotify();
  }

  Future<void> refresh() => initialize();
}
