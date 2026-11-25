import 'package:shared_models/shared_models.dart';

import '../../core/network/api_client.dart';
import '../../core/l10n/app_language.dart';

/// 056 — sosyal, elmas ve rakip kadrosu uçları.
///
/// Modeller burada, sade sınıflar: alanlar sunucunun açık profil
/// sözleşmesiyle birebir (e-posta, altın, elmas, eşya YOK).
class SocialApi {
  final ApiClient api;
  SocialApi(this.api);

  Future<FriendLists> friends() async => FriendLists.fromJson(await api.get('/social/friends'));
  Future<String> request(String id) async => (await api.post('/social/friends/$id'))['friend_status'].toString();
  Future<String> accept(String id) async => (await api.post('/social/friends/$id/accept'))['friend_status'].toString();
  Future<String> decline(String id) async =>
      (await api.post('/social/friends/$id/decline'))['friend_status'].toString();
  Future<String> remove(String id) async => (await api.delete('/social/friends/$id'))['friend_status'].toString();

  Future<List<PlayerSummary>> search(String q) async {
    final r = await api.get('/social/search', sorgu: {'q': q});
    return [for (final p in r['players'] as List? ?? const []) PlayerSummary.fromJson(Map<String, dynamic>.from(p as Map))];
  }

  Future<PublicProfile> profile(String id) async => PublicProfile.fromJson(await api.get('/social/players/$id'));

  Future<GemStatus> gems() async => GemStatus.fromJson(await api.get('/gems'));

  Future<Map<String, dynamic>> exchange(String offer, {required String key}) =>
      api.postIdempotent('/gems/exchange', anahtar: key, govde: {'offer': offer});

  Future<ChestOpenResult> openChestWithGems(String chestId, int expectedCost, {required String key}) async =>
      ChestOpenResult.fromJson(
        await api.postIdempotent('/chests/$chestId/open-gems', anahtar: key, govde: {'expected_cost': expectedCost}),
      );

  Future<OpponentSquad> opponentSquad(String matchId) async =>
      OpponentSquad.fromJson(await api.get('/match/$matchId/opponent-squad'));
}

int _i(Object? v, [int d = 0]) => v is num ? v.toInt() : int.tryParse('$v') ?? d;
DateTime? _t(Object? v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

/// Arkadaşlık durumu (sunucudaki _friend_status)
enum FriendStatus {
  self,
  friends,
  incoming,
  outgoing,
  none;

  static FriendStatus parse(Object? v) =>
      FriendStatus.values.firstWhere((e) => e.name == v?.toString(), orElse: () => FriendStatus.none);
}

/// Liste satırı: arkadaş / istek / arama sonucu
class PlayerSummary {
  final String id;
  final String username;
  final int mmr;
  final int wins;
  final int losses;
  final int draws;
  final bool online;
  final DateTime? lastSeenAt;
  final FriendStatus friendStatus;

  const PlayerSummary({
    required this.id,
    required this.username,
    this.mmr = 1000,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.online = false,
    this.lastSeenAt,
    this.friendStatus = FriendStatus.none,
  });

  factory PlayerSummary.fromJson(Map<String, dynamic> j) => PlayerSummary(
    id: j['id'].toString(),
    username: j['username']?.toString() ?? 'Oyuncu'.tr,
    mmr: _i(j['mmr'], 1000),
    wins: _i(j['wins']),
    losses: _i(j['losses']),
    draws: _i(j['draws']),
    online: j['online'] == true,
    lastSeenAt: _t(j['last_seen_at']),
    friendStatus: FriendStatus.parse(j['friend_status']),
  );

  PlayerSummary withStatus(FriendStatus s) => PlayerSummary(
    id: id,
    username: username,
    mmr: mmr,
    wins: wins,
    losses: losses,
    draws: draws,
    online: online,
    lastSeenAt: lastSeenAt,
    friendStatus: s,
  );
}

class FriendLists {
  final List<PlayerSummary> friends;
  final List<PlayerSummary> incoming;
  final List<PlayerSummary> outgoing;
  const FriendLists({this.friends = const [], this.incoming = const [], this.outgoing = const []});

  static List<PlayerSummary> _l(Object? v) => [
    for (final p in v as List? ?? const []) PlayerSummary.fromJson(Map<String, dynamic>.from(p as Map)),
  ];

  factory FriendLists.fromJson(Map<String, dynamic> j) =>
      FriendLists(friends: _l(j['friends']), incoming: _l(j['incoming']), outgoing: _l(j['outgoing']));
}

/// Profilde ve rakip kadrosunda gösterilen kart
class ShownCard {
  final String cardId;

  /// Katalogdaki değişmeyen kimlik (kart görseli); eski sunucuda yok
  final String? slug;
  final String fullName;
  final CardPosition position;
  final CardTier tier;
  final int power;
  final bool played;
  const ShownCard({
    required this.cardId,
    this.slug,
    required this.fullName,
    required this.position,
    required this.tier,
    required this.power,
    this.played = false,
  });

  factory ShownCard.fromJson(Map<String, dynamic> j) => ShownCard(
    cardId: j['card_id'].toString(),
    slug: j['slug']?.toString(),
    fullName: j['full_name']?.toString() ?? '',
    position: CardPosition.fromCode(j['position'].toString()),
    tier: CardTier.fromCode(j['tier'].toString()),
    power: _i(j['power']),
    played: j['played'] == true,
  );
}

class HeadToHead {
  final int matches;
  final int myWins;
  final int theirWins;
  final int draws;
  const HeadToHead({this.matches = 0, this.myWins = 0, this.theirWins = 0, this.draws = 0});
  factory HeadToHead.fromJson(Map<String, dynamic>? j) => j == null
      ? const HeadToHead()
      : HeadToHead(
          matches: _i(j['matches']),
          myWins: _i(j['my_wins']),
          theirWins: _i(j['their_wins']),
          draws: _i(j['draws']),
        );
}

/// Açık profil (herkes görebilir)
class PublicProfile {
  final String id;
  final String username;
  final int mmr;
  final int wins;
  final int losses;
  final int draws;
  final PlayerRank? rank;
  final DateTime? joinedAt;
  final bool online;
  final DateTime? lastSeenAt;
  final FriendStatus friendStatus;
  final int friendCount;
  final int collectionCount;
  final String? frame;
  final String? badge;
  final List<ShownCard> topCards;

  /// 'win' | 'loss' | 'draw', en yeni önce (en fazla 5)
  final List<String> recentForm;
  final HeadToHead headToHead;

  const PublicProfile({
    required this.id,
    required this.username,
    this.mmr = 1000,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.rank,
    this.joinedAt,
    this.online = false,
    this.lastSeenAt,
    this.friendStatus = FriendStatus.none,
    this.friendCount = 0,
    this.collectionCount = 0,
    this.frame,
    this.badge,
    this.topCards = const [],
    this.recentForm = const [],
    this.headToHead = const HeadToHead(),
  });

  int get totalMatches => wins + losses + draws;
  double get winRate => totalMatches == 0 ? 0 : wins / totalMatches;

  factory PublicProfile.fromJson(Map<String, dynamic> j) {
    final eq = j['equipped'] is Map ? Map<String, dynamic>.from(j['equipped'] as Map) : const <String, dynamic>{};
    PlayerRank? rank;
    try {
      if (j['rank'] is Map) rank = PlayerRank.fromJson(Map<String, dynamic>.from(j['rank'] as Map));
    } catch (_) {
      rank = null;
    }
    return PublicProfile(
      id: j['id'].toString(),
      username: j['username']?.toString() ?? 'Oyuncu'.tr,
      mmr: _i(j['mmr'], 1000),
      wins: _i(j['wins']),
      losses: _i(j['losses']),
      draws: _i(j['draws']),
      rank: rank,
      joinedAt: _t(j['joined_at']),
      online: j['online'] == true,
      lastSeenAt: _t(j['last_seen_at']),
      friendStatus: FriendStatus.parse(j['friend_status']),
      friendCount: _i(j['friend_count']),
      collectionCount: _i(j['collection_count']),
      frame: eq['frame']?.toString(),
      badge: eq['badge']?.toString(),
      topCards: [
        for (final c in j['top_cards'] as List? ?? const []) ShownCard.fromJson(Map<String, dynamic>.from(c as Map)),
      ],
      recentForm: [for (final f in j['recent_form'] as List? ?? const []) f.toString()],
      headToHead: HeadToHead.fromJson(j['head_to_head'] is Map ? Map<String, dynamic>.from(j['head_to_head'] as Map) : null),
    );
  }

  PublicProfile withStatus(FriendStatus s) => PublicProfile(
    id: id,
    username: username,
    mmr: mmr,
    wins: wins,
    losses: losses,
    draws: draws,
    rank: rank,
    joinedAt: joinedAt,
    online: online,
    lastSeenAt: lastSeenAt,
    friendStatus: s,
    friendCount: friendCount + (s == FriendStatus.friends ? 1 : 0) - (friendStatus == FriendStatus.friends ? 1 : 0),
    collectionCount: collectionCount,
    frame: frame,
    badge: badge,
    topCards: topCards,
    recentForm: recentForm,
    headToHead: headToHead,
  );
}

class GemOffer {
  final String slug;
  final int gems;
  final int coins;
  const GemOffer({required this.slug, required this.gems, required this.coins});
  factory GemOffer.fromJson(Map<String, dynamic> j) =>
      GemOffer(slug: j['slug'].toString(), gems: _i(j['gems']), coins: _i(j['coins']));
}

class GemStatus {
  final int gems;
  final List<GemOffer> exchange;

  /// Yuvadaki sandık kimliği → hemen açma bedeli
  final Map<String, int> openCosts;
  final int openSecondsPerGem;
  const GemStatus({required this.gems, this.exchange = const [], this.openCosts = const {}, this.openSecondsPerGem = 600});

  factory GemStatus.fromJson(Map<String, dynamic> j) => GemStatus(
    gems: _i(j['gems']),
    exchange: [for (final o in j['exchange'] as List? ?? const []) GemOffer.fromJson(Map<String, dynamic>.from(o as Map))],
    openCosts: {
      for (final e in (j['open_costs'] is Map ? (j['open_costs'] as Map).entries : const <MapEntry>[]))
        e.key.toString(): _i(e.value),
    },
    openSecondsPerGem: _i(j['open_seconds_per_gem'], 600),
  );

  /// Sunucuyla aynı formül: kalan her [openSecondsPerGem] saniye 1 elmas, en az 1
  static int costFor(int remainingSeconds, {int secondsPerGem = 600}) =>
      remainingSeconds <= 0 ? 1 : ((remainingSeconds + secondsPerGem - 1) ~/ secondsPerGem).clamp(1, 1 << 30);
}

class OpponentSquad {
  final String matchId;
  final String opponentId;
  final String opponentUsername;
  final int opponentMmr;
  final String outcome;
  final List<ShownCard> cards;
  const OpponentSquad({
    required this.matchId,
    required this.opponentId,
    required this.opponentUsername,
    this.opponentMmr = 1000,
    this.outcome = 'draw',
    this.cards = const [],
  });

  factory OpponentSquad.fromJson(Map<String, dynamic> j) {
    final o = j['opponent'] is Map ? Map<String, dynamic>.from(j['opponent'] as Map) : const <String, dynamic>{};
    return OpponentSquad(
      matchId: j['match_id'].toString(),
      opponentId: o['id']?.toString() ?? '',
      opponentUsername: o['username']?.toString() ?? 'Rakip'.tr,
      opponentMmr: _i(o['mmr'], 1000),
      outcome: j['outcome']?.toString() ?? 'draw',
      cards: [for (final c in j['cards'] as List? ?? const []) ShownCard.fromJson(Map<String, dynamic>.from(c as Map))],
    );
  }

  List<ShownCard> byPosition(CardPosition p) => cards.where((c) => c.position == p).toList();

  /// Ortalama güç (kart yoksa 0)
  int get averagePower => cards.isEmpty ? 0 : (cards.fold<int>(0, (t, c) => t + c.power) / cards.length).round();
}

/// Son görülme metni: "Çevrimiçi", "5 dk önce", "3 sa önce", "2 gün önce"
String lastSeenText(bool online, DateTime? at, {DateTime? now}) {
  if (online) return 'Çevrimiçi'.tr;
  if (at == null) return 'Uzun süredir yok'.tr;
  final d = (now ?? DateTime.now()).difference(at);
  if (d.inMinutes < 60) return '{p} dk önce'.trArgs({'p': d.inMinutes.clamp(1, 59)});
  if (d.inHours < 24) return '{inHours} sa önce'.trArgs({'inHours': d.inHours});
  if (d.inDays < 30) return '{inDays} gün önce'.trArgs({'inDays': d.inDays});
  return 'Uzun süredir yok'.tr;
}
