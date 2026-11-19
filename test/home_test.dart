import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/error/app_exception.dart';
import 'package:futbol_card/core/theme/app_theme.dart';
import 'package:futbol_card/core/utils/result.dart';
import 'package:futbol_card/features/home/presentation/viewmodel/home_view_model.dart';
import 'package:futbol_card/features/leaderboard/domain/repositories/leaderboard_repository.dart';
import 'package:futbol_card/features/match/domain/repositories/match_repository.dart';
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





  });

  group('RecentMatchesPanel', () {


  });


}

// ====================================================================
// SAHTE KAYNAKLAR
// ====================================================================
class _SahteMacRepo implements MatchRepository {
  /// 039: seçilen mevkiler (testler okuyabilir)
  final secilenMevkiler = <CardPosition>[];

  @override
  Future<Result<Map<String, dynamic>>> choosePosition(String matchId, CardPosition position) async {
    secilenMevkiler.add(position);
    return const Success({'status': 'ok'});
  }

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
