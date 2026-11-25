import 'dart:async';

import '../../core/auth/session_manager.dart';
import '../../core/base/base_view_model.dart';
import '../../core/base/view_state.dart';
import '../../core/error/app_exception.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/result.dart';
import 'social_api.dart';
import '../../core/l10n/app_language.dart';

/// Sosyal hata kodları → Türkçe
String socialErrorText(AppException e) => switch (e.technicalDetail) {
  'friend_self' => 'Kendine arkadaşlık isteği gönderemezsin.'.tr,
  'player_not_found' => 'Oyuncu bulunamadı.'.tr,
  'friend_limit' => 'En fazla 100 arkadaşın olabilir.'.tr,
  'friend_request_limit' => 'Bekleyen çok fazla isteğin var. Önce bazılarını geri çek.'.tr,
  'friend_request_not_found' => 'Bu istek artık geçerli değil.'.tr,
  'match_not_found' => 'Maç bulunamadı.'.tr,
  'match_not_finished' => 'Rakibin kadrosu maç bitince görünür.'.tr,
  'not_enough_gems' => 'Yeterli elmas yok.'.tr,
  'offer_not_found' => 'Teklif bulunamadı.'.tr,
  'idempotency_in_progress' => 'İstek hâlâ işleniyor, birazdan tekrar dene.'.tr,
  _ => e.message,
};

/// ARKADAŞLAR ekranı: liste, gelen/giden istekler, oyuncu arama
class FriendsViewModel extends BaseViewModel {
  final SocialApi _api;
  FriendsViewModel(this._api);

  FriendLists _listeler = const FriendLists();
  FriendLists get lists => _listeler;
  bool _yuklendi = false;
  bool get loaded => _yuklendi;

  String _arama = '';
  String get query => _arama;
  List<PlayerSummary> _sonuclar = const [];
  List<PlayerSummary> get results => _sonuclar;
  bool _araniyor = false;
  bool get searching => _araniyor;

  final Set<String> _islenen = {};
  bool isWorking(String id) => _islenen.contains(id);

  String? _hata;
  String? get actionError => _hata;
  String? _bilgi;
  String? get info => _bilgi;

  Timer? _gecikme;
  int _aramaNo = 0;

  Future<void> load() async {
    final l = await run(() => Result.guard(_api.friends), loadingState: ViewState.loading);
    if (l != null) {
      _listeler = l;
      _yuklendi = true;
    }
    safeNotify();
  }

  Future<void> refresh() async {
    final l = (await Result.guard(_api.friends)).dataOrNull;
    if (l != null) _listeler = l;
    safeNotify();
  }

  /// Yazarken arar (300 ms bekleyip son yazılanı); 2 harften kısa boş
  void setQuery(String q) {
    _arama = q.trim();
    _gecikme?.cancel();
    if (_arama.length < 2) {
      _sonuclar = const [];
      _araniyor = false;
      safeNotify();
      return;
    }
    _araniyor = true;
    safeNotify();
    _gecikme = Timer(const Duration(milliseconds: 300), search);
  }

  Future<void> search() async {
    final no = ++_aramaNo;
    final q = _arama;
    if (q.length < 2) return;
    final s = await Result.guard(() => _api.search(q));
    if (no != _aramaNo) return; // daha yeni bir arama var
    _araniyor = false;
    _sonuclar = s.dataOrNull ?? const [];
    final h = s.errorOrNull;
    _hata = h == null ? null : socialErrorText(h);
    safeNotify();
  }

  Future<void> _eylem(String id, Future<String> Function() is_, String basari) async {
    if (_islenen.contains(id)) return;
    _islenen.add(id);
    _hata = null;
    _bilgi = null;
    safeNotify();
    final s = await Result.guard(is_);
    _islenen.remove(id);
    final h = s.errorOrNull;
    if (h != null) {
      _hata = socialErrorText(h);
    } else {
      final durum = FriendStatus.parse(s.dataOrNull);
      _sonuclar = [for (final p in _sonuclar) p.id == id ? p.withStatus(durum) : p];
      _bilgi = durum == FriendStatus.friends ? 'Artık arkadaşsınız!'.tr : basari;
      await refresh();
    }
    safeNotify();
  }

  Future<void> sendRequest(PlayerSummary p) => _eylem(p.id, () => _api.request(p.id), 'İstek gönderildi: {username}'.trArgs({'username': p.username}));
  Future<void> accept(PlayerSummary p) => _eylem(p.id, () => _api.accept(p.id), 'Artık arkadaşsınız!'.tr);
  Future<void> decline(PlayerSummary p) => _eylem(p.id, () => _api.decline(p.id), 'İstek reddedildi.'.tr);
  Future<void> remove(PlayerSummary p) => _eylem(p.id, () => _api.remove(p.id), '{username} listeden çıkarıldı.'.trArgs({'username': p.username}));

  @override
  void dispose() {
    _gecikme?.cancel();
    super.dispose();
  }
}

/// Başka bir oyuncunun açık profili
class PlayerProfileViewModel extends BaseViewModel {
  final SocialApi _api;
  final String playerId;
  final SessionManager? _session;
  PlayerProfileViewModel(this._api, this.playerId, {SessionManager? session})
    // ignore: prefer_initializing_formals
    : _session = session;

  PublicProfile? _profil;
  PublicProfile? get profile => _profil;

  bool get isSelf => _session?.user?.id == playerId || _profil?.friendStatus == FriendStatus.self;

  bool _calisiyor = false;
  bool get acting => _calisiyor;
  String? _hata;
  String? get actionError => _hata;

  Future<void> load() async {
    final p = await run(() => Result.guard(() => _api.profile(playerId)), loadingState: ViewState.loading);
    if (p != null) _profil = p;
    safeNotify();
  }

  Future<void> _eylem(Future<String> Function() is_) async {
    final p = _profil;
    if (p == null || _calisiyor) return;
    _calisiyor = true;
    _hata = null;
    safeNotify();
    final s = await Result.guard(is_);
    _calisiyor = false;
    final h = s.errorOrNull;
    if (h != null) {
      _hata = socialErrorText(h);
    } else {
      _profil = p.withStatus(FriendStatus.parse(s.dataOrNull));
    }
    safeNotify();
  }

  Future<void> addFriend() => _eylem(() => _api.request(playerId));
  Future<void> accept() => _eylem(() => _api.accept(playerId));
  Future<void> decline() => _eylem(() => _api.decline(playerId));
  Future<void> removeFriend() => _eylem(() => _api.remove(playerId));
}

/// Bitmiş maçta rakibin kadrosu
class OpponentSquadViewModel extends BaseViewModel {
  final SocialApi _api;
  final String matchId;
  OpponentSquadViewModel(this._api, this.matchId);

  OpponentSquad? _kadro;
  OpponentSquad? get squad => _kadro;
  String? get errorText => error == null ? null : socialErrorText(error!);

  Future<void> load() async {
    final k = await run(() => Result.guard(() => _api.opponentSquad(matchId)), loadingState: ViewState.loading);
    if (k != null) _kadro = k;
    safeNotify();
  }
}

/// Mağazadaki elmas bölümü: elmasla altın
class GemStoreViewModel extends BaseViewModel {
  final SocialApi _api;
  final SessionManager? _session;
  GemStoreViewModel(this._api, {SessionManager? session})
    // ignore: prefer_initializing_formals
    : _session = session;

  GemStatus? _durum;
  GemStatus? get status => _durum;
  int get gems => _durum?.gems ?? _session?.user?.gems ?? 0;

  String? _islenen;
  String? get busyOffer => _islenen;
  String? _hata;
  String? get actionError => _hata;
  String? _bilgi;
  String? get info => _bilgi;

  final Map<String, String> _anahtarlar = {};

  Future<void> load() async {
    final d = await run(() => Result.guard(_api.gems), showLoading: false);
    if (d != null) {
      _durum = d;
      await _oturum(gems: d.gems);
    }
    safeNotify();
  }

  bool canBuy(GemOffer o) => gems >= o.gems;

  Future<bool> buy(GemOffer o) async {
    if (_islenen != null) return false;
    if (!canBuy(o)) {
      _hata = 'Yeterli elmas yok ({gems} gerekli).'.trArgs({'gems': o.gems});
      safeNotify();
      return false;
    }
    _islenen = o.slug;
    _hata = null;
    _bilgi = null;
    safeNotify();
    final eylem = 'ex:${o.slug}:$gems';
    final anahtar = _anahtarlar.putIfAbsent(eylem, ApiClient.newIdempotencyKey);
    final s = await Result.guard(() => _api.exchange(o.slug, key: anahtar));
    _islenen = null;
    final h = s.errorOrNull;
    if (h != null) {
      if (h.type != AppErrorType.network) _anahtarlar.remove(eylem);
      _hata = socialErrorText(h);
      safeNotify();
      return false;
    }
    _anahtarlar.remove(eylem);
    final r = s.dataOrNull!;
    final yeniElmas = (r['gems_after'] as num?)?.toInt();
    final yeniAltin = (r['coins_after'] as num?)?.toInt();
    if (_durum != null && yeniElmas != null) {
      _durum = GemStatus(
        gems: yeniElmas,
        exchange: _durum!.exchange,
        openCosts: _durum!.openCosts,
        openSecondsPerGem: _durum!.openSecondsPerGem,
      );
    }
    await _oturum(gems: yeniElmas, coins: yeniAltin);
    _bilgi = '+{coins} altın hesabına eklendi.'.trArgs({'coins': o.coins});
    safeNotify();
    return true;
  }

  Future<void> _oturum({int? gems, int? coins}) async {
    final u = _session?.user;
    if (u == null) return;
    if ((gems == null || gems == u.gems) && (coins == null || coins == u.coins)) return;
    await _session!.updateUser(u.copyWith(gems: gems ?? u.gems, coins: coins ?? u.coins));
  }
}
