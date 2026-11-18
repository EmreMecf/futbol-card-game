import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/auth/session_manager.dart';
import 'package:futbol_card/core/di/injection.dart';
import 'package:futbol_card/core/theme/app_theme.dart';
import 'package:futbol_card/core/utils/result.dart';
import 'package:futbol_card/features/chests/presentation/viewmodel/chests_view_model.dart';
import 'package:futbol_card/features/items/domain/items_repository.dart';
import 'package:futbol_card/features/leaderboard/presentation/viewmodel/leaderboard_view_model.dart';
import 'package:futbol_card/features/sbc/domain/repositories/sbc_repository.dart';
import 'package:futbol_card/features/sbc/presentation/viewmodel/sbc_builder_view_model.dart';
import 'package:futbol_card/ui_v21/screens/inner/v21_inner_screens.dart';
import 'package:futbol_card/ui_v21/screens/rewards/v21_match_panels.dart';
import 'package:futbol_card/ui_v21/ui_v21.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../goldens/sahte_item.dart';
import '../goldens/sahte_veri.dart';
import 'v21_test_support.dart';

/// FAZ 6 — PR'lardan bağımsız kalanlar: sıralama, kart takası kadro kurma,
/// sandık olasılıkları, maç sonu panelleri. HTML referansında bu ekranların
/// karşılığı yok; golden + davranış testleri.

/// Kadro kurma görevi: her kart en az Bronz → tam kadro şartı karşılar
final _challenge = SbcChallenge.fromJson({
  'id': 'c9',
  'slug': 'kadro-temizligi',
  'name': 'Kadro Temizliği',
  'category': 'genel',
  'requirements': [
    {'tier': 'bronze', 'type': 'min_tier'},
  ],
  'rewards': [
    {'type': 'coins', 'amount': 750},
  ],
});

/// Kadro dışı (eritilebilir) kartlar: altın kadronun kopyaları
final List<InventoryCard> _spare = [
  for (final c in kGoldenSquad.values) c.copyWith(userCardId: 'yedek-${c.userCardId}', inDeck: false),
];

class _SbcRepo extends GoldenSbcRepo {
  final submitted = <List<String>>[];

  @override
  Future<Result<List<InventoryCard>>> fetchInventory() async => Success(_spare);

  @override
  Future<Result<SbcSubmitResult>> submit({required String challengeId, required List<String> userCardIds}) async {
    submitted.add(userCardIds);
    return const Success(
      SbcSubmitResult(challengeSlug: 'kadro-temizligi', challengeName: 'Kadro Temizliği', burnedCount: 11, coins: 750),
    );
  }
}

PlayerRank _rank(int tier, String code, String name, int div, int mmr, double progress) => PlayerRank(
  mmr: mmr,
  tierId: tier,
  leagueCode: code,
  leagueName: name,
  division: div,
  color: '#F97316',
  tierMinMmr: mmr - 50,
  nextTierMmr: mmr + 75,
  nextLeagueName: name,
  nextDivision: div + 1,
  progress: progress,
);

final _promoted = MatchLeagueChange(
  mmrBefore: 1860,
  mmrAfter: 1885,
  mmrDelta: 25,
  rankBefore: _rank(8, 'master', 'Master', 2, 1860, 0.9),
  rankAfter: _rank(9, 'master', 'Master', 3, 1885, 0.1),
  direction: 'promoted',
);

const _same = MatchLeagueChange(
  mmrBefore: 1800,
  mmrAfter: 1825,
  mmrDelta: 25,
  rankBefore: kGoldenRank,
  rankAfter: kGoldenRank,
);

void main() {
  final skipGolden = v21GoldenSkipReason;
  late SessionManager session;
  late _SbcRepo sbc;

  setUpAll(() async {
    dotenv.loadFromString(envString: 'ENABLE_LOGGING=false');
    await loadV21Fonts();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    session = await goldenSession();
    sbc = _SbcRepo();
    final items = GoldenItemsRepo();
    getIt
      ..registerSingleton<ItemsRepository>(items)
      ..registerSingleton<SbcRepository>(sbc)
      ..registerFactory<LeaderboardViewModel>(() => LeaderboardViewModel(GoldenLeaderboardRepo(), session))
      ..registerFactory<ChestsViewModel>(
        () => ChestsViewModel(GoldenChestRepo(), items: items, clock: () => kGoldenServerTime),
      )
      ..registerFactoryParam<SbcBuilderViewModel, SbcChallenge, void>(
        (gorev, _) => SbcBuilderViewModel(getIt<SbcRepository>(), challenge: gorev),
      );
  });

  Future<void> pump(WidgetTester t, Widget screen, Size size) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ChangeNotifierProvider<SessionManager>.value(
        value: session,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          home: RepaintBoundary(key: const Key('screen'), child: screen),
        ),
      ),
    );
    await t.runAsync(() async {
      for (final a in V21Assets.all) {
        await precacheImage(AssetImage(a), t.binding.rootElement!);
      }
    });
    for (var i = 0; i < 12; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> unmount(WidgetTester t) => t.pumpWidget(const SizedBox.shrink());

  Widget panels() => Scaffold(
    backgroundColor: Colors.transparent,
    body: Stack(
      children: [
        const Positioned.fill(child: V21Background()),
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            V21MatchChestPanel(
              matchId: 'm1',
              preview: SourceChest(
                chest: goldenChest('p1', ChestTypes.gold, slot: 2),
                winCopy: const {'full_name': 'Efe Kaya'},
              ),
            ),
            const V21MatchSeasonXpLine(matchId: 'm1', preview: MatchSeasonXp(xp: 100)),
            const SizedBox(height: 12),
            V21LeagueChangePanel(change: _promoted),
          ],
        ),
      ],
    ),
  );

  // ------------------------------------------------------------------
  group('Sıralama', () {
    testWidgets('kendi sıram, podyum, liste dışındaki kendi satırım', (t) async {
      await pump(t, const V21LeaderboardScreen(), const Size(390, 844));
      expect(t.takeException(), isNull);
      expect(find.text('SIRALAMA'), findsWidgets);
      expect(find.text('ArenaMaster'), findsOneWidget);
      expect(find.text('9.'), findsWidgets);
      expect(find.textContaining('kupa sonra'), findsOneWidget);
      await t.scrollUntilVisible(find.text('OrtaSahaUstası'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('OrtaSahaUstası'), findsOneWidget);
      await unmount(t);
    });
  });

  group('Sandık olasılıkları', () {
    testWidgets('sunucudaki sürümün tabloları ve şanssızlık koruması', (t) async {
      await pump(t, const V21ChestOddsScreen(), const Size(390, 844));
      expect(t.takeException(), isNull);
      expect(find.textContaining('SÜRÜM'), findsOneWidget);
      expect(find.text('Galibiyet'), findsOneWidget);
      expect(find.textContaining('Şanssızlık koruması'), findsOneWidget);
      await unmount(t);
    });
  });

  group('Kadro kurma', () {
    testWidgets('boş kadroda gönderim kilitli', (t) async {
      await pump(t, V21SbcBuilderScreen(challenge: _challenge), const Size(390, 844));
      expect(t.takeException(), isNull);
      expect(find.text('KADRO TEMİZLİĞİ'), findsOneWidget);
      expect(find.text('0/11'), findsWidgets);
      await t.scrollUntilVisible(find.text('ŞARTLAR TAMAMLANMADI'), 200, scrollable: find.byType(Scrollable).first);
      await t.tap(find.text('ŞARTLAR TAMAMLANMADI'));
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text('KARTLAR ERİTİLSİN Mİ?'), findsNothing);
      expect(sbc.submitted, isEmpty);
      await unmount(t);
    });

    testWidgets('doldur → geri alınamaz onayı: VAZGEÇ göndermez, ERİT gönderir', (t) async {
      await pump(t, V21SbcBuilderScreen(challenge: _challenge), const Size(390, 844));
      await t.tap(find.text('EN DÜŞÜKLER'));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('11/11'), findsWidgets);

      final submit = find.text('KARTLARI ERİT VE ÖDÜLÜ AL');
      await t.scrollUntilVisible(submit, 200, scrollable: find.byType(Scrollable).first);
      await t.ensureVisible(submit);
      await t.pump();
      await t.tap(submit);
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text('KARTLAR ERİTİLSİN Mİ?'), findsOneWidget);
      expect(find.textContaining('GERİ ALINAMAZ'), findsWidgets);

      await t.tap(find.text('VAZGEÇ'));
      await t.pump(const Duration(milliseconds: 600));
      expect(sbc.submitted, isEmpty, reason: 'vazgeçince kart eritilmemeli');

      await t.tap(submit);
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      await t.tap(find.text('ERİT'));
      for (var i = 0; i < 8; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(sbc.submitted, hasLength(1));
      expect(sbc.submitted.single, hasLength(11));
      expect(find.text('GÖREV TAMAMLANDI'), findsOneWidget);
      await unmount(t);
    });
  });

  group('Maç sonu panelleri', () {
    testWidgets('sandık yuvası, gelişim kopyası, sezon XP, lig atlama', (t) async {
      await pump(t, panels(), const Size(390, 844));
      expect(t.takeException(), isNull);
      expect(find.text('SANDIK KAZANDIN'), findsOneWidget);
      expect(find.text('2. yuvaya kondu'), findsOneWidget);
      expect(find.text('+1 GELİŞİM KOPYASI'), findsOneWidget);
      expect(find.text('Efe Kaya'), findsOneWidget);
      expect(find.text('+100 SEZON XP'), findsOneWidget);
      expect(find.text('SEVİYE ATLADIN'), findsOneWidget);
      expect(find.text('+25'), findsOneWidget);
      await unmount(t);
    });

    testWidgets('enerji yok: sandık atlandı notu; XP yoksa satır yok', (t) async {
      await pump(
        t,
        const Scaffold(
          body: Column(
            children: [
              V21MatchChestPanel(
                matchId: 'm2',
                preview: SourceChest(skipped: 'no_energy'),
              ),
              V21MatchSeasonXpLine(matchId: 'm2', preview: MatchSeasonXp(xp: 0)),
            ],
          ),
        ),
        const Size(390, 844),
      );
      expect(find.text('SANDIK HAKKIN BİTMİŞTİ'), findsOneWidget);
      expect(find.textContaining('SEZON XP'), findsNothing);
      await unmount(t);
    });

    testWidgets('aynı basamak: şerit yok, ilerleme metni var', (t) async {
      await pump(t, const Scaffold(body: V21LeagueChangePanel(change: _same)), const Size(390, 844));
      expect(find.textContaining('ATLADIN'), findsNothing);
      expect(find.textContaining('kupa sonra'), findsOneWidget);
      await unmount(t);
    });

    testWidgets('terfi kutlaması: DEVAM kapatır', (t) async {
      var closed = false;
      await pump(
        t,
        V21LeaguePromotionOverlay(change: _promoted, onContinue: () => closed = true),
        const Size(390, 844),
      );
      expect(t.takeException(), isNull);
      expect(find.text('TERFİ!'), findsWidgets);
      expect(find.text('YENİ SEVİYE!'), findsOneWidget);
      await t.tap(find.text('DEVAM'));
      expect(closed, isTrue);
      await unmount(t);
    });
  });

  // ------------------------------------------------------------------
  group('Golden + duyarlılık', () {
    final screens = <String, Widget Function()>{
      'leaderboard': () => const V21LeaderboardScreen(),
      'chest_odds': () => const V21ChestOddsScreen(),
      'sbc_builder': () => V21SbcBuilderScreen(challenge: _challenge),
      'match_panels': panels,
      'promotion': () => V21LeaguePromotionOverlay(change: _promoted, onContinue: () {}),
    };
    for (final e in screens.entries) {
      for (final size in kV21Sizes) {
        testWidgets('${e.key} ${v21SizeName(size)}', (t) async {
          await pump(t, e.value(), size);
          expect(t.takeException(), isNull, reason: 'taşma olmamalı');
          if (skipGolden == null) {
            await expectLater(
              find.byKey(const Key('screen')),
              matchesGoldenFile('goldens/v21_${e.key}_${v21SizeName(size)}.png'),
            );
          }
          await unmount(t);
        });
      }
    }
  });
}
