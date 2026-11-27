/// EKONOMİ V2 (FAZ 4) — Battle Pass (sezon yolu) ve görev modelleri.
///
/// Sunucu cevabını olduğu gibi taşır; istemci hiçbir ödülü ya da XP'yi
/// kendisi hesaplamaz (yalnız gösterim için kademe ilerlemesi).
library;

DateTime? _tarih(Object? v) => v == null ? null : DateTime.tryParse(v.toString());
int _int(Object? v, [int varsayilan = 0]) => v is num ? v.toInt() : int.tryParse('$v') ?? varsayilan;

/// Bir kademenin bir yolundaki ödül
class SeasonReward {
  /// coins | chest | item | paid_gems
  final String type;
  final int amount;
  final String? chestType;
  final String? slug;
  final int qty;
  final String? name;
  final String? category;

  const SeasonReward({
    required this.type,
    this.amount = 0,
    this.chestType,
    this.slug,
    this.qty = 1,
    this.name,
    this.category,
  });

  factory SeasonReward.fromJson(Map<String, dynamic> j) => SeasonReward(
        type: j['type']?.toString() ?? 'coins',
        amount: _int(j['amount']),
        chestType: j['chest_type']?.toString(),
        slug: j['slug']?.toString(),
        qty: _int(j['qty'], 1),
        name: j['name']?.toString(),
        category: j['category']?.toString(),
      );

  bool get isCoins => type == 'coins';
  bool get isChest => type == 'chest';
  bool get isItem => type == 'item';

  /// 063: ücretli elmas (yalnız kozmetikte harcanır; güç vermez)
  bool get isPaidGems => type == 'paid_gems';
  bool get isCosmetic =>
      isItem &&
      const {'profile_frame', 'kit', 'card_skin', 'arena_skin', 'victory_anim', 'character_cosmetic', 'season_badge'}
          .contains(category);
}

class SeasonTier {
  final int tier;
  final SeasonReward free;
  final SeasonReward premium;
  final bool freeClaimed;
  final bool premiumClaimed;

  const SeasonTier({
    required this.tier,
    required this.free,
    required this.premium,
    this.freeClaimed = false,
    this.premiumClaimed = false,
  });

  factory SeasonTier.fromJson(Map<String, dynamic> j) => SeasonTier(
        tier: _int(j['tier']),
        free: SeasonReward.fromJson(Map<String, dynamic>.from(j['free'] as Map)),
        premium: SeasonReward.fromJson(Map<String, dynamic>.from(j['premium'] as Map)),
        freeClaimed: j['free_claimed'] == true,
        premiumClaimed: j['premium_claimed'] == true,
      );
}

class SeasonOverview {
  final bool enabled;
  final String? seasonId;
  final int number;
  final String name;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int xp;
  final int tier;
  final int xpPerTier;
  final int maxTier;
  final bool premium;
  final bool premiumPlus;
  final bool premiumPurchaseEnabled;
  final List<SeasonTier> tiers;
  final DateTime? serverTime;

  const SeasonOverview({
    required this.enabled,
    this.seasonId,
    this.number = 0,
    this.name = '',
    this.startsAt,
    this.endsAt,
    this.xp = 0,
    this.tier = 0,
    this.xpPerTier = 1000,
    this.maxTier = 50,
    this.premium = false,
    this.premiumPlus = false,
    this.premiumPurchaseEnabled = false,
    this.tiers = const [],
    this.serverTime,
  });

  factory SeasonOverview.fromJson(Map<String, dynamic> j) {
    final s = j['season'] is Map ? Map<String, dynamic>.from(j['season'] as Map) : const <String, dynamic>{};
    return SeasonOverview(
      enabled: j['enabled'] == true,
      seasonId: s['id']?.toString(),
      number: _int(s['number']),
      name: s['name']?.toString() ?? '',
      startsAt: _tarih(s['starts_at']),
      endsAt: _tarih(s['ends_at']),
      xp: _int(j['xp']),
      tier: _int(j['tier']),
      xpPerTier: _int(j['xp_per_tier'], 1000),
      maxTier: _int(j['max_tier'], 50),
      premium: j['premium'] == true,
      premiumPlus: j['premium_plus'] == true,
      premiumPurchaseEnabled: j['premium_purchase_enabled'] == true,
      tiers: [
        for (final t in (j['tiers'] as List? ?? const [])) SeasonTier.fromJson(Map<String, dynamic>.from(t as Map)),
      ],
      serverTime: _tarih(j['server_time']),
    );
  }

  bool get isMaxed => tier >= maxTier;

  /// Bulunulan kademede ilerleme (0..1)
  double get tierProgress => isMaxed ? 1 : (xp - tier * xpPerTier) / xpPerTier;

  /// Sonraki kademeye kalan XP
  int get xpToNext => isMaxed ? 0 : (tier + 1) * xpPerTier - xp;

  bool isReached(int t) => t <= tier;

  /// Şimdi alınabilecek ödül sayısı (premium kilitliyse yalnız ücretsiz yol)
  int get claimableCount => tiers.fold(
      0,
      (n, t) =>
          n +
          (isReached(t.tier) && !t.freeClaimed ? 1 : 0) +
          (premium && isReached(t.tier) && !t.premiumClaimed ? 1 : 0));

  /// Sezon bitimine kalan süre (sunucu saatine göre)
  Duration? remaining(DateTime now) => endsAt?.difference(now);
}

class Mission {
  final String slug;

  /// daily | weekly | season
  final String period;
  final String title;
  final String description;
  final int target;
  final int progress;
  final int xp;
  final bool completed;
  final DateTime? resetsAt;

  const Mission({
    required this.slug,
    required this.period,
    required this.title,
    this.description = '',
    required this.target,
    this.progress = 0,
    required this.xp,
    this.completed = false,
    this.resetsAt,
  });

  factory Mission.fromJson(Map<String, dynamic> j) => Mission(
        slug: j['slug']?.toString() ?? '',
        period: j['period']?.toString() ?? 'daily',
        title: j['title']?.toString() ?? '',
        description: j['description']?.toString() ?? '',
        target: _int(j['target'], 1),
        progress: _int(j['progress']),
        xp: _int(j['xp']),
        completed: j['completed'] == true,
        resetsAt: _tarih(j['resets_at']),
      );

  double get ratio => target <= 0 ? 0 : (progress / target).clamp(0, 1).toDouble();
}

class MissionsOverview {
  final bool enabled;
  final List<Mission> missions;
  final DateTime? serverTime;

  const MissionsOverview({required this.enabled, this.missions = const [], this.serverTime});

  factory MissionsOverview.fromJson(Map<String, dynamic> j) => MissionsOverview(
        enabled: j['enabled'] == true,
        missions: [
          for (final m in (j['missions'] as List? ?? const [])) Mission.fromJson(Map<String, dynamic>.from(m as Map)),
        ],
        serverTime: _tarih(j['server_time']),
      );

  List<Mission> period(String p) => missions.where((m) => m.period == p).toList();
}

/// Maç sonu: bu maçta kazanılan sezon XP'si
class MatchSeasonXp {
  final int xp;
  final bool noEnergy;
  const MatchSeasonXp({required this.xp, this.noEnergy = false});

  factory MatchSeasonXp.fromJson(Map<String, dynamic> j) =>
      MatchSeasonXp(xp: _int(j['xp']), noEnergy: j['no_energy'] == true);
}
