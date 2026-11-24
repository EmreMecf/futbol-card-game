import 'package:material_ui/material_ui.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/auth/session_manager.dart';
import 'package:futbol_card/core/di/injection.dart';
import 'package:futbol_card/core/error/app_exception.dart';
import 'package:futbol_card/core/network/api_client.dart';
import 'package:futbol_card/core/theme/app_theme.dart';
import 'package:futbol_card/features/chests/presentation/viewmodel/chests_view_model.dart';
import 'package:futbol_card/features/social/social_api.dart';
import 'package:futbol_card/features/social/social_view_models.dart';
import 'package:futbol_card/ui_v21/screens/social/v21_social_screens.dart';
import 'package:futbol_card/ui_v21/ui_v21.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../goldens/sahte_veri.dart';
import 'v21_test_support.dart';

/// 056: elmas, arkadaşlık, açık profil, rakip kadrosu (istemci)

class _NoApi implements ApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Bellekte çalışan sahte sosyal uçlar
class FakeSocialApi extends SocialApi {
  FakeSocialApi() : super(_NoApi());

  final statuses = <String, FriendStatus>{'u2': FriendStatus.none, 'u3': FriendStatus.incoming};
  final calls = <String>[];
  int bakiye = 40;
  int coins = 1000;
  String? failCode;

  PlayerSummary _p(String id, String ad) =>
      PlayerSummary(id: id, username: ad, mmr: 1450, wins: 9, losses: 3, online: id == 'u2', friendStatus: statuses[id]!);

  @override
  Future<FriendLists> friends() async => FriendLists(
    friends: [for (final e in statuses.entries) if (e.value == FriendStatus.friends) _p(e.key, 'oyuncu_${e.key}')],
    incoming: [for (final e in statuses.entries) if (e.value == FriendStatus.incoming) _p(e.key, 'oyuncu_${e.key}')],
    outgoing: [for (final e in statuses.entries) if (e.value == FriendStatus.outgoing) _p(e.key, 'oyuncu_${e.key}')],
  );

  Future<String> _set(String id, FriendStatus s, String call) async {
    calls.add('$call:$id');
    if (failCode != null) throw AppException(message: 'x', technicalDetail: failCode);
    statuses[id] = s;
    return s.name;
  }

  @override
  Future<String> request(String id) => _set(id, FriendStatus.outgoing, 'request');
  @override
  Future<String> accept(String id) => _set(id, FriendStatus.friends, 'accept');
  @override
  Future<String> decline(String id) => _set(id, FriendStatus.none, 'decline');
  @override
  Future<String> remove(String id) => _set(id, FriendStatus.none, 'remove');

  @override
  Future<List<PlayerSummary>> search(String q) async {
    calls.add('search:$q');
    return [_p('u2', 'oyuncu_u2')].where((p) => p.username.startsWith(q)).toList();
  }

  @override
  Future<PublicProfile> profile(String id) async => PublicProfile.fromJson({
    'id': id,
    'username': 'Rakip Usta',
    'mmr': 1820,
    'wins': 24,
    'losses': 9,
    'draws': 2,
    'online': false,
    'last_seen_at': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
    'friend_status': statuses[id]?.name ?? 'none',
    'friend_count': 4,
    'collection_count': 37,
    'equipped': {'frame': 'frame_season1'},
    'top_cards': [
      {'card_id': 'c1', 'full_name': 'Aren Solmar', 'position': 'FWD', 'tier': 'legend', 'power': 98},
      {'card_id': 'c2', 'full_name': 'Taren Volsk', 'position': 'GK', 'tier': 'legend', 'power': 95},
      {'card_id': 'c3', 'full_name': 'Usta Kaleci', 'position': 'GK', 'tier': 'diamond', 'power': 90},
    ],
    'recent_form': ['win', 'loss', 'win', 'draw'],
    'head_to_head': {'matches': 3, 'my_wins': 2, 'their_wins': 1, 'draws': 0},
    'email': 'gizli@ornek.com',
    'coins': 99999,
  });

  @override
  Future<GemStatus> gems() async => GemStatus(gems: bakiye, exchange: const [
    GemOffer(slug: 'gold_small', gems: 10, coins: 250),
    GemOffer(slug: 'gold_medium', gems: 50, coins: 1400),
  ]);

  @override
  Future<Map<String, dynamic>> exchange(String offer, {required String key}) async {
    calls.add('exchange:$offer:$key');
    final o = offer == 'gold_small' ? (10, 250) : (50, 1400);
    bakiye -= o.$1;
    coins += o.$2;
    return {'gems_after': bakiye, 'coins_after': coins};
  }

  @override
  Future<ChestOpenResult> openChestWithGems(String chestId, int expectedCost, {required String key}) async {
    calls.add('gemopen:$chestId:$expectedCost');
    bakiye -= expectedCost;
    return ChestOpenResult(chestId: chestId, chestType: 'gold', coins: 80, gems: 6, gemsAfter: bakiye + 6, gemsSpent: expectedCost, coinsAfter: 2530);
  }

  @override
  Future<OpponentSquad> opponentSquad(String matchId) async => OpponentSquad.fromJson({
    'match_id': matchId,
    'opponent': {'id': 'u9', 'username': 'Kartal', 'mmr': 1600},
    'outcome': 'loss',
    'cards': [
      for (final (i, p) in ['GK', 'DEF', 'DEF', 'DEF', 'DEF', 'MID', 'MID', 'MID', 'MID', 'FWD', 'FWD'].indexed)
        {'card_id': 'k$i', 'full_name': 'Rakip Oyuncu $i', 'position': p, 'tier': i < 3 ? 'gold' : 'silver', 'power': 70 + i},
    ],
  });
}

void main() {
  late SessionManager session;
  late FakeSocialApi api;

  setUpAll(() async {
    dotenv.loadFromString(envString: 'ENABLE_LOGGING=false');
    await loadV21Fonts();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    session = await goldenSession();
    await session.updateUser(session.user!.copyWith(gems: 40));
    api = FakeSocialApi();
    getIt
      ..registerSingleton<SocialApi>(api)
      ..registerSingleton<SessionManager>(session);
  });

  Future<void> pump(WidgetTester t, Widget screen, {Size size = const Size(390, 844)}) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ChangeNotifierProvider<SessionManager>.value(
        value: session,
        child: MaterialApp(debugShowCheckedModeBanner: false, theme: AppTheme.dark, home: Scaffold(body: screen)),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 150));
    }
  }

  group('Modeller', () {
    test('açık profil: gizli alanlar modele girmez, form ve karşılaşma okunur', () async {
      final p = await api.profile('u2');
      expect(p.username, 'Rakip Usta');
      expect(p.topCards, hasLength(3));
      expect(p.recentForm, ['win', 'loss', 'win', 'draw']);
      expect(p.headToHead.myWins, 2);
      expect(p.frame, 'frame_season1');
      expect(p.winRate, closeTo(24 / 35, 0.001));
    });

    test('elmas bedeli sunucuyla aynı: kalan her 10 dk 1 elmas, en az 1', () {
      expect(GemStatus.costFor(0), 1);
      expect(GemStatus.costFor(59), 1);
      expect(GemStatus.costFor(600), 1);
      expect(GemStatus.costFor(601), 2);
      expect(GemStatus.costFor(3 * 3600), 18);
    });

    test('son görülme metni', () {
      final simdi = DateTime(2026, 11, 25, 12);
      expect(lastSeenText(true, null), 'Çevrimiçi');
      expect(lastSeenText(false, simdi.subtract(const Duration(minutes: 5)), now: simdi), '5 dk önce');
      expect(lastSeenText(false, simdi.subtract(const Duration(hours: 3)), now: simdi), '3 sa önce');
      expect(lastSeenText(false, simdi.subtract(const Duration(days: 2)), now: simdi), '2 gün önce');
      expect(lastSeenText(false, null), 'Uzun süredir yok');
    });
  });

  group('Arkadaşlar', () {
    test('ViewModel: istek kabul, arama ve hata mesajı', () async {
      final vm = FriendsViewModel(api);
      await vm.load();
      expect(vm.lists.incoming.single.id, 'u3');
      await vm.accept(vm.lists.incoming.single);
      expect(vm.lists.friends.single.id, 'u3');
      expect(vm.info, 'Artık arkadaşsınız!');

      vm.setQuery('o');
      expect(vm.results, isEmpty, reason: '2 harften kısa aranmaz');
      vm.setQuery('oyuncu');
      await vm.search();
      expect(vm.results.single.username, 'oyuncu_u2');
      await vm.sendRequest(vm.results.single);
      expect(vm.results.single.friendStatus, FriendStatus.outgoing);
      expect(vm.lists.outgoing.single.id, 'u2');

      api.failCode = 'friend_limit';
      await vm.remove(vm.lists.outgoing.single);
      expect(vm.actionError, 'En fazla 100 arkadaşın olabilir.');
      vm.dispose();
    });

    testWidgets('ekran: istekler sekmesinde KABUL, arama sonucunda EKLE', (t) async {
      await pump(t, const V21FriendsScreen());
      expect(t.takeException(), isNull);
      expect(find.text('HENÜZ ARKADAŞIN YOK'), findsOneWidget);
      expect(find.text('İSTEKLER (1)'), findsOneWidget);

      await t.tap(find.text('İSTEKLER (1)'));
      await settle(t);
      expect(find.text('oyuncu_u3'), findsOneWidget);
      await t.tap(find.text('KABUL'));
      await settle(t);
      expect(api.calls, contains('accept:u3'));
      expect(find.text('Artık arkadaşsınız!'), findsOneWidget);

      await t.tap(find.text('ARA'));
      await settle(t);
      await t.enterText(find.byKey(const Key('oyuncu-ara')).first, 'oyuncu');
      await t.pump(const Duration(milliseconds: 400));
      await settle(t);
      expect(find.text('oyuncu_u2'), findsOneWidget);
      await t.tap(find.text('EKLE'));
      await settle(t);
      expect(api.calls, contains('request:u2'));
      expect(find.text('İSTEK GİTTİ'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  group('Açık profil', () {
    testWidgets('görünenler var, gizliler yok; ARKADAŞ EKLE çalışır', (t) async {
      await pump(t, const V21PlayerProfileScreen(playerId: 'u2'));
      expect(t.takeException(), isNull);
      expect(find.text('Rakip Usta'), findsOneWidget);
      expect(find.text('1.820'), findsOneWidget);
      expect(find.text('%69'), findsOneWidget);
      expect(find.text('3 sa önce'), findsOneWidget);
      expect(find.text('99.999'), findsNothing, reason: 'altın gizli');
      expect(find.textContaining('gizli@ornek.com'), findsNothing, reason: 'e-posta gizli');
      expect(find.byType(V21PlayerCard), findsNWidgets(3));
      await t.scrollUntilVisible(find.text('Sen 2 · Rakip Usta 1 · Berabere 0'), 200,
          scrollable: find.byType(Scrollable).first);
      await t.tap(find.text('ARKADAŞ EKLE'));
      await settle(t);
      expect(api.calls, contains('request:u2'));
      expect(find.text('İSTEĞİ GERİ ÇEK'), findsOneWidget);
    });
  });

  group('Rakip kadrosu', () {
    testWidgets('bitmiş maçta rakibin 11 kartı mevkilere göre', (t) async {
      await pump(t, const V21OpponentSquadSheet(matchId: 'm1'));
      expect(t.takeException(), isNull);
      expect(find.text('KARTAL'), findsOneWidget);
      expect(find.text('KAYBETTİN'), findsOneWidget);
      expect(find.byType(V21PlayerCard), findsNWidgets(11));
      expect(find.textContaining('ortalama güç 75'), findsOneWidget);
      expect(find.text('PROFİLİ'), findsOneWidget);
    });
  });

  group('Elmas', () {
    testWidgets('mağaza: elmasla altın alınır, bakiye ve oturum güncellenir', (t) async {
      await pump(t, const SingleChildScrollView(child: V21GemStoreSection()));
      expect(t.takeException(), isNull);
      expect(find.text('ELMASLA ALTIN'), findsOneWidget);
      await t.tap(find.byKey(const Key('elmas-gold_small')));
      await settle(t);
      expect(api.calls.where((c) => c.startsWith('exchange:gold_small')), hasLength(1));
      expect(session.user!.gems, 30);
      expect(session.user!.coins, 1250);
      expect(find.text('+250 altın hesabına eklendi.'), findsOneWidget);
      // 50 elmas yok: sunucuya gitmeden uyarı
      await t.tap(find.byKey(const Key('elmas-gold_medium')));
      await settle(t);
      expect(api.calls.where((c) => c.startsWith('exchange:gold_medium')), isEmpty);
      expect(find.text('Yeterli elmas yok (50 gerekli).'), findsOneWidget);
    });

    test('sandık: elmas bedeli hesaplanır, elmasla açılır, bakiye güncellenir', () async {
      final vm = ChestsViewModel(GoldenChestRepo(), session: session, clock: () => kGoldenServerTime, gemApi: api);
      await vm.load();
      final slots = vm.inventory!.slots;
      final kapali = slots.firstWhere((c) => c.isSealed);
      final acilan = slots.firstWhere((c) => c.isUnlocking);
      expect(vm.gemCost(kapali), GemStatus.costFor(kapali.unlockSeconds));
      expect(vm.gemCost(acilan), GemStatus.costFor(vm.remaining(acilan)!.inSeconds));
      expect(vm.canOpenWithGems(kapali), isTrue);
      final once = session.user!.gems;
      final bedel = vm.gemCost(acilan)!;
      expect(bedel, lessThanOrEqualTo(once));
      expect(await vm.openWithGems(acilan), isTrue);
      expect(api.calls.last, 'gemopen:${acilan.id}:$bedel');
      expect(vm.lastOpening?.gems, 6);
      expect(session.user!.gems, once - bedel + 6);
      expect(session.user!.coins, 2530);

      // Yetersiz elmas: sunucuya gitmeden uyarı
      await session.updateUser(session.user!.copyWith(gems: 0));
      expect(await vm.openWithGems(kapali), isFalse);
      expect(vm.actionError, startsWith('Yeterli elmas yok'));
      vm.dispose();
    });
  });
}
