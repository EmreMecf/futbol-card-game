import 'package:shared_models/shared_models.dart';

import '../../../../core/base/base_view_model.dart';
import '../../../../core/base/view_state.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/result.dart';
import '../../domain/season_repository.dart';

/// SEZON YOLU (Ekonomi V2, FAZ 4). Ödül alma her eylemde bir idempotency
/// anahtarı taşır; ağ hatasında aynı eylem aynı anahtarla tekrar denenir,
/// kural reddinde (ör. kademe kilitli) anahtar bırakılır.
class SeasonViewModel extends BaseViewModel {
  final SeasonRepository _repository;
  SeasonViewModel(this._repository);

  SeasonOverview? _sezon;
  SeasonOverview? get overview => _sezon;

  MissionsOverview? _gorevler;
  MissionsOverview? get missions => _gorevler;

  /// İşlenen eylem: "free:3", "premium:1" ya da "all"
  String? _islenen;
  String? get busyAction => _islenen;
  bool isClaiming(int tier, String track) => _islenen == '$track:$tier' || _islenen == 'all';

  String? _hata;
  String? get actionError => _hata;

  String? _bilgi;
  String? get lastInfo => _bilgi;

  final Map<String, String> _anahtarlar = {};

  Future<void> load() async {
    final s = await run(() => _repository.fetchOverview(), loadingState: ViewState.loading);
    if (s != null) _sezon = s;
    _gorevler = (await _repository.fetchMissions()).dataOrNull ?? _gorevler;
    safeNotify();
  }

  Future<void> _tazele() async {
    _sezon = (await _repository.fetchOverview()).dataOrNull ?? _sezon;
    _gorevler = (await _repository.fetchMissions()).dataOrNull ?? _gorevler;
  }

  bool canClaim(SeasonTier t, String track) {
    final s = _sezon;
    if (s == null || !s.isReached(t.tier)) return false;
    return track == 'free' ? !t.freeClaimed : s.premium && !t.premiumClaimed;
  }

  Future<bool> claim(SeasonTier t, String track) =>
      _eylem('$track:${t.tier}', 'claim:${t.tier}:$track', (k) => _repository.claim(t.tier, track, idempotencyKey: k),
          (sonuc) => _bilgi = '${t.tier}. kademe ödülü alındı: ${rewardLabel(track == 'free' ? t.free : t.premium)}.');

  Future<bool> claimAll() {
    final s = _sezon;
    return _eylem('all', 'all:${s?.xp}:${s?.claimableCount}', (k) => _repository.claimAll(idempotencyKey: k), (sonuc) {
      final n = (sonuc['count'] as num?)?.toInt() ?? 0;
      _bilgi = n == 0 ? 'Alınacak ödül yok.' : '$n ödül alındı.';
    });
  }

  Future<bool> _eylem(String islem, String eylem, Future<Result<Map<String, dynamic>>> Function(String) is_,
      void Function(Map<String, dynamic>) ok) async {
    if (_islenen != null) return false;
    final anahtar = _anahtarlar.putIfAbsent(eylem, ApiClient.newIdempotencyKey);
    _islenen = islem;
    _hata = null;
    _bilgi = null;
    safeNotify();
    final s = await is_(anahtar);
    _islenen = null;
    final hata = s.errorOrNull;
    if (hata != null) {
      if (hata.type != AppErrorType.network) _anahtarlar.remove(eylem);
      _hata = seasonErrorMessage(hata.technicalDetail, hata.message);
      safeNotify();
      return false;
    }
    _anahtarlar.remove(eylem);
    ok(s.dataOrNull ?? const {});
    await _tazele();
    safeNotify();
    return true;
  }
}

/// "93 altın", "Gümüş sandık", "Altın joker parça ×3"
String rewardLabel(SeasonReward r) {
  if (r.isCoins) return '${r.amount} altın';
  if (r.isChest) {
    final ad = switch (r.chestType) {
      'bronze' => 'Bronz',
      'silver' => 'Gümüş',
      'gold' => 'Altın',
      'legend' => 'Efsane',
      _ => r.chestType ?? '',
    };
    return '$ad sandık';
  }
  final ad = r.name ?? r.slug ?? 'Item';
  return r.qty > 1 ? '$ad ×${r.qty}' : ad;
}
