import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/auth/session_manager.dart';
import 'package:futbol_card/core/network/websocket_service.dart';
import 'package:futbol_card/core/storage/token_storage.dart';
import 'package:futbol_card/core/utils/result.dart';
import 'package:futbol_card/features/match/domain/repositories/match_repository.dart';
import 'package:futbol_card/features/match/presentation/viewmodel/match_view_model.dart';
import 'package:shared_models/shared_models.dart';

/// FAZ 4 — Maç sonucu ekranı.
void main() {
  setUpAll(() => dotenv.loadFromString(envString: 'ENABLE_LOGGING=false'));

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


  group('MatchResultView', () {





  });

  // ==================================================================
  // FAZ 6 — LİG DEĞİŞİMİ (sunucunun 022 kaydı)
  // ==================================================================
  group('Lig değişimi', () {



  });
}

class _Repo implements MatchRepository {
  /// 039: seçilen mevkiler (testler okuyabilir)
  final secilenMevkiler = <CardPosition>[];

  @override
  Future<Result<Map<String, dynamic>>> choosePosition(String matchId, CardPosition position) async {
    secilenMevkiler.add(position);
    return const Success({'status': 'ok'});
  }

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

  // Her zaman bagli: kopma senaryolari match_view_model_test'te.
  @override
  Stream<bool> get connectionState => const Stream<bool>.empty();
  @override
  bool get isConnected => true;
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
