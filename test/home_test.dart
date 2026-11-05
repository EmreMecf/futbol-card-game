import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/error/app_exception.dart';
import 'package:futbol_card/core/theme/app_theme.dart';
import 'package:futbol_card/core/utils/result.dart';
import 'package:futbol_card/features/home/presentation/viewmodel/home_view_model.dart';
import 'package:futbol_card/features/home/presentation/widgets/home_panels.dart';
import 'package:futbol_card/features/leaderboard/domain/repositories/leaderboard_repository.dart';
import 'package:futbol_card/features/match/domain/repositories/match_repository.dart';
import 'package:futbol_card/shared/widgets/game/game_ui.dart';
import 'package:shared_models/shared_models.dart';

/// FAZ 3 — Ana sayfa.
///
/// Ana sayfadaki her sayı sunucudan geliyor. Bu testler:
///   * galibiyet serisinin doğru hesaplandığını,
///   * bir istek başarısız olsa bile ekranın açıldığını,
///   * sunucuda olmayan şeylerin (günlük görev, sezon) SAHTE sayıyla
///     gösterilmediğini
/// kilitliyor.
void main() {
  MatchHistoryEntry mac(MatchOutcome sonuc,
          {String rakip = 'Rakip', int benim = 6, int onun = 4, int alinan = 0}) =>
      MatchHistoryEntry(
        matchId: 'm-$rakip-${sonuc.name}-$benim$onun',
        opponentId: 'o1',
        opponentUsername: rakip,
        myScore: benim,
        opponentScore: onun,
        outcome: sonuc,
        cardsWon: alinan,
      );

  const rutbe = PlayerRank(
    mmr: 1825,
    tierId: 5,
    leagueCode: 'usta',
    leagueName: 'Usta',
    division: 2,
    color: '#3BAAFA',
    tierMinMmr: 1800,
    nextTierMmr: 1900,
    nextLeagueName: 'Usta',
    nextDivision: 3,
    progress: 0.25,
  );

  // ==================================================================
  // VIEWMODEL
  // ==================================================================
  group('HomeViewModel', () {
    test('seri: en yeni maçtan geriye kesintisiz galibiyetler', () async {
      final mr = _SahteMacRepo()
        ..gecmis = [
          mac(MatchOutcome.win),
          mac(MatchOutcome.win),
          mac(MatchOutcome.win),
          mac(MatchOutcome.loss), // seri burada biter
          mac(MatchOutcome.win),
        ];
      final vm = HomeViewModel(_SahteLigRepo()..rutbe = rutbe, mr);
      await vm.load();

      expect(vm.winStreak, 3);
      expect(vm.isStreakCapped, isFalse);
    });

    test('son maç beraberlikse seri sıfır', () async {
      final mr = _SahteMacRepo()
        ..gecmis = [mac(MatchOutcome.draw), mac(MatchOutcome.win)];
      final vm = HomeViewModel(_SahteLigRepo(), mr);
      await vm.load();
      expect(vm.winStreak, 0);
    });

    test('pencere tamamen galibiyetse seri "10+" sayılır', () async {
      final mr = _SahteMacRepo()
        ..gecmis = List.generate(10, (_) => mac(MatchOutcome.win));
      final vm = HomeViewModel(_SahteLigRepo(), mr);
      await vm.load();
      expect(vm.winStreak, 10);
      expect(vm.isStreakCapped, isTrue);
    });

    test('ana sayfada en fazla 3 son maç gösterilir', () async {
      final mr = _SahteMacRepo()
        ..gecmis = List.generate(8, (i) => mac(MatchOutcome.win, rakip: 'R$i'));
      final vm = HomeViewModel(_SahteLigRepo(), mr);
      await vm.load();

      expect(vm.recentMatches, hasLength(HomeViewModel.recentMatchCount));
      expect(vm.recentMatches.first.opponentUsername, 'R0',
          reason: 'En yeni maç en üstte');
    });

    test('rütbe yüklenemezse geçmiş YİNE gelir, ekran açılır', () async {
      final mr = _SahteMacRepo()..gecmis = [mac(MatchOutcome.win)];
      final vm = HomeViewModel(_SahteLigRepo(), mr); // rütbe yok -> hata
      await vm.load();

      expect(vm.isLoaded, isTrue);
      expect(vm.rank, isNull);
      expect(vm.recentMatches, hasLength(1));
    });

    test('ikisi de başarısız olsa bile yükleme biter (sonsuz spinner yok)',
        () async {
      final vm = HomeViewModel(
        _SahteLigRepo(),
        _SahteMacRepo()..hata = 'Sunucu kapalı',
      );
      await vm.load();
      expect(vm.isLoaded, isTrue);
      expect(vm.recentMatches, isEmpty);
    });

    test('maç geçmişi istenirken seri penceresi kadar istenir', () async {
      final mr = _SahteMacRepo();
      await HomeViewModel(_SahteLigRepo(), mr).load();
      expect(mr.istenenLimit, 10);
    });
  });

  // ==================================================================
  // PANELLER
  // ==================================================================
  Widget sarmala(Widget c) => MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: c,
          ),
        ),
      );

  const kullanici = UserModel(
    id: 'u1',
    username: 'Emre',
    mmr: 1825,
    coins: 2450,
  );

  group('ArenaHeroPanel', () {
    testWidgets('kupa (MMR) binlik ayraçla, lig ve ilerleme gerçek veriden',
        (tester) async {
      await tester.pumpWidget(sarmala(const ArenaHeroPanel(
        user: kullanici,
        rank: rutbe,
        winStreak: 0,
      )));
      await tester.pumpAndSettle();

      expect(find.text('1.825'), findsOneWidget);
      expect(find.text('USTA 2'), findsOneWidget);
      // 75 puan / 25 = 3 galibiyet
      expect(find.text('Usta 3 için 3 galibiyet'), findsOneWidget);
      expect(find.byType(GameButton), findsOneWidget);
      expect(find.text('MAÇA BAŞLA'), findsOneWidget);
    });

    testWidgets('seri 2 ve üstündeyse rozet görünür', (tester) async {
      await tester.pumpWidget(sarmala(const ArenaHeroPanel(
        user: kullanici,
        rank: rutbe,
        winStreak: 4,
      )));
      expect(find.text('4 galibiyet serisi'), findsOneWidget);
    });

    testWidgets('tek galibiyet "seri" sayılmaz', (tester) async {
      await tester.pumpWidget(sarmala(const ArenaHeroPanel(
        user: kullanici,
        rank: rutbe,
        winStreak: 1,
      )));
      expect(find.textContaining('serisi'), findsNothing);
    });

    testWidgets('rütbe gelmeden de çizilir, buton çalışır durumda',
        (tester) async {
      await tester.pumpWidget(sarmala(const ArenaHeroPanel(
        user: kullanici,
        rank: null,
        winStreak: 0,
      )));
      expect(tester.takeException(), isNull);
      expect(find.text('MAÇA BAŞLA'), findsOneWidget);
    });

    testWidgets('en üst basamakta "en üst" yazar', (tester) async {
      await tester.pumpWidget(sarmala(ArenaHeroPanel(
        user: kullanici,
        rank: rutbe.copyWith(isTopTier: true, nextTierMmr: null),
        winStreak: 0,
      )));
      expect(find.text('En üst basamaktasın'), findsOneWidget);
    });

    testWidgets('dar telefonda (320 px) taşmaz', (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(sarmala(const ArenaHeroPanel(
        user: kullanici,
        rank: rutbe,
        winStreak: 12,
        isStreakCapped: true,
      )));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('12+ galibiyet serisi'), findsOneWidget);
    });
  });

  group('RecentMatchesPanel', () {
    testWidgets('boşsa açıklayıcı mesaj', (tester) async {
      await tester.pumpWidget(
        sarmala(const RecentMatchesPanel(matches: [], isLoaded: true)),
      );
      expect(find.textContaining('Henüz maç oynamadın'), findsOneWidget);
    });

    testWidgets('sonuç harfi, rakip, skor ve kart hareketi', (tester) async {
      await tester.pumpWidget(sarmala(RecentMatchesPanel(
        matches: [
          mac(MatchOutcome.win, rakip: 'StormFC', benim: 7, onun: 4, alinan: 3),
          mac(MatchOutcome.loss, rakip: 'Taktik', benim: 3, onun: 8),
        ],
        isLoaded: true,
      )));

      expect(find.text('G'), findsOneWidget);
      expect(find.text('M'), findsOneWidget);
      expect(find.text('vs StormFC'), findsOneWidget);
      expect(find.text('7 - 4'), findsOneWidget);
      expect(find.text('3 kart aldın'), findsOneWidget);
    });

    testWidgets('yüklenirken gösterge', (tester) async {
      await tester.pumpWidget(
        sarmala(const RecentMatchesPanel(matches: [], isLoaded: false)),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('ComingSoonPanel — sahte veri YOK', () {
    testWidgets('görev ve sezon "YAKINDA" olarak işaretli', (tester) async {
      await tester.pumpWidget(sarmala(const ComingSoonPanel()));

      expect(find.text('YAKINDA'), findsNWidgets(2));
      expect(find.text('Günlük görevler'), findsOneWidget);
      expect(find.text('Sezon yolu'), findsOneWidget);
    });

    testWidgets('içinde uydurma ilerleme / sayı yok', (tester) async {
      // MD kural 11: geçici sahte veri ile gerçek veri karışmamalı.
      // Prototipteki "2/3", "12 / 20" gibi değerler burada olmamalı.
      await tester.pumpWidget(sarmala(const ComingSoonPanel()));

      expect(find.byType(GameProgressBar), findsNothing);
      expect(find.textContaining(RegExp(r'\d+\s*/\s*\d+')), findsNothing);
    });
  });

  test('binlik ayracı Türkçe', () {
    expect(formatThousands(1825), '1.825');
    expect(formatThousands(999), '999');
    expect(formatThousands(1000000), '1.000.000');
    expect(formatThousands(-2450), '-2.450');
  });
}

// ====================================================================
// SAHTE KAYNAKLAR
// ====================================================================
class _SahteMacRepo implements MatchRepository {
  List<MatchHistoryEntry> gecmis = const [];
  String? hata;
  int? istenenLimit;

  @override
  Future<Result<List<MatchHistoryEntry>>> fetchMatchHistoryList({
    int limit = 20,
    int offset = 0,
  }) async {
    istenenLimit = limit;
    final h = hata;
    if (h != null) return Failure(AppException(message: h));
    return Success(gecmis);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Bu test için gerekmiyor');
}

class _SahteLigRepo implements LeaderboardRepository {
  PlayerRank? rutbe;

  @override
  Future<Result<PlayerRank>> fetchMyRank() async {
    final r = rutbe;
    if (r == null) return const Failure(AppException(message: 'Yok'));
    return Success(r);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Bu test için gerekmiyor');
}
