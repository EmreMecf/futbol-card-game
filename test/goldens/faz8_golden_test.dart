import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/auth/session_manager.dart';
import 'package:futbol_card/core/di/injection.dart';
import 'package:futbol_card/core/theme/app_theme.dart';
import 'package:futbol_card/features/auth/presentation/view/login_view.dart';
import 'package:futbol_card/features/auth/presentation/view/register_view.dart';
import 'package:futbol_card/features/auth/presentation/viewmodel/auth_view_model.dart';
import 'package:futbol_card/features/match/presentation/viewmodel/match_view_model.dart';
import 'package:futbol_card/features/match/presentation/widgets/match_result_view.dart';
import 'package:futbol_card/features/settings/presentation/viewmodel/settings_view_model.dart';
import 'package:futbol_card/features/settings/presentation/view/settings_view.dart';
import 'package:futbol_card/shared/widgets/walkout/walkout.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'golden_araclari.dart';
import 'sahte_veri.dart';

/// FAZ 8 — referansta karşılığı olmayan, eski paletten yeni dile
/// geçirilen ekranlar: giriş, kayıt, ayarlar, lig atlama, walkout.
void main() {
  final atla = goldenSkipReason;
  late SessionManager oturum;

  setUpAll(() async {
    dotenv.loadFromString(envString: 'ENABLE_LOGGING=false');
    if (atla == null) await loadGoldenFonts();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    oturum = await goldenSession();
    final ayar = SettingsViewModel();
    await ayar.load();
    getIt.registerSingleton<SettingsViewModel>(ayar);

    // Walkout kartı telefonun jiroskopunu dinler; test ortamında bu
    // eklenti yok. Boş (hiç olay göndermeyen) sahte kanal.
    final ileti = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    ileti.setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/sensors/method'), (_) async => null);
    ileti.setMockStreamHandler(
      const EventChannel('dev.fluttercommunity.plus/sensors/gyroscope'),
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
  });

  Future<void> ac(WidgetTester t, Widget ekran, Size boyut, {int kare = 8}) async {
    t.view.physicalSize = boyut;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionManager>.value(value: oturum),
        ChangeNotifierProvider<AuthViewModel>(create: (_) => AuthViewModel(GoldenAuthRepo())),
      ],
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

  PlayerRank rutbe(String kod, String ad, int seviye, int id, int puan, double ilerleme) => PlayerRank(
        mmr: puan,
        tierId: id,
        leagueCode: kod,
        leagueName: ad,
        division: seviye,
        color: kod == 'usta' ? '#2DD4BF' : '#7C8DA6',
        tierMinMmr: puan - 20,
        nextTierMmr: puan + 80,
        nextLeagueName: ad,
        nextDivision: seviye + 1,
        progress: ilerleme,
      );

  final yukselme = MatchLeagueChange(
    mmrBefore: 1290,
    mmrAfter: 1315,
    mmrDelta: 25,
    rankBefore: rutbe('amateur', 'Amatör', 3, 3, 1290, 0.9),
    rankAfter: rutbe('usta', 'Usta', 1, 4, 1315, 0.15),
    direction: 'promoted',
  );

  Widget macSonucu() => MatchResultView(
        result: MatchResultSummary(
          matchId: 'm',
          didIWin: true,
          myScore: 6,
          opponentScore: 4,
          opponent: const OpponentInfo(id: 'o', username: 'StormFC'),
          leagueChange: yukselme,
        ),
        rewardDelta: const MatchRewardDelta(coins: 150, rating: 25, protectionSlots: 0),
        onClose: () {},
        onNewMatch: () {},
      );

  final ekranlar = <String, Widget Function()>{
    '11_giris': () => const LoginView(),
    '11k_kayit': () => const RegisterView(),
    '12_ayarlar': () => const SettingsView(),
  };

  for (final e in ekranlar.entries) {
    for (final boyut in kGoldenSizes) {
      testWidgets('${e.key} ${sizeName(boyut)} taşmaz', (t) async {
        await ac(t, e.value(), boyut);
        expect(t.takeException(), isNull, reason: 'taşma veya çizim hatası');
        await esle(t, '${e.key}_${sizeName(boyut)}');
      }, skip: atla != null);
    }
  }

  for (final boyut in kGoldenSizes) {
    testWidgets('13 lig atlama ${sizeName(boyut)} taşmaz', (t) async {
      await ac(t, macSonucu(), boyut, kare: 20);
      expect(t.takeException(), isNull);
      expect(find.text('LİG ATLADIN!'), findsOneWidget);
      await esle(t, '13_lig_atlama_${sizeName(boyut)}');

      // Kutlama kapanınca maç sonucundaki lig paneli
      await t.tap(find.text('DEVAM'));
      for (var i = 0; i < 12; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(t.takeException(), isNull);
      await esle(t, '13p_lig_paneli_${sizeName(boyut)}');
    }, skip: atla != null);
  }

  for (final boyut in kGoldenSizes) {
    testWidgets('14 walkout ${sizeName(boyut)} taşmaz', (t) async {
      // Sahnenin sonu (kart ve DEVAM görünür): kare kare ilerlet,
      // sürekli ışık salınımı yüzünden pumpAndSettle kullanılamaz.
      await ac(t, WalkoutScreen(card: kGoldenCards[0], onContinue: () {}), boyut, kare: 80);
      expect(t.takeException(), isNull);
      await esle(t, '14_walkout_${sizeName(boyut)}');
    }, skip: atla != null);
  }
}
