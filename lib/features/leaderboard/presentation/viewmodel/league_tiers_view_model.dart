import 'package:shared_models/shared_models.dart';

import '../../../../core/base/base_view_model.dart';
import '../../domain/repositories/leaderboard_repository.dart';

/// "Ligler" tanıtım ekranının verisi.
///
/// Bütün basamakları ve oyuncunun şu an nerede olduğunu gösteriyor.
/// Oyuncu "kaç lig var, sıradaki ne, en tepede ne var" sorularının
/// cevabını tek ekranda görüyor.
class LeagueTiersViewModel extends BaseViewModel {
  final LeaderboardRepository _repository;

  LeagueTiersViewModel(this._repository, {Future<TrophyRoad?> Function()? trophyRoad})
      // ignore: prefer_initializing_formals
      : _kupaYoluSor = trophyRoad;

  /// 043: kupa yolu (kayıt yoksa ya da anahtar kapalıysa gösterilmez)
  final Future<TrophyRoad?> Function()? _kupaYoluSor;
  TrophyRoad? _kupaYolu;
  TrophyRoad? get trophyRoad => (_kupaYolu?.enabled ?? false) ? _kupaYolu : null;

  /// Bir basamağın kupa yolu bilgisi (yoksa null)
  TrophyRoadTier? trophyTier(int tierId) =>
      trophyRoad?.tiers.where((t) => t.tierId == tierId).firstOrNull;

  List<LeagueTier> _basamaklar = const [];
  List<LeagueTier> get tiers => _basamaklar;

  /// Lige göre gruplanmış hali. Arayüz "Amatör" başlığı altında üç
  /// kart çiziyor.
  List<LeagueGroup> get groups => LeagueGroup.fromTiers(_basamaklar);

  PlayerRank? _rutbe;
  PlayerRank? get myRank => _rutbe;

  /// Oyuncunun şu an bulunduğu basamağın numarası.
  /// Liste o basamağı vurguluyor.
  int? get myTierId => _rutbe?.tierId;

  Future<void> initialize() async {
    // Basamak listesi asıl içerik; rütbe sadece vurgu için.
    // Rütbe gelmese de liste gösterilebilmeli.
    await Future.wait([loadTiers(), loadRank(), loadTrophyRoad()]);
  }

  Future<void> loadTrophyRoad() async {
    final sor = _kupaYoluSor;
    if (sor == null) return;
    _kupaYolu = await sor();
    safeNotify();
  }

  Future<void> loadTiers() async {
    final sonuc = await run(() => _repository.fetchTiers());
    if (sonuc != null) _basamaklar = sonuc;
    safeNotify();
  }

  Future<void> loadRank() async {
    final sonuc = await run(
      () => _repository.fetchMyRank(),
      showLoading: false,
    );
    if (sonuc != null) _rutbe = sonuc;
    safeNotify();
  }

  Future<void> refresh() => initialize();
}
