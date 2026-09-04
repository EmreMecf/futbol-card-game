import 'package:shared_models/shared_models.dart';

import '../../../../core/auth/session_manager.dart';
import '../../../../core/base/base_view_model.dart';
import '../../domain/repositories/leaderboard_repository.dart';

/// Liderlik tablosu ekranının verisi.
class LeaderboardViewModel extends BaseViewModel {
  final LeaderboardRepository _repository;
  final SessionManager _session;

  LeaderboardViewModel(this._repository, this._session);

  /// Bir sayfada kaç oyuncu gösteriliyor
  static const int sayfaBoyutu = 50;

  Leaderboard _tablo = const Leaderboard();
  Leaderboard get leaderboard => _tablo;

  PlayerRank? _rutbe;
  PlayerRank? get myRank => _rutbe;

  String? get myUserId => _session.userId;

  List<LeaderboardEntry> get entries => _tablo.entries;

  /// Oyuncunun kendi sırası. Listede olmasa bile dolu gelir.
  int? get myPosition => _tablo.myPosition;

  /// Oyuncu gösterilen listenin içinde mi?
  ///
  /// Değilse ekran altta ayrı bir "sen buradasın" satırı çiziyor;
  /// oyuncu 340. sırada da olsa kendini görebiliyor.
  bool get amIInList => _tablo.amIInList;

  /// Listede benim satırım (varsa)
  LeaderboardEntry? get myEntry {
    final id = myUserId;
    if (id == null) return null;
    for (final e in _tablo.entries) {
      if (e.userId == id) return e;
    }
    return null;
  }

  Future<void> initialize() async {
    // İki istek paralel: rütbe rozeti ve liste birbirini beklemesin.
    await Future.wait([loadRank(), loadLeaderboard()]);
  }

  Future<void> loadRank() async {
    final sonuc = await run(
      () => _repository.fetchMyRank(),
      // Rütbe rozeti listeden bağımsız; onun yüklenmesi listeyi
      // spinner'a çevirmemeli.
      showLoading: false,
    );
    if (sonuc != null) _rutbe = sonuc;
    safeNotify();
  }

  Future<void> loadLeaderboard() async {
    final sonuc = await run(
      () => _repository.fetchLeaderboard(limit: sayfaBoyutu),
    );
    if (sonuc != null) _tablo = sonuc;
    safeNotify();
  }

  Future<void> refresh() => initialize();
}
