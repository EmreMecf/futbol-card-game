import 'package:futbol_card/core/auth/session_manager.dart';
import 'package:futbol_card/core/error/app_exception.dart';
import 'package:futbol_card/features/auth/domain/repositories/auth_repository.dart';
import 'package:futbol_card/features/sbc/domain/repositories/sbc_repository.dart';
import 'package:futbol_card/core/storage/token_storage.dart';
import 'package:futbol_card/core/utils/result.dart';
import 'package:futbol_card/features/chests/domain/chest_repository.dart';
import 'package:futbol_card/features/collection/domain/repositories/collection_repository.dart';
import 'package:futbol_card/features/deck/domain/repositories/deck_repository.dart';
import 'package:futbol_card/features/leaderboard/domain/repositories/leaderboard_repository.dart';
import 'package:futbol_card/core/network/websocket_service.dart';
import 'package:futbol_card/features/match/domain/repositories/match_repository.dart';
import 'package:futbol_card/features/matchmaking/domain/repositories/matchmaking_repository.dart';
import 'package:futbol_card/features/progress/domain/progress_repository.dart';
import 'package:futbol_card/features/store/domain/repositories/store_repository.dart';
import 'package:shared_models/shared_models.dart';

/// Golden testlerinin verisi.
///
/// Referans HTML'deki ÖRNEK kartlarla aynı ad/güç/nadirlik kullanılır ki
/// referans ekran ile Flutter ekranı yan yana karşılaştırılabilsin. Bu
/// veri SADECE testte; uygulama her zaman sunucu verisini gösterir.
const _referansKartlari = [
  ('Kuzey Yıldızı', CardPosition.forward, 96, CardTier.legend),
  ('Altın Golcü', CardPosition.forward, 91, CardTier.gold),
  ('Hız Ustası', CardPosition.forward, 94, CardTier.diamond),
  ('Oyun Kurucu', CardPosition.midfielder, 89, CardTier.gold),
  ('Demir Duvar', CardPosition.defender, 88, CardTier.gold),
  ('Usta Kaleci', CardPosition.goalkeeper, 93, CardTier.diamond),
  ('Hızlı Kanat', CardPosition.midfielder, 82, CardTier.silver),
  ('Genç Yetenek', CardPosition.forward, 78, CardTier.bronze),
  ('Efsane Kaptan', CardPosition.midfielder, 98, CardTier.legend),
  ('Sert Stoper', CardPosition.defender, 85, CardTier.silver),
  ('Saha Generali', CardPosition.midfielder, 86, CardTier.gold),
  ('Çelik Bek', CardPosition.defender, 84, CardTier.silver),
];

/// Referanstaki sırayla (koleksiyon güce göre sıralar; golden'da
/// referans sırasını korumak için güç sırası zaten benzer)
final List<InventoryCard> kGoldenCards = [
  for (var i = 0; i < _referansKartlari.length; i++)
    InventoryCard(
      userCardId: 'uc-$i',
      cardId: 'golden-${_referansKartlari[i].$1}',
      fullName: _referansKartlari[i].$1,
      position: _referansKartlari[i].$2,
      power: _referansKartlari[i].$3,
      tier: _referansKartlari[i].$4,
      club: ['Mavi Şimşek', 'Kızıl Fırtına', 'Liman Rüzgârı'][i % 3],
      attributes: CardAttributes(
        shooting: 60 + i * 2, pace: 70 + i, physical: 65 + i, defending: 50 + i * 3,
        dribbling: 72 + i, acceleration: 75 + i),
    ),
];

const kGoldenUser = UserModel(
  id: 'u1',
  username: 'testoyuncu',
  coins: 2450,
  mmr: 1825,
  wins: 24,
  losses: 9,
  draws: 2,
);

/// Gerçek basamaklarla tutarlı ([kGoldenTiers]): 1.825 puan = Master 2
const kGoldenRank = PlayerRank(
  mmr: 1825,
  tierId: 8,
  leagueCode: 'master',
  leagueName: 'Master',
  division: 2,
  color: '#F97316',
  tierMinMmr: 1750,
  nextTierMmr: 1875,
  nextLeagueName: 'Master',
  nextDivision: 3,
  progress: 0.6,
);

class GoldenCollectionRepo implements CollectionRepository {
  final List<InventoryCard> cards;
  GoldenCollectionRepo([List<InventoryCard>? c]) : cards = c ?? kGoldenCards;
  @override
  Future<Result<List<InventoryCard>>> fetchInventory() async => Success(cards);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// league_tiers tablosunun birebiri (yerel veritabanı)
const kGoldenTiers = [
  LeagueTier(tierId: 1, leagueCode: 'amateur', leagueName: 'Amatör', division: 1, minMmr: 1000, color: '#7C8DA6'),
  LeagueTier(tierId: 2, leagueCode: 'amateur', leagueName: 'Amatör', division: 2, minMmr: 1100, color: '#7C8DA6'),
  LeagueTier(tierId: 3, leagueCode: 'amateur', leagueName: 'Amatör', division: 3, minMmr: 1200, color: '#7C8DA6'),
  LeagueTier(tierId: 4, leagueCode: 'usta', leagueName: 'Usta', division: 1, minMmr: 1300, color: '#2DD4BF'),
  LeagueTier(tierId: 5, leagueCode: 'usta', leagueName: 'Usta', division: 2, minMmr: 1400, color: '#2DD4BF'),
  LeagueTier(tierId: 6, leagueCode: 'usta', leagueName: 'Usta', division: 3, minMmr: 1500, color: '#2DD4BF'),
  LeagueTier(tierId: 7, leagueCode: 'master', leagueName: 'Master', division: 1, minMmr: 1625, color: '#F97316'),
  LeagueTier(tierId: 8, leagueCode: 'master', leagueName: 'Master', division: 2, minMmr: 1750, color: '#F97316'),
  LeagueTier(tierId: 9, leagueCode: 'master', leagueName: 'Master', division: 3, minMmr: 1875, color: '#F97316'),
  LeagueTier(tierId: 10, leagueCode: 'master_class', leagueName: 'Master Class', division: 1, minMmr: 2025, color: '#F43F5E'),
  LeagueTier(tierId: 11, leagueCode: 'master_class', leagueName: 'Master Class', division: 2, minMmr: 2225, color: '#F43F5E'),
  LeagueTier(tierId: 12, leagueCode: 'master_class', leagueName: 'Master Class', division: 3, minMmr: 2475, color: '#F43F5E'),
];

/// Liderlik (referanstaki örnek adlarla, yalnız test verisi). Oyuncu 9. sırada,
/// gösterilen listenin dışında → altta kendi satırı.
final Leaderboard kGoldenLeaderboard = Leaderboard(
  entries: [
    for (final (i, ad, puan, lig, sev) in const [
      (1, 'ArenaMaster', 2510, 'Master Class', 3),
      (2, 'StormFC', 2260, 'Master Class', 2),
      (3, 'TaktikKralı', 2040, 'Master Class', 1),
      (4, 'KuzeyRüzgarı', 1990, 'Master', 3),
      (5, 'BeyazGelincik', 1920, 'Master', 3),
      (6, 'OrtaSahaUstası', 1880, 'Master', 3),
    ])
      LeaderboardEntry(
          rankPosition: i, userId: 'rakip-$i', username: ad, mmr: puan, leagueName: lig, division: sev, color: '#F43F5E'),
  ],
  myPosition: 9,
);

class GoldenLeaderboardRepo implements LeaderboardRepository {
  @override
  Future<Result<PlayerRank>> fetchMyRank() async => const Success(kGoldenRank);
  @override
  Future<Result<Leaderboard>> fetchLeaderboard({int limit = 50, int offset = 0}) async => Success(kGoldenLeaderboard);
  @override
  Future<Result<List<LeagueTier>>> fetchTiers() async => const Success(kGoldenTiers);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class GoldenMatchRepo implements MatchRepository {
  @override
  Future<Result<List<MatchHistoryEntry>>> fetchMatchHistoryList({int limit = 20, int offset = 0}) async => Success([
        // Sıra korunur: ilk 4 galibiyet (ana sayfadaki "4 galibiyet" serisi)
        for (final (i, ad, ben, o, sonuc) in const [
          (0, 'StormFC', 7, 4, MatchOutcome.win),
          (1, 'TaktikKralı', 6, 5, MatchOutcome.win),
          (2, 'KuzeyRüzgarı', 8, 3, MatchOutcome.win),
          (3, 'BeyazGelincik', 5, 4, MatchOutcome.win),
          (9, 'OrtaSahaUstası', 3, 6, MatchOutcome.loss),
        ])
          MatchHistoryEntry(
              matchId: 'm$i', opponentId: 'o$i', opponentUsername: ad, myScore: ben, opponentScore: o, outcome: sonuc),
      ]);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Referans kadro ekranındaki güçler (slot -> güç, mevki):
/// ST 91 88 · MID 85 89 86 84 · DEF 82 87 85 83 · GK 93
final Map<int, InventoryCard> kGoldenSquad = {
  for (final (slot, guc, mevki, kulup, uyruk) in const [
    (9, 91, CardPosition.forward, 'Mavi Şimşek', 'TUR'),
    (10, 88, CardPosition.forward, 'Mavi Şimşek', 'BRA'),
    (5, 85, CardPosition.midfielder, 'Kızıl Fırtına', 'TUR'),
    (6, 89, CardPosition.midfielder, 'Mavi Şimşek', 'TUR'),
    (7, 86, CardPosition.midfielder, 'Liman Rüzgârı', 'ESP'),
    (8, 84, CardPosition.midfielder, 'Kızıl Fırtına', 'ESP'),
    (1, 82, CardPosition.defender, 'Kızıl Fırtına', 'TUR'),
    (2, 87, CardPosition.defender, 'Liman Rüzgârı', 'ESP'),
    (3, 85, CardPosition.defender, 'Liman Rüzgârı', 'FRA'),
    (4, 83, CardPosition.defender, 'Kızıl Fırtına', 'FRA'),
    (0, 93, CardPosition.goalkeeper, 'Liman Rüzgârı', 'TUR'),
  ])
    slot: InventoryCard(
      userCardId: 'sq-$slot',
      cardId: 'golden-sq-$slot',
      fullName: 'Kadro Oyuncusu $slot',
      position: mevki,
      tier: guc >= 93 ? CardTier.diamond : CardTier.gold,
      power: guc,
      club: kulup,
      nationality: uyruk,
      league: 'Kurgu Ligi',
    ),
};

class GoldenDeckRepo implements DeckRepository {
  /// Kaydedilmiş kadro (null = boş kadro)
  final Map<int, InventoryCard> slots;
  GoldenDeckRepo([Map<int, InventoryCard>? s]) : slots = s ?? kGoldenSquad;

  @override
  Future<Result<List<DeckSummary>>> fetchDecks() async =>
      Success([DeckSummary(id: 'd1', name: 'Ana kadro', isActive: true, cardCount: slots.length)]);
  @override
  Future<Result<Map<int, InventoryCard>>> fetchDeckSlots(String deckId) async => Success(slots);
  @override
  Future<Result<List<InventoryCard>>> fetchDeckCards(String deckId) async => Success(slots.values.toList());
  @override
  Future<Result<DeckChemistry>> fetchChemistry(String deckId) async => const Success(DeckChemistry());
  @override
  Future<Result<List<InventoryCard>>> fetchInventory() async =>
      Success([...slots.values, ...kGoldenCards]);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Depo extends TokenStorage {
  Map<String, dynamic>? _k;
  @override
  Future<void> saveUser(Map<String, dynamic> user) async => _k = user;
  @override
  Future<Map<String, dynamic>?> readUser() async => _k;
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

Future<SessionManager> goldenSession() async {
  final s = SessionManager(_Depo());
  await s.updateUser(kGoldenUser);
  return s;
}

// ====================================================================
// FAZ 5: maç hazırlığı ve maç
// ====================================================================
class GoldenMatchmakingRepo implements MatchmakingRepository {
  @override
  Future<Result<String?>> activeMatchId() async => const Success(null);
  @override
  Future<Result<List<DeckSummary>>> fetchDecks() async =>
      const Success([DeckSummary(id: 'd1', name: 'Ana kadro', isActive: true, cardCount: 11)]);
  @override
  Future<Result<List<InventoryCard>>> fetchDeckCards(String deckId) async => Success(kGoldenSquad.values.toList());
  @override
  Future<Result<DeckValidation>> validateDeck(String deckId) async => const Success(DeckValidation(isValid: true));
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class GoldenSocket implements WebSocketService {
  @override
  Stream<bool> get connectionState => const Stream<bool>.empty();
  @override
  bool get isConnected => true;
  @override
  Stream<RealtimeEvent> get events => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

/// Maç kurgusu (match_layout_test ile aynı): 5. tur, sıra bende,
/// rakip Forvet açtı (Elmas 88 + 2 kimya, taktiği gizli), masada 2 kart,
/// skor 2-2, enerji 3/5, 31 sn.
class GoldenArenaRepo implements MatchRepository {
  @override
  Future<Result<MatchState>> fetchState(String m) async {
    final n = DateTime.now();
    return Success(MatchState(
      matchId: m,
      status: MatchStatus.active,
      roundNumber: 5,
      isMyTurn: true,
      requiredPosition: CardPosition.forward,
      serverTime: n,
      turnDeadline: n.add(const Duration(seconds: 31)),
      myScore: 2,
      opponentScore: 2,
      myCardsLeft: 7,
      opponentCardsLeft: 6,
      potCount: 2,
      myEnergy: 3,
      opponentEnergy: 4,
      opponent: const OpponentInfo(id: 'o', username: 'StormFC', mmr: 1640),
    ));
  }

  @override
  Future<Result<List<HandCard>>> fetchHand(String m) async => Success([
        for (final (id, p, t, g, ad, k) in const [
          ('1', CardPosition.forward, CardTier.gold, 84, 'Altın Golcü', 3),
          ('2', CardPosition.forward, CardTier.legend, 96, 'Kuzey Yıldızı', 4),
          ('3', CardPosition.midfielder, CardTier.legend, 98, 'Efsane Kaptan', 6),
          ('4', CardPosition.defender, CardTier.silver, 85, 'Sert Stoper', 2),
          ('5', CardPosition.goalkeeper, CardTier.diamond, 93, 'Usta Kaleci', 4),
          ('6', CardPosition.midfielder, CardTier.gold, 86, 'Saha Generali', 1),
          ('7', CardPosition.defender, CardTier.silver, 84, 'Çelik Bek', 0),
        ])
          HandCard(userCardId: id, cardId: 'golden-$ad', fullName: ad, position: p, tier: t, power: g, chemistry: k),
      ]);

  @override
  Future<Result<MatchHistory>> fetchHistory(String m) async => const Success(MatchHistory(moves: [
        MatchMove(
          roundNumber: 5,
          userId: 'o',
          isLead: true,
          position: CardPosition.forward,
          tier: CardTier.diamond,
          power: 88,
          chemistry: 2,
          fullName: 'Hız Ustası',
        ),
      ]));

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// ====================================================================
// FAZ 6: mağaza (fiyat ve oranlar yerel veritabanındaki pack_types'tan
// birebir: tier_weights / 10000)
// ====================================================================
List<TierOdds> _oranlar(Map<CardTier, int> m) =>
    [for (final e in m.entries.toList()..sort((a, b) => b.value.compareTo(a.value))) TierOdds(tier: e.key, weight: e.value)];

final List<PackType> kGoldenPacks = [
  PackType(
    slug: 'standard',
    name: 'Standart Paket',
    description: 'Legend çıkma ihtimali binde bir.',
    cardCount: 5,
    priceCoins: 500,
    sortOrder: 1,
    odds: _oranlar({
      CardTier.bronze: 5500, CardTier.silver: 3000, CardTier.gold: 1300, CardTier.diamond: 190, CardTier.legend: 10,
    }),
  ),
  PackType(
    slug: 'premium',
    name: 'Premium Paket',
    description: 'Belirgin şekilde daha yüksek ihtimaller. En az bir Altın.',
    cardCount: 5,
    priceCoins: 2500,
    sortOrder: 2,
    odds: _oranlar({
      CardTier.bronze: 2000, CardTier.silver: 3500, CardTier.gold: 3500, CardTier.diamond: 900, CardTier.legend: 100,
    }),
  ),
  PackType(
    slug: 'squad',
    name: 'Kadro Paketi',
    description: 'Tam bir 11 kişilik kadro: 1 kaleci, 4 defans, 4 orta saha, 2 forvet.',
    cardCount: 11,
    priceCoins: 4000,
    sortOrder: 3,
    positionQuota: const {'GK': 1, 'DEF': 4, 'MID': 4, 'FWD': 2},
    odds: _oranlar({
      CardTier.bronze: 4000, CardTier.silver: 3500, CardTier.gold: 2200, CardTier.diamond: 280, CardTier.legend: 20,
    }),
  ),
];

/// Premium paket açılışı (5 kart, biri Efsane)
final PackOpenResult kGoldenOpening = PackOpenResult(
  packSlug: 'premium',
  packName: 'Premium Paket',
  coinsSpent: 2500,
  coinsLeft: 0,
  cards: [kGoldenCards[8], kGoldenCards[2], kGoldenCards[3], kGoldenCards[6], kGoldenCards[7]],
);

class GoldenStoreRepo implements StoreRepository {
  @override
  Future<Result<List<PackType>>> fetchPacks() async => Success(kGoldenPacks);
  @override
  Future<Result<PackOpenResult>> openPack(String slug) async => Success(kGoldenOpening);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}


// ====================================================================
// FAZ 7: görevler (sbc_challenges tablosundaki tanımlar), profil
// ====================================================================
final List<SbcChallenge> kGoldenChallenges = [
  for (final j in [
    {'id': 'c1', 'slug': 'bronz-temizligi', 'name': 'Bronz Temizliği', 'category': 'baslangic',
     'description': '11 bronz kartı erit, altın kazan.',
     'requirements': [{'tier': 'bronze', 'type': 'max_tier'}], 'rewards': [{'type': 'coins', 'amount': 750}]},
    {'id': 'c2', 'slug': 'gumus-yukseltme', 'name': 'Gümüş Yükseltme', 'category': 'baslangic',
     'requirements': [{'tier': 'silver', 'type': 'exact_tier'}, {'type': 'min_chemistry', 'value': 12}],
     'rewards': [{'type': 'pack', 'pack_slug': 'standard'}], 'max_completions': 1, 'completed_count': 1, 'is_completed': true},
    {'id': 'c3', 'slug': 'uluslararasi-kadro', 'name': 'Uluslararası Kadro', 'category': 'genel',
     'requirements': [{'tier': 'silver', 'type': 'min_tier'}, {'type': 'min_distinct_nations', 'value': 6}, {'type': 'min_chemistry', 'value': 18}],
     'rewards': [{'type': 'pack', 'pack_slug': 'sbc_gold'}, {'type': 'coins', 'amount': 500}]},
  ])
    SbcChallenge.fromJson(j),
];

class GoldenSbcRepo implements SbcRepository {
  @override
  Future<Result<List<SbcChallenge>>> fetchChallenges() async => Success(kGoldenChallenges);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class GoldenAuthRepo implements AuthRepository {
  @override
  Future<Result<MeResponse>> fetchProfile() async => const Failure(AppException(message: 'test'));
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// =====================================================================
// EKONOMİ V2 (FAZ 1): SANDIKLAR — sahte veri (yalnız test)
// =====================================================================
/// Sabit sunucu saati: sayaçlar golden'da kararlı görünsün
final kGoldenServerTime = DateTime.utc(2026, 11, 10, 10);

Chest goldenChest(String id, String type,
        {String status = 'sealed', String location = 'slot', int? slot, Duration? kalan, int unlock = 7200}) =>
    Chest(
      id: id,
      chestType: type,
      status: status,
      location: location,
      slotNo: slot,
      sourceType: 'match',
      sourceId: 'mac-$id',
      unlockSeconds: unlock,
      unlockStartedAt: kalan == null ? null : kGoldenServerTime.subtract(const Duration(minutes: 30)),
      // +0,5 sn: ekran saniyeyi aşağı yuvarlar, test süresi sayacı oynatmaz
      unlockReadyAt: kalan == null ? null : kGoldenServerTime.add(kalan + const Duration(milliseconds: 500)),
      createdAt: kGoldenServerTime.subtract(const Duration(days: 2)),
    );

final kGoldenChestInventory = ChestInventory(
  slots: [
    goldenChest('s1', ChestTypes.silver, status: 'unlocking', slot: 1, kalan: const Duration(hours: 1, minutes: 23, seconds: 45)),
    goldenChest('s2', ChestTypes.gold, slot: 2, unlock: 21600),
    goldenChest('s4', ChestTypes.legend, slot: 4, unlock: 43200),
  ],
  instant: [goldenChest('i1', ChestTypes.bronze, status: 'ready', location: 'instant', unlock: 0)],
  mailbox: [goldenChest('m1', ChestTypes.gold, location: 'mailbox', unlock: 21600)],
  enabled: true,
  energy: RewardEnergy(energy: 7, max: 10, nextAt: kGoldenServerTime.add(const Duration(minutes: 41)), serverTime: kGoldenServerTime),
  serverTime: kGoldenServerTime,
);

ChestCard goldenChestCard(int i, String outcome) {
  final k = kGoldenCards[i];
  return ChestCard(
    cardId: k.cardId, slug: k.cardId, fullName: k.fullName, position: k.position, tier: k.tier,
    power: k.power, club: k.club, nationality: k.nationality, outcome: outcome);
}

final kGoldenChestOpen = ChestOpenResult(
  chestId: 'g1',
  chestType: ChestTypes.gold,
  cards: [goldenChestCard(7, 'new'), goldenChestCard(3, 'copy'), goldenChestCard(5, 'squad_guard')],
  coins: 104,
  jokers: const {'silver': 2, 'gold': 1},
  coinsAfter: 2554,
);

/// Sunucudaki sürüm 1 (031) ile aynı tablolar
final kGoldenChestOdds = ChestOdds.fromJson({
  'version': 1,
  'active_from': '2026-11-10T08:00:00.000Z',
  'types': {
    'bronze': {'name': 'Bronz', 'unlock_seconds': 0, 'coins': [10, 20], 'jokers': {'bronze': 1}, 'compensation': 25, 'sort': 1},
    'silver': {'name': 'Gümüş', 'unlock_seconds': 7200, 'coins': [30, 50], 'jokers': {'bronze': 2, 'silver': 1}, 'compensation': 70, 'sort': 2},
    'gold': {'name': 'Altın', 'unlock_seconds': 21600, 'coins': [80, 120], 'jokers': {'silver': 2, 'gold': 1}, 'compensation': 180, 'sort': 3},
    'legend': {'name': 'Efsane', 'unlock_seconds': 43200, 'coins': [200, 300], 'jokers': {'gold': 2, 'diamond': 1}, 'compensation': 450, 'sort': 4},
  },
  'type_odds': {
    'win': {'bronze': 520, 'silver': 350, 'gold': 110, 'legend': 20},
    'draw': {'bronze': 700, 'silver': 260, 'gold': 40},
    'loss': {'bronze': 800, 'silver': 180, 'gold': 20},
  },
  'slot_odds': {
    'bronze': [for (var i = 0; i < 3; i++) {'bronze': 720, 'silver': 240, 'gold': 40}],
    'silver': [
      {'bronze': 500, 'silver': 380, 'gold': 110, 'diamond': 10},
      {'bronze': 500, 'silver': 380, 'gold': 110, 'diamond': 10},
      {'silver': 700, 'gold': 260, 'diamond': 36, 'legend': 4},
    ],
    'gold': [
      {'bronze': 250, 'silver': 420, 'gold': 280, 'diamond': 45, 'legend': 5},
      {'bronze': 250, 'silver': 420, 'gold': 280, 'diamond': 45, 'legend': 5},
      {'gold': 820, 'diamond': 160, 'legend': 20},
    ],
    'legend': [
      {'silver': 300, 'gold': 520, 'diamond': 160, 'legend': 20},
      {'silver': 300, 'gold': 520, 'diamond': 160, 'legend': 20},
      {'diamond': 850, 'legend': 150},
    ],
  },
  'pity': {'gold_after': 15, 'legend_after': 60},
  'weight_total': 1000,
});

class GoldenChestRepo implements ChestRepository {
  ChestInventory inventory = kGoldenChestInventory;
  SourceChest matchChest = SourceChest(chest: goldenChest('mc', ChestTypes.silver, slot: 3));
  EmergencySquadStatus emergency = EmergencySquadStatus(
      enabled: true, missing: const {'MID': 1}, eligible: true, serverTime: kGoldenServerTime);

  @override
  Future<Result<ChestInventory>> fetchInventory() async => Success(inventory);
  @override
  Future<Result<ChestOdds>> fetchOdds({int? version}) async => Success(kGoldenChestOdds);
  @override
  Future<Result<SourceChest>> fetchMatchChest(String matchId) async => Success(matchChest);
  @override
  Future<Result<ChestOpenResult>> open(String chestId, {required String idempotencyKey}) async =>
      Success(kGoldenChestOpen);
  @override
  Future<Result<EmergencySquadStatus>> fetchEmergencySquad() async => Success(emergency);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// =====================================================================
// EKONOMİ V2 (FAZ 2): FUTBOLCU SEVİYESİ — sahte veri (yalnız test)
// =====================================================================
PlayerProgressItem goldenProgress(int i, {required int level, required int copies, LevelCost? next,
    int owned = 1, int convertible = 0, int jokers = 0}) {
  final k = kGoldenCards[i];
  return PlayerProgressItem(
    cardId: k.cardId, fullName: k.fullName, position: k.position, tier: k.tier, power: k.power,
    club: k.club, nationality: k.nationality, level: level, copies: copies, ownedCopies: owned,
    convertibleCopies: convertible, next: next, jokersAvailable: jokers);
}

final kGoldenProgress = ProgressOverview(
  items: [
    // Kopyayla hazır (Altın 3->4: 2 kopya, 250 altın)
    goldenProgress(1, level: 3, copies: 2, next: const LevelCost(copies: 2, coins: 250)),
    // Jokerle hazır (Elmas 4->5: 2 kopya, 900 altın; 1 kopya + 3 joker)
    goldenProgress(2, level: 4, copies: 1, next: const LevelCost(copies: 2, coins: 900), jokers: 3),
    // Ustalık eşiğini geçmiş (seviye 6)
    goldenProgress(0, level: 6, copies: 1, next: const LevelCost(copies: 3, coins: 4000)),
    // Kopya eksik + dönüştürülebilir fazla kopya
    goldenProgress(7, level: 1, copies: 0, next: const LevelCost(copies: 1, coins: 20), owned: 4, convertible: 2),
    // En yüksek seviye
    goldenProgress(9, level: 10, copies: 0),
  ],
  jokers: const {'bronze': 4, 'silver': 2, 'gold': 1, 'diamond': 3},
  coins: 2450,
  mastery: const {'5': {'coins': 200}, '10': {'coins': 1000}},
  enabled: true,
);

class GoldenProgressRepo implements ProgressRepository {
  @override
  Future<Result<ProgressOverview>> fetchOverview() async => Success(kGoldenProgress);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
