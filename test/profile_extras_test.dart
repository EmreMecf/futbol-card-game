import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/auth/session_manager.dart';
import 'package:futbol_card/core/error/app_exception.dart';
import 'package:futbol_card/core/storage/favorites_store.dart';
import 'package:futbol_card/core/storage/token_storage.dart';
import 'package:futbol_card/core/theme/app_theme.dart';
import 'package:futbol_card/core/utils/result.dart';
import 'package:futbol_card/features/auth/domain/repositories/auth_repository.dart';
import 'package:futbol_card/features/collection/domain/repositories/collection_repository.dart';
import 'package:futbol_card/features/leaderboard/domain/repositories/leaderboard_repository.dart';
import 'package:futbol_card/features/match/domain/repositories/match_repository.dart';
import 'package:futbol_card/features/profile/domain/achievements.dart';
import 'package:futbol_card/features/profile/presentation/viewmodel/profile_view_model.dart';
import 'package:futbol_card/features/profile/presentation/widgets/profile_sections.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// FAZ 3 — Profil: başarımlar ve favori kartlar (MD bölüm 4-J).
void main() {
  UserModel oyuncu({int g = 0, int m = 0, int b = 0}) =>
      UserModel(id: 'u', username: 'Emre', wins: g, losses: m, draws: b);

  PlayerRank rutbe(String kod) => PlayerRank(
        mmr: 1500,
        tierId: 4,
        leagueCode: kod,
        leagueName: kod,
        division: 1,
        color: '#FFFFFF',
      );

  Achievement bul(List<Achievement> l, String id) =>
      l.firstWhere((a) => a.id == id);

  // ==================================================================
  // BAŞARIM HESABI
  // ==================================================================
  group('Achievement.evaluate', () {
    test('yeni oyuncu: hepsi kilitli', () {
      final l = Achievement.evaluate(oyuncu(), rutbe('amateur'));
      expect(l.where((a) => a.isUnlocked), isEmpty);
    });

    test('maç ve galibiyet eşikleri gerçek sayaçlardan', () {
      final l = Achievement.evaluate(oyuncu(g: 10, m: 30, b: 10), null);

      expect(bul(l, 'ilk_mac').isUnlocked, isTrue);
      expect(bul(l, 'ilk_galibiyet').isUnlocked, isTrue);
      expect(bul(l, 'on_galibiyet').isUnlocked, isTrue);
      // 10 + 30 + 10 = 50 maç
      expect(bul(l, 'elli_mac').isUnlocked, isTrue);
    });

    test('eşiğin bir altı kilitli, ilerleme doğru', () {
      final l = Achievement.evaluate(oyuncu(g: 9), null);
      final on = bul(l, 'on_galibiyet');

      expect(on.isUnlocked, isFalse);
      expect(on.progress, closeTo(0.9, 0.001));
      expect(on.progressText, '9 / 10');
    });

    test('ilerleme metni hedefi aşmaz', () {
      final l = Achievement.evaluate(oyuncu(g: 37), null);
      expect(bul(l, 'on_galibiyet').progressText, '10 / 10');
    });

    test('lig başarımları sunucunun lig koduna göre', () {
      expect(
        bul(Achievement.evaluate(oyuncu(), rutbe('usta')), 'usta_ligi').isUnlocked,
        isTrue,
      );
      expect(
        bul(Achievement.evaluate(oyuncu(), rutbe('usta')), 'master_ligi').isUnlocked,
        isFalse,
      );
      final mc = Achievement.evaluate(oyuncu(), rutbe('master_class'));
      expect(bul(mc, 'usta_ligi').isUnlocked, isTrue);
      expect(bul(mc, 'master_ligi').isUnlocked, isTrue);
    });

    test('rütbe yüklenemezse lig başarımları KİLİTLİ (yanlış açık değil)',
        () {
      final l = Achievement.evaluate(oyuncu(g: 100), null);
      expect(bul(l, 'usta_ligi').isUnlocked, isFalse);
      expect(bul(l, 'master_ligi').isUnlocked, isFalse);
    });

    test('bilinmeyen lig kodu çökertmez, en alt sayılır', () {
      final l = Achievement.evaluate(oyuncu(), rutbe('yeni_lig'));
      expect(bul(l, 'usta_ligi').isUnlocked, isFalse);
    });
  });

  // ==================================================================
  // FAVORİ KARTLAR
  // ==================================================================
  InventoryCard kart(String u, String c, CardTier t, int g) => InventoryCard(
        userCardId: u,
        cardId: c,
        fullName: 'Oyuncu $c',
        position: CardPosition.forward,
        tier: t,
        power: g,
      );

  late SessionManager oturum;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    oturum = SessionManager(TokenStorage(_SahteDepo()));
  });

  ProfileViewModel vmKur({CollectionRepository? koleksiyon, FavoritesStore? fav}) =>
      ProfileViewModel(
        _SahteMac(),
        _SahteAuth(),
        _SahteLig(),
        oturum,
        collectionRepository: koleksiyon,
        favorites: fav,
      );

  group('Profil favori kartları', () {
    test('bağımlılık verilmezse bölüm desteklenmez (eski kurulumlar)', () {
      expect(vmKur().supportsFavorites, isFalse);
    });

    test('aynı oyuncu bir kez, en iyiden kötüye sıralı', () async {
      SharedPreferences.setMockInitialValues({
        'favori_kartlar': ['c-altin', 'c-legend', 'c-bronz'],
      });
      final vm = vmKur(
        koleksiyon: _SahteKoleksiyon([
          kart('u1', 'c-bronz', CardTier.bronze, 50),
          kart('u2', 'c-legend', CardTier.legend, 95),
          kart('u3', 'c-altin', CardTier.gold, 80),
          kart('u4', 'c-altin', CardTier.gold, 80), // ikinci kopya
          kart('u5', 'c-favori-degil', CardTier.legend, 99),
        ]),
        fav: FavoritesStore(),
      );

      await vm.loadFavorites();

      expect(
        vm.favoriteCards.map((k) => k.cardId),
        ['c-legend', 'c-altin', 'c-bronz'],
      );
    });

    test('en fazla 6 favori gösterilir', () async {
      SharedPreferences.setMockInitialValues({
        'favori_kartlar': [for (var i = 0; i < 10; i++) 'c$i'],
      });
      final vm = vmKur(
        koleksiyon: _SahteKoleksiyon([
          for (var i = 0; i < 10; i++) kart('u$i', 'c$i', CardTier.gold, 70 + i),
        ]),
        fav: FavoritesStore(),
      );
      await vm.loadFavorites();
      expect(vm.favoriteCards, hasLength(ProfileViewModel.maxFavoritesShown));
    });
  });

  // ==================================================================
  // ÇİZİM
  // ==================================================================
  group('Başarım karosu', () {
    Widget sarmala(Widget c) => MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Center(child: SizedBox(width: 170, height: 112, child: c)),
          ),
        );

    testWidgets('kilitli karoda kilit ve ilerleme çubuğu', (tester) async {
      final a = bul(Achievement.evaluate(oyuncu(g: 4), null), 'on_galibiyet');
      await tester.pumpWidget(sarmala(AchievementTile(achievement: a)));

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
      expect(find.text('Seri Galip'), findsOneWidget);
    });

    testWidgets('açık karoda onay işareti, çubuk yok', (tester) async {
      final a = bul(Achievement.evaluate(oyuncu(g: 1), null), 'ilk_galibiyet');
      await tester.pumpWidget(sarmala(AchievementTile(achievement: a)));

      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.byIcon(Icons.lock_rounded), findsNothing);
    });

    testWidgets('ekran okuyucu durumu söyler', (tester) async {
      final semantik = tester.ensureSemantics();
      final a = bul(Achievement.evaluate(oyuncu(g: 4), null), 'on_galibiyet');
      await tester.pumpWidget(sarmala(AchievementTile(achievement: a)));

      expect(
        find.bySemanticsLabel(RegExp('Kilitli, 4 / 10')),
        findsOneWidget,
      );
      semantik.dispose();
    });
  });
}

// ====================================================================
// SAHTE KAYNAKLAR
// ====================================================================
class _SahteKoleksiyon implements CollectionRepository {
  final List<InventoryCard> kartlar;
  _SahteKoleksiyon(this.kartlar);

  @override
  Future<Result<List<InventoryCard>>> fetchInventory() async =>
      Success(kartlar);

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _SahteMac implements MatchRepository {
  @override
  Future<Result<List<MatchHistoryEntry>>> fetchMatchHistoryList({
    int limit = 20,
    int offset = 0,
  }) async =>
      const Success([]);

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _SahteLig implements LeaderboardRepository {
  @override
  Future<Result<PlayerRank>> fetchMyRank() async =>
      const Failure(AppException(message: 'yok'));

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _SahteAuth implements AuthRepository {
  @override
  Future<Result<MeResponse>> fetchProfile() async =>
      const Failure(AppException(message: 'yok'));

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _SahteDepo implements FlutterSecureStorage {
  final Map<String, String> _v = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _v.remove(key);
    } else {
      _v[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _v[key];

  @override
  dynamic noSuchMethod(Invocation i) => null;
}
