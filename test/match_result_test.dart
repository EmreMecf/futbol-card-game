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
