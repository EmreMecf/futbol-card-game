import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/auth/session_manager.dart';
import 'package:futbol_card/core/network/websocket_service.dart';
import 'package:futbol_card/core/storage/token_storage.dart';
import 'package:futbol_card/core/theme/app_theme.dart';
import 'package:futbol_card/core/utils/result.dart';
import 'package:futbol_card/features/match/domain/repositories/match_repository.dart';
import 'package:futbol_card/features/match/presentation/viewmodel/match_view_model.dart';
import 'package:futbol_card/features/match/presentation/widgets/league_change_widgets.dart';
import 'package:futbol_card/features/match/presentation/widgets/match_result_view.dart';
import 'package:shared_models/shared_models.dart';

/// FAZ 4 — Maç sonucu ekranı.
void main() {
  setUpAll(() => dotenv.loadFromString(envString: 'ENABLE_LOGGING=false'));

  InventoryCard kart(String id, CardTier t) => InventoryCard(
        userCardId: id,
        cardId: 'c$id',
        fullName: 'Oyuncu $id',
        position: CardPosition.defender,
        tier: t,
        power: 70,
      );

  // ==================================================================
  // ÖDÜL FARKI — iki sayı da sunucudan
  // ==================================================================
  group('MatchViewModel.rewardDelta', () {
    test('maç öncesi oturum ile sunucunun yeni profili arasındaki fark',
        () async {
      final oturum = SessionManager(_Depo());
      await oturum.updateUser(const UserModel(
        id: 'u-1',
        username: 'Ben',
        coins: 1000,
        mmr: 1500,
        protectionSlots: 3,
      ));

      final repo = _Repo()
        ..sonuc = const MatchResultSummary(
          matchId: 'm',
          didIWin: true,
          myProfile: UserModel(
            id: 'u-1',
            username: 'Ben',
            coins: 1100,
            mmr: 1525,
            protectionSlots: 4,
          ),
        );
      final vm = MatchViewModel(repo, _Soket(), oturum, matchId: 'm');
      await vm.initialize();

      final d = vm.rewardDelta!;
      expect(d.coins, 100);
      expect(d.rating, 25);
      expect(d.protectionSlots, 1);
      // Oturum da güncellendi
      expect(oturum.user!.mmr, 1525);
      vm.dispose();
    });

    test('maç öncesi profil bilinmiyorsa fark YOK (yanlış +0 yazılmaz)',
        () async {
      final repo = _Repo()
        ..sonuc = const MatchResultSummary(
          matchId: 'm',
          myProfile: UserModel(id: 'u-1', username: 'Ben', mmr: 1475),
        );
      final vm = MatchViewModel(repo, _Soket(), SessionManager(_Depo()),
          matchId: 'm');
      await vm.initialize();

      expect(vm.rewardDelta, isNull);
      vm.dispose();
    });
  });

  // ==================================================================
  // EKRAN
  // ==================================================================
  Future<void> ac(WidgetTester tester, MatchResultView ekran) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: ekran));
    await tester.pump(const Duration(milliseconds: 700));
  }

  group('MatchResultView', () {
    testWidgets('zafer: başlık, skor, ödüller ve kazanılan kartlar',
        (tester) async {
      await ac(
        tester,
        MatchResultView(
          result: MatchResultSummary(
            matchId: 'm',
            didIWin: true,
            myScore: 7,
            opponentScore: 4,
            opponent: const OpponentInfo(id: 'o', username: 'StormFC'),
            cardsWon: [kart('1', CardTier.gold), kart('2', CardTier.silver)],
          ),
          rewardDelta: const MatchRewardDelta(
            coins: 100,
            rating: 25,
            protectionSlots: 1,
          ),
          onClose: () {},
          onNewMatch: () {},
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('ZAFER!'), findsOneWidget);
      expect(find.text('7 – 4'), findsOneWidget);
      expect(find.text('+100'), findsOneWidget);
      expect(find.text('+25'), findsOneWidget);
      expect(find.text('+1'), findsOneWidget);
      expect(find.text('Kazandığın kartlar (2)'), findsOneWidget);
      expect(find.text('YENİ MAÇ'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('mağlubiyet: kaybedilen kartlar ve eksi puan', (tester) async {
      await ac(
        tester,
        MatchResultView(
          result: MatchResultSummary(
            matchId: 'm',
            myScore: 3,
            opponentScore: 8,
            cardsLost: [
              kart('1', CardTier.gold),
              kart('2', CardTier.silver),
              kart('3', CardTier.bronze),
            ],
          ),
          rewardDelta: const MatchRewardDelta(
            coins: 0,
            rating: -25,
            protectionSlots: 0,
          ),
          onClose: () {},
        ),
      );

      expect(find.text('MAĞLUBİYET'), findsOneWidget);
      expect(find.text('3 kartını kalıcı olarak kaptırdın.'), findsOneWidget);
      expect(find.text('-25'), findsOneWidget);
      expect(find.text('Kaybettiğin kartlar (3)'), findsOneWidget);
      expect(find.text('YENİ MAÇ'), findsNothing,
          reason: 'onNewMatch verilmediyse buton yok');
    });

    testWidgets('beraberlik', (tester) async {
      await ac(
        tester,
        MatchResultView(
          result: const MatchResultSummary(matchId: 'm', isDraw: true),
          onClose: () {},
        ),
      );
      expect(find.text('BERABERLİK'), findsOneWidget);
      expect(find.text('Beraberlikte kimse kart kaybetmez.'), findsOneWidget);
    });

    testWidgets('fark bilinmiyorsa ödül kutuları hiç çizilmez',
        (tester) async {
      await ac(
        tester,
        MatchResultView(
          result: const MatchResultSummary(matchId: 'm', didIWin: true),
          onClose: () {},
        ),
      );
      expect(find.text('Coin'), findsNothing);
      expect(find.text('Puan'), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('sonuç gelene kadar yükleniyor', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        home: MatchResultView(result: null, onClose: () {}),
      ));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('butonlar çalışır', (tester) async {
      var anaSayfa = 0, yeniMac = 0;
      await ac(
        tester,
        MatchResultView(
          result: const MatchResultSummary(matchId: 'm', isDraw: true),
          onClose: () => anaSayfa++,
          onNewMatch: () => yeniMac++,
        ),
      );
      await tester.tap(find.text('YENİ MAÇ'));
      await tester.tap(find.text('ANA SAYFA'));
      expect(yeniMac, 1);
      expect(anaSayfa, 1);
    });
  });

  // ==================================================================
  // FAZ 6 — LİG DEĞİŞİMİ (sunucunun 022 kaydı)
  // ==================================================================
  PlayerRank rank(String kod, String ad, int seviye, int tier, int mmr,
          {double ilerleme = 0.2, String? sonrakiAd, int? sonrakiSeviye}) =>
      PlayerRank(
        mmr: mmr,
        tierId: tier,
        leagueCode: kod,
        leagueName: ad,
        division: seviye,
        color: '#22D3EE',
        progress: ilerleme,
        nextTierMmr: mmr + 80,
        nextLeagueName: sonrakiAd ?? ad,
        nextDivision: sonrakiSeviye ?? seviye + 1,
      );

  MatchLeagueChange degisim(String yon) => switch (yon) {
        'promoted' => MatchLeagueChange(
            mmrBefore: 1290,
            mmrAfter: 1315,
            mmrDelta: 25,
            rankBefore: rank('amateur', 'Amatör', 3, 3, 1290, ilerleme: 0.9),
            rankAfter: rank('usta', 'Usta', 1, 4, 1315, ilerleme: 0.15),
            direction: 'promoted',
          ),
        'demoted' => MatchLeagueChange(
            mmrBefore: 1305,
            mmrAfter: 1280,
            mmrDelta: -25,
            rankBefore: rank('usta', 'Usta', 1, 4, 1305, ilerleme: 0.05),
            rankAfter: rank('amateur', 'Amatör', 3, 3, 1280, ilerleme: 0.8),
            direction: 'demoted',
          ),
        _ => MatchLeagueChange(
            mmrBefore: 1400,
            mmrAfter: 1425,
            mmrDelta: 25,
            rankBefore: rank('usta', 'Usta', 2, 5, 1400, ilerleme: 0),
            rankAfter: rank('usta', 'Usta', 2, 5, 1425, ilerleme: 0.25),
          ),
      };

  group('Lig değişimi', () {
    testWidgets('yükselme: lig atlama ekranı, Devam ile kapanır',
        (tester) async {
      await ac(
        tester,
        MatchResultView(
          result: MatchResultSummary(
            matchId: 'm',
            didIWin: true,
            leagueChange: degisim('promoted'),
          ),
          onClose: () {},
        ),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(tester.takeException(), isNull);
      expect(find.text('LİG ATLADIN!'), findsOneWidget);
      expect(find.text('USTA 1'), findsOneWidget);

      await tester.tap(find.text('DEVAM'));
      await tester.pumpAndSettle();

      expect(find.text('LİG ATLADIN!'), findsNothing,
          reason: 'Ekran bir kez gösterilir');
      // Panel: değişim şeridi ve yeni lig
      expect(find.text('LİG ATLADIN'), findsOneWidget);
      expect(find.text('Amatör 3'), findsWidgets);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsWidgets);
      expect(find.text('1315 puan'), findsOneWidget);
    });

    testWidgets('aynı basamakta: atlama ekranı yok, hedef yazılır',
        (tester) async {
      await ac(
        tester,
        MatchResultView(
          result: MatchResultSummary(
            matchId: 'm',
            didIWin: true,
            leagueChange: degisim('same'),
          ),
          onClose: () {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LeaguePromotionOverlay), findsNothing);
      expect(find.text('Usta 2'), findsWidgets);
      expect(find.text('Usta 3 için 4 galibiyet (80 puan).'), findsOneWidget);
    });

    testWidgets('düşüş: "SEVİYE DÜŞTÜ", kutlama yok', (tester) async {
      await ac(
        tester,
        MatchResultView(
          result: MatchResultSummary(
            matchId: 'm',
            myScore: 2,
            opponentScore: 9,
            leagueChange: degisim('demoted'),
          ),
          onClose: () {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LeaguePromotionOverlay), findsNothing);
      expect(find.text('SEVİYE DÜŞTÜ'), findsOneWidget);
      expect(find.text('-25'), findsOneWidget);
    });

    testWidgets('sunucu kaydı yoksa lig bölümü hiç çizilmez', (tester) async {
      await ac(
        tester,
        MatchResultView(
          result: const MatchResultSummary(matchId: 'm', didIWin: true),
          onClose: () {},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LeagueChangePanel), findsNothing);
    });
  });
}

class _Repo implements MatchRepository {
  MatchResultSummary? sonuc;

  @override
  Future<Result<MatchState>> fetchState(String matchId) async => Success(
        MatchState(
          matchId: matchId,
          status: MatchStatus.finished,
          roundNumber: 11,
          serverTime: DateTime.now(),
        ),
      );

  @override
  Future<Result<List<HandCard>>> fetchHand(String matchId) async =>
      const Success([]);

  @override
  Future<Result<MatchHistory>> fetchHistory(String matchId) async =>
      const Success(MatchHistory());

  @override
  Future<Result<MatchResultSummary>> fetchResult(String matchId) async =>
      Success(sonuc!);

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _Soket implements WebSocketService {
  @override
  Stream<RealtimeEvent> get events => const Stream<RealtimeEvent>.empty();

  @override
  dynamic noSuchMethod(Invocation i) => null;
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
