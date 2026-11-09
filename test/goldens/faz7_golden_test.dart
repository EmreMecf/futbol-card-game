import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/auth/session_manager.dart';
import 'package:futbol_card/core/di/injection.dart';
import 'package:futbol_card/core/storage/favorites_store.dart';
import 'package:futbol_card/core/theme/app_theme.dart';
import 'package:futbol_card/features/leaderboard/presentation/view/leaderboard_view.dart';
import 'package:futbol_card/features/leaderboard/presentation/view/league_tiers_view.dart';
import 'package:futbol_card/features/leaderboard/presentation/viewmodel/leaderboard_view_model.dart';
import 'package:futbol_card/features/leaderboard/presentation/viewmodel/league_tiers_view_model.dart';
import 'package:futbol_card/features/match/presentation/viewmodel/match_view_model.dart';
import 'package:futbol_card/features/match/presentation/widgets/match_result_view.dart';
import 'package:futbol_card/features/profile/presentation/view/profile_view.dart';
import 'package:futbol_card/features/profile/presentation/viewmodel/profile_view_model.dart';
import 'package:futbol_card/features/sbc/presentation/view/sbc_list_view.dart';
import 'package:futbol_card/features/sbc/presentation/view/sbc_result_view.dart';
import 'package:futbol_card/features/sbc/presentation/viewmodel/sbc_list_view_model.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'golden_araclari.dart';
import 'sahte_veri.dart';

/// FAZ 7 — ligler/liderlik, lig basamakları, profil, maç sonucu, görevler.
void main() {
  final atla = goldenSkipReason;
  late SessionManager oturum;

  setUpAll(() async {
    dotenv.loadFromString(envString: 'ENABLE_LOGGING=false');
    if (atla == null) await loadGoldenFonts();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({'favori_kartlar': ['golden-Kuzey Yıldızı', 'golden-Hız Ustası']});
    await getIt.reset();
    oturum = await goldenSession();
    getIt
      ..registerFactory<LeaderboardViewModel>(() => LeaderboardViewModel(GoldenLeaderboardRepo(), oturum))
      ..registerFactory<LeagueTiersViewModel>(() => LeagueTiersViewModel(GoldenLeaderboardRepo()))
      ..registerFactory<ProfileViewModel>(() => ProfileViewModel(GoldenMatchRepo(), GoldenAuthRepo(),
          GoldenLeaderboardRepo(), oturum,
          collectionRepository: GoldenCollectionRepo(), favorites: FavoritesStore()))
      ..registerFactory<SbcListViewModel>(() => SbcListViewModel(GoldenSbcRepo()));
  });

  Future<void> ac(WidgetTester t, Widget ekran, Size boyut) async {
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
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> esle(WidgetTester t, String ad) =>
      expectLater(find.byKey(const Key('ekran')), matchesGoldenFile('ekranlar/$ad.png'));

  final zafer = MatchResultSummary(
    matchId: 'm',
    didIWin: true,
    myScore: 7,
    opponentScore: 4,
    opponent: const OpponentInfo(id: 'o', username: 'StormFC'),
    cardsWon: [kGoldenCards[6], kGoldenCards[9]],
  );
  final maglubiyet = MatchResultSummary(
    matchId: 'm',
    myScore: 3,
    opponentScore: 8,
    opponent: const OpponentInfo(id: 'o', username: 'StormFC'),
    cardsLost: [kGoldenCards[7], kGoldenCards[11], kGoldenCards[10]],
  );

  final ekranlar = <String, Widget Function()>{
    '06_ligler': () => const LeaderboardView(),
    '06l_lig_basamaklari': () => const LeagueTiersView(),
    '07_profil': () => const ProfileView(),
    '08_mac_sonucu': () => MatchResultView(
          result: zafer,
          rewardDelta: const MatchRewardDelta(coins: 150, rating: 25, protectionSlots: 1),
          onClose: () {},
          onNewMatch: () {},
        ),
    '08m_mac_sonucu_maglubiyet': () => MatchResultView(
          result: maglubiyet,
          rewardDelta: const MatchRewardDelta(coins: 0, rating: -25, protectionSlots: 0),
          onClose: () {},
          onNewMatch: () {},
        ),
    '10_gorevler': () => const SbcListView(),
    '10s_gorev_sonucu': () => SbcResultView(
          result: SbcSubmitResult(
            challengeSlug: 'bronz-temizligi',
            challengeName: 'Bronz Temizliği',
            burnedCount: 11,
            rewards: [
              const SbcReward(type: 'coins', amount: 750),
              SbcReward(type: 'pack', packSlug: 'standard', cards: [kGoldenCards[2], kGoldenCards[4], kGoldenCards[7]]),
            ],
          ),
          onClose: () {},
        ),
  };

  for (final e in ekranlar.entries) {
    for (final boyut in kGoldenSizes) {
      testWidgets('${e.key} ${sizeName(boyut)} taşmaz', (t) async {
        await ac(t, e.value(), boyut);
        expect(t.takeException(), isNull, reason: 'taşma veya çizim hatası');
        await esle(t, '${e.key}_${sizeName(boyut)}');
        await t.pumpWidget(const SizedBox());
      }, skip: atla != null);
    }
  }

  for (final (ad, ekran, kaydir) in [
    ('06b_ligler_alt', () => const LeaderboardView(), 600.0),
    ('07b_profil_alt', () => const ProfileView(), 650.0),
  ]) {
    testWidgets('$ad 390x844', (t) async {
      await ac(t, ekran(), const Size(390, 844));
      await t.drag(find.byType(Scrollable).first, Offset(0, -kaydir));
      await t.pump(const Duration(milliseconds: 300));
      await esle(t, '${ad}_390x844');
    }, skip: atla != null);
  }
}
