import 'package:shared_models/shared_models.dart';

import '../../../../core/auth/session_manager.dart';
import '../../../../core/base/base_view_model.dart';
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

  ProfileViewModel(
    this._matchRepository,
    this._authRepository,
    this._leaderboardRepository,
    this._session,
  );

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
    // Rütbe ve geçmiş birbirini beklemesin
    await Future.wait([loadRank(), loadHistory()]);
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
    await run(
      () => _authRepository.fetchProfile(),
      showLoading: false,
    );
    safeNotify();
  }

  Future<void> loadHistory() async {
    final liste = await run(
      () => _matchRepository.fetchMatchHistoryList(limit: 20),
    );

    if (liste != null) _gecmis = liste;
    safeNotify();
  }

  Future<void> refresh() => initialize();
}
