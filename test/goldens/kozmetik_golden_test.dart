import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/auth/session_manager.dart';
import 'package:futbol_card/core/di/injection.dart';
import 'package:futbol_card/core/storage/favorites_store.dart';
import 'package:futbol_card/core/theme/app_theme.dart';
import 'package:futbol_card/core/utils/result.dart';
import 'package:futbol_card/features/items/cosmetics/equipped_cosmetics.dart';
import 'package:futbol_card/features/items/domain/items_repository.dart';
import 'package:futbol_card/features/match/presentation/arena/ref_stadium.dart';
import 'package:futbol_card/features/match/presentation/viewmodel/match_view_model.dart';
import 'package:futbol_card/features/match/presentation/widgets/match_result_view.dart';
import 'package:futbol_card/features/profile/presentation/view/profile_view.dart';
import 'package:futbol_card/features/profile/presentation/viewmodel/profile_view_model.dart';
import 'package:futbol_card/shared/widgets/cosmetics/cosmetic_art.dart';
import 'package:futbol_card/shared/widgets/ref_card/ref_player_card.dart';
import 'package:futbol_card/shared/widgets/walkout/confetti_overlay.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'golden_araclari.dart';
import 'sahte_item.dart';
import 'sahte_veri.dart';

/// EKONOMİ V2 FAZ 6 — kozmetiklerin oyunda gösterimi: profil (çerçeve,
/// forma, kaptan bandı, rozet), kart görünümü, arena, zafer animasyonu.
/// Kozmetikler yalnız görsel: güç, ad ve nadirlik aynı kalır (K1).
const _hepsi = {
  'frame': 'frame_season1',
  'kit': 'kit_season1',
  'character': 'captain_band',
  'badge': 'badge_s1_gold',
  'card_skin': 'card_skin_night',
  'arena': 'arena_rainy_night',
  'victory': 'victory_fireworks',
};

class _Depo implements ItemsRepository {
  Map<String, String> giyilen;
  _Depo(this.giyilen);

  @override
  Future<Result<ItemInventory>> fetchInventory() async => Success(ItemInventory(
      catalog: kGoldenItemCatalog, items: const [], equipped: giyilen, enabled: true, serverTime: kGoldenServerTime));

  @override
  Future<Result<Map<String, dynamic>>> use(String slug,
          {Map<String, dynamic> target = const {}, required String idempotencyKey}) async =>
      const Success({});
  @override
  Future<Result<void>> equip(String slug, {required String idempotencyKey}) async => const Success(null);
  @override
  Future<Result<void>> unequip(String slot, {required String idempotencyKey}) async => const Success(null);
}

void main() {
  final atla = goldenSkipReason;
  late SessionManager oturum;
  late EquippedCosmetics kozmetik;

  setUpAll(() async {
    dotenv.loadFromString(envString: 'ENABLE_LOGGING=false');
    if (atla == null) await loadGoldenFonts();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({'favori_kartlar': ['golden-Kuzey Yıldızı', 'golden-Hız Ustası']});
    await getIt.reset();
    oturum = await goldenSession();
    kozmetik = EquippedCosmetics(_Depo(_hepsi));
    await kozmetik.refresh();
    getIt
      ..registerSingleton<EquippedCosmetics>(kozmetik)
      ..registerFactory<ProfileViewModel>(() => ProfileViewModel(GoldenMatchRepo(), GoldenAuthRepo(),
          GoldenLeaderboardRepo(), oturum,
          collectionRepository: GoldenCollectionRepo(), favorites: FavoritesStore()));
  });

  Future<void> ac(WidgetTester t, Widget ekran, Size boyut, {int kare = 8}) async {
    t.view.physicalSize = boyut;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ChangeNotifierProvider<SessionManager>.value(
      value: oturum,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: RepaintBoundary(key: const Key('ekran'), child: ekran),
      ),
    ));
    for (var i = 0; i < kare; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> esle(WidgetTester t, String ad) =>
      expectLater(find.byKey(const Key('ekran')), matchesGoldenFile('ekranlar/$ad.png'));

  for (final boyut in [const Size(390, 844), const Size(320, 568), const Size(1366, 768)]) {
    testWidgets('32 profil kozmetikleri ${sizeName(boyut)}', (t) async {
      await ac(t, const ProfileView(), boyut);
      expect(t.takeException(), isNull);
      expect(find.text('S1'), findsOneWidget, reason: 'sezon çerçevesi');
      expect(find.text('C'), findsOneWidget, reason: 'kaptan bandı');
      expect(find.text('SEZON 1 · ALTIN'), findsOneWidget, reason: 'sezon rozeti');
      await esle(t, '32_profil_kozmetik_${sizeName(boyut)}');
      await t.pumpWidget(const SizedBox());
    }, skip: atla != null);
  }

  testWidgets('profil: kozmetik çıkarılınca eski görünüm (canlı)', (t) async {
    await ac(t, const ProfileView(), const Size(390, 844));
    expect(find.text('S1'), findsOneWidget);
    kozmetik.apply(const {});
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('S1'), findsNothing);
    expect(find.text('SEZON 1 · ALTIN'), findsNothing);
    await t.pumpWidget(const SizedBox());
  }, skip: atla != null);

  testWidgets('33 kart görünümü: Gece Işığı (üst) / varsayılan (alt), 5 nadirlik', (t) async {
    Widget sira(String? skin) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (final (i, tier) in CardTier.values.indexed)
            Padding(
              padding: const EdgeInsets.all(3),
              child: RefPlayerCard(
                name: 'Oyuncu ${i + 1}',
                position: CardPosition.values[i % CardPosition.values.length],
                tier: tier,
                power: 60 + i * 8,
                seed: 'kozmetik-$i',
                width: 70,
                skin: skin,
              ),
            ),
        ]);
    await ac(
        t,
        Scaffold(
          backgroundColor: const Color(0xFF080E19),
          body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [sira('card_skin_night'), sira(null)])),
        ),
        const Size(390, 300));
    expect(t.takeException(), isNull);
    // K1: kozmetik gücü ve adı değiştirmez (iki sırada aynı metinler)
    for (var i = 0; i < CardTier.values.length; i++) {
      expect(find.text('${60 + i * 8}'), findsNWidgets(2));
      expect(find.text('Oyuncu ${i + 1}'), findsNWidgets(2));
    }
    await esle(t, '33_kart_gece_isigi');
    await t.pumpWidget(const SizedBox());
  }, skip: atla != null);

  testWidgets('34 arena: Yağmurlu Gece (üst) / varsayılan (alt)', (t) async {
    await ac(
        t,
        const Scaffold(
          backgroundColor: Color(0xFF080E19),
          body: Padding(
            padding: EdgeInsets.all(12),
            child: Column(children: [
              RefStadium(caption: 'SIRA SENDE', height: 200, skin: 'arena_rainy_night'),
              SizedBox(height: 12),
              RefStadium(caption: 'SIRA SENDE', height: 200),
            ]),
          ),
        ),
        const Size(390, 450));
    expect(t.takeException(), isNull);
    expect(find.byType(RainyNightOverlay), findsOneWidget, reason: 'yalnız kozmetikli stadyumda');
    await esle(t, '34_arena_yagmurlu_gece');
    await t.pumpWidget(const SizedBox());
  }, skip: atla != null);

  testWidgets('35 zafer: havai fişek konfetinin yerine geçer', (t) async {
    await ac(
      t,
      MatchResultView(
        result: const MatchResultSummary(matchId: 'm', didIWin: true, myScore: 7, opponentScore: 4),
        rewardDelta: const MatchRewardDelta(coins: 100, rating: 25, protectionSlots: 1),
        onClose: () {},
        onNewMatch: () {},
      ),
      const Size(390, 844),
      kare: 12,
    );
    expect(find.byType(FireworksOverlay), findsOneWidget);
    expect(find.byType(ConfettiOverlay), findsNothing);
    expect(t.takeException(), isNull);
    await esle(t, '35_zafer_havai_fisek_390x844');
    // Kozmetik yoksa eski konfeti
    kozmetik.apply(const {});
    await t.pumpWidget(const SizedBox());
    await ac(
      t,
      MatchResultView(
        result: const MatchResultSummary(matchId: 'm', didIWin: true, myScore: 7, opponentScore: 4),
        rewardDelta: const MatchRewardDelta(coins: 100, rating: 25, protectionSlots: 1),
        onClose: () {},
        onNewMatch: () {},
      ),
      const Size(390, 844),
    );
    expect(find.byType(ConfettiOverlay), findsOneWidget);
    expect(find.byType(FireworksOverlay), findsNothing);
    await t.pumpWidget(const SizedBox(), duration: const Duration(seconds: 3));
  }, skip: atla != null);

  test('servis: ekonomi kapalıysa ve çıkışta hiçbir kozmetik yok', () async {
    final depo = _Depo(_hepsi);
    final s = EquippedCosmetics(depo);
    await s.refresh();
    expect(s.cardSkin, 'card_skin_night');
    expect(s.arena, 'arena_rainy_night');
    s.clear();
    expect(s.equipped, isEmpty);
    expect(s.frame, isNull);
  });
}
