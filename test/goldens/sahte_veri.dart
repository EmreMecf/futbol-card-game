import 'package:futbol_card/core/auth/session_manager.dart';
import 'package:futbol_card/core/storage/token_storage.dart';
import 'package:futbol_card/core/utils/result.dart';
import 'package:futbol_card/features/collection/domain/repositories/collection_repository.dart';
import 'package:futbol_card/features/deck/domain/repositories/deck_repository.dart';
import 'package:futbol_card/features/leaderboard/domain/repositories/leaderboard_repository.dart';
import 'package:futbol_card/features/match/domain/repositories/match_repository.dart';
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

class GoldenDeckRepo implements DeckRepository {
  @override
  Future<Result<List<DeckSummary>>> fetchDecks() async =>
      const Success([DeckSummary(id: 'd1', name: 'Ana kadro', isActive: true, cardCount: 11)]);
  @override
  Future<Result<List<InventoryCard>>> fetchInventory() async => Success(kGoldenCards);
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
