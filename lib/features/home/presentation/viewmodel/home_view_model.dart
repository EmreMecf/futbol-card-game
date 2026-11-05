import 'package:shared_models/shared_models.dart';

import '../../../../core/base/base_view_model.dart';
import '../../../leaderboard/domain/repositories/leaderboard_repository.dart';
import '../../../match/domain/repositories/match_repository.dart';

/// Ana sayfanın verisi — TAMAMI SUNUCUDAN.
///
/// ===================================================================
/// NE VAR, NE YOK?
/// ===================================================================
/// GERÇEK (sunucudan):
///   * Lig basamağı ve bir sonraki basamağa ilerleme  (/api/leaderboard/rank)
///   * Son maçlar                                      (/api/match/history)
///   * Coin, puan, galibiyet sayıları                  (oturum)
///
/// YOK (sunucuda karşılığı olmadığı için uydurulmuyor):
///   * Günlük görevler
///   * Sezon yolu
///   Ana sayfada bu ikisi "Yakında" olarak açıkça işaretli. Sahte
///   "2/3 görev" göstermek oyuncuya yalan söylemek olurdu (MD kural 11).
///
/// ===================================================================
/// HATA DURUMU
/// ===================================================================
/// Lig ya da geçmiş yüklenemezse ana sayfa YİNE açılır; sadece o bölüm
/// eksik kalır. Oyuncunun "MAÇA BAŞLA"ya basabilmesi, lig rozetini
/// görmesinden önemli.
class HomeViewModel extends BaseViewModel {
  final LeaderboardRepository _leaderboardRepository;
  final MatchRepository _matchRepository;

  HomeViewModel(this._leaderboardRepository, this._matchRepository);

  /// Ana sayfada gösterilen son maç sayısı
  static const int recentMatchCount = 3;

  /// Galibiyet serisi hesaplanırken bakılan maç sayısı.
  /// Seri bundan uzunsa "10+" gibi gösterilir.
  static const int _seriPenceresi = 10;

  PlayerRank? _rutbe;
  PlayerRank? get rank => _rutbe;

  List<MatchHistoryEntry> _gecmis = const [];

  /// En yeniden eskiye son maçlar (en fazla [recentMatchCount])
  List<MatchHistoryEntry> get recentMatches =>
      _gecmis.take(recentMatchCount).toList();

  bool _yuklendi = false;

  /// İlk yükleme bitti mi? (iskelet yerine gerçek içerik göstermek için)
  bool get isLoaded => _yuklendi;

  /// Kesintisiz galibiyet serisi (en son maçtan geriye doğru).
  ///
  /// Sunucu geçmişi EN YENİDEN eskiye sıralı gönderiyor
  /// (`order by finished_at desc`). Beraberlik ya da mağlubiyet seriyi
  /// bitirir.
  int get winStreak {
    var seri = 0;
    for (final m in _gecmis) {
      if (m.outcome != MatchOutcome.win) break;
      seri++;
    }
    return seri;
  }

  /// Seri, pencerenin tamamı kadar mı? (ekranda "10+" yazmak için)
  bool get isStreakCapped =>
      _gecmis.length >= _seriPenceresi && winStreak == _seriPenceresi;

  /// Ekran açılınca ve aşağı çekip yenileyince.
  ///
  /// İki istek paralel: biri yavaşsa diğerini bekletmesin.
  Future<void> load() async {
    await Future.wait([_rutbeYukle(), _gecmisYukle()]);
    _yuklendi = true;
    safeNotify();
  }

  Future<void> _rutbeYukle() async {
    final sonuc = await run(
      () => _leaderboardRepository.fetchMyRank(),
      showLoading: false,
    );
    if (sonuc != null) _rutbe = sonuc;
  }

  Future<void> _gecmisYukle() async {
    final sonuc = await run(
      () => _matchRepository.fetchMatchHistoryList(limit: _seriPenceresi),
      showLoading: false,
    );
    if (sonuc != null) _gecmis = sonuc;
  }
}
