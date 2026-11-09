import 'package:futbol_card/core/auth/session_manager.dart';
import 'package:futbol_card/core/storage/token_storage.dart';
import 'package:futbol_card/core/utils/result.dart';
import 'package:futbol_card/features/collection/domain/repositories/collection_repository.dart';
import 'package:futbol_card/features/deck/domain/repositories/deck_repository.dart';
import 'package:futbol_card/features/leaderboard/domain/repositories/leaderboard_repository.dart';
import 'package:futbol_card/core/network/websocket_service.dart';
import 'package:futbol_card/features/match/domain/repositories/match_repository.dart';
import 'package:futbol_card/features/matchmaking/domain/repositories/matchmaking_repository.dart';
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

const kGoldenRank = PlayerRank(
  mmr: 1825,
  tierId: 8,
  leagueCode: 'usta',
  leagueName: 'Usta',
  division: 3,
  color: '#F8C665',
  tierMinMmr: 1700,
  nextTierMmr: 2000,
  nextLeagueName: 'Master',
  nextDivision: 1,
  progress: 0.42,
);

class GoldenCollectionRepo implements CollectionRepository {
  final List<InventoryCard> cards;
  GoldenCollectionRepo([List<InventoryCard>? c]) : cards = c ?? kGoldenCards;
  @override
  Future<Result<List<InventoryCard>>> fetchInventory() async => Success(cards);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class GoldenLeaderboardRepo implements LeaderboardRepository {
  @override
  Future<Result<PlayerRank>> fetchMyRank() async => const Success(kGoldenRank);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class GoldenMatchRepo implements MatchRepository {
  @override
  Future<Result<List<MatchHistoryEntry>>> fetchMatchHistoryList({int limit = 20, int offset = 0}) async => Success([
        for (var i = 0; i < 4; i++)
          MatchHistoryEntry(
              matchId: 'm$i', opponentId: 'o', opponentUsername: 'Rakip', outcome: MatchOutcome.win),
        const MatchHistoryEntry(
            matchId: 'm9', opponentId: 'o', opponentUsername: 'Rakip', outcome: MatchOutcome.loss),
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
