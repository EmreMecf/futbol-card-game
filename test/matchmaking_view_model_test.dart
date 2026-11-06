import 'dart:async';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/auth/session_manager.dart';
import 'package:futbol_card/core/error/app_exception.dart';
import 'package:futbol_card/core/network/websocket_service.dart';
import 'package:futbol_card/core/storage/token_storage.dart';
import 'package:futbol_card/core/utils/result.dart';
import 'package:futbol_card/features/matchmaking/domain/repositories/matchmaking_repository.dart';
import 'package:futbol_card/features/matchmaking/presentation/viewmodel/matchmaking_view_model.dart';
import 'package:shared_models/shared_models.dart';

/// FAZ 7 — Eşleştirme akışı (kalite kontrolde %0 kapsamla bulundu).
///
/// Eşleşme İKİ kanaldan gelebiliyor (WebSocket + 4 sn'lik yoklama).
/// En önemli güvence: aynı maç iki kanaldan da bildirilse bile oyuncu
/// maça BİR KEZ girer ve kuyrukta kalmaz.
void main() {
  setUpAll(() => dotenv.loadFromString(envString: 'ENABLE_LOGGING=false'));

  late _Repo repo;
  late _Soket soket;
  late SessionManager oturum;
  late MatchmakingViewModel vm;

  InventoryCard kart(String id, CardTier t, int g) => InventoryCard(
        userCardId: id,
        cardId: 'c$id',
        fullName: 'Oyuncu $id',
        position: CardPosition.defender,
        tier: t,
        power: g,
      );

  setUp(() async {
    // Test verisi: 3 kartlık kadro
    repoKartlari = [
      kart('1', CardTier.gold, 85),
      kart('2', CardTier.gold, 80),
      kart('3', CardTier.legend, 70),
    ];
    repo = _Repo();
    soket = _Soket();
    oturum = SessionManager(_Depo());
    await oturum.updateUser(
        const UserModel(id: 'u', username: 'Ben', protectionSlots: 2));
    vm = MatchmakingViewModel(repo, soket, oturum);
  });

  tearDown(() async {
    vm.dispose();
    await soket.kapat();
  });

  group('Hazırlık', () {
    test('yarım kalmış maç varsa doğrudan oraya gidilir', () async {
      repo.aktifMac = 'eski-mac';
      await vm.initialize();

      expect(vm.stage, MatchmakingStage.found);
      expect(vm.foundMatchId, 'eski-mac');
      expect(repo.desteIstegi, 0, reason: 'Kadro yüklemeye gerek yok');
    });

    test('aktif kadro seçilir, doğrulanır ve aranabilir olur', () async {
      await vm.initialize();

      expect(vm.selectedDeck?.id, 'd2', reason: 'isActive olan seçilmeli');
      expect(vm.deckCards, hasLength(3));
      expect(vm.canSearch, isTrue);
    });

    test('geçersiz kadroyla arama yapılamaz', () async {
      repo.gecerli = false;
      await vm.initialize();
      expect(vm.canSearch, isFalse);
    });

    test('koruma hakkı sınırı aşılamaz', () async {
      await vm.initialize();
      vm.toggleProtection('1');
      vm.toggleProtection('2');
      vm.toggleProtection('3'); // hak 2
      expect(vm.protectedCardIds, {'1', '2'});

      vm.toggleProtection('1'); // geri al
      expect(vm.protectedCardIds, {'2'});
    });

    test('otomatik koruma en değerli kartları seçer', () async {
      await vm.initialize();
      vm.autoProtectBest();
      // 3: Legend, 1: Altın 85 > 2: Altın 80
      expect(vm.protectedCardIds, {'3', '1'});
    });
  });

  group('Arama', () {
    test('sunucu hemen eşleştirirse maça geçilir', () async {
      repo.bulSonucu = const MatchFindResult(
          status: MatchmakingStatus.matched, matchId: 'm1');
      await vm.initialize();
      await vm.startSearch();

      expect(vm.stage, MatchmakingStage.found);
      expect(vm.foundMatchId, 'm1');
    });

    test('korunan kartlar sunucuya gönderilir', () async {
      await vm.initialize();
      vm.toggleProtection('3');
      await vm.startSearch();
      expect(repo.gonderilenKoruma, ['3']);
    });

    test('sunucu hata verirse hazırlığa dönülür', () async {
      repo.bulHatasi = 'Kadro gecersiz.';
      await vm.initialize();
      await vm.startSearch();

      expect(vm.stage, MatchmakingStage.preparing);
      expect(vm.errorMessage, 'Kadro gecersiz.');
    });

    test('WebSocket bildirimiyle maç bulunur', () async {
      await vm.initialize();
      await vm.startSearch();
      expect(vm.stage, MatchmakingStage.searching);

      soket.yayinla(const RealtimeEvent(
          type: RealtimeEventType.queueUpdated, matchId: 'm-ws'));
      await Future<void>.delayed(Duration.zero);

      expect(vm.stage, MatchmakingStage.found);
      expect(vm.foundMatchId, 'm-ws');
    });

    test('iki kanaldan aynı anda gelse bile maça BİR KEZ girilir', () async {
      await vm.initialize();
      await vm.startSearch();

      var bildirim = 0;
      vm.addListener(() {
        if (vm.stage == MatchmakingStage.found) bildirim++;
      });

      soket.yayinla(const RealtimeEvent(
          type: RealtimeEventType.queueUpdated, matchId: 'm-ilk'));
      soket.yayinla(const RealtimeEvent(
          type: RealtimeEventType.queueUpdated, matchId: 'm-ikinci'));
      await Future<void>.delayed(Duration.zero);

      expect(vm.foundMatchId, 'm-ilk', reason: 'İlk gelen geçerli');
      expect(bildirim, 1);
    });

    // testWidgets: zamanlayıcılar Flutter'ın SAHTE saatinde çalışır,
    // 4 saniyelik yoklamayı gerçekten beklemeden ilerletebiliyoruz.
    // (Ayrı bir fake_async bağımlılığı eklememek için.)
    testWidgets('WebSocket koparsa yoklama maçı yakalar', (t) async {
      await vm.initialize();
      await vm.startSearch();
      expect(vm.stage, MatchmakingStage.searching);

      // Bildirim hiç gelmiyor; sunucu sonraki yoklamada eşleştiriyor
      repo.bulSonucu = const MatchFindResult(
          status: MatchmakingStatus.matched, matchId: 'm-yoklama');
      await t.pump(GameRules.matchmakingPollInterval);

      expect(vm.stage, MatchmakingStage.found);
      expect(vm.foundMatchId, 'm-yoklama');

      // Maç bulunduktan sonra yoklama DURUR (sunucuyu boşuna yormaz)
      final sayi = repo.bulIstegi;
      await t.pump(GameRules.matchmakingPollInterval * 3);
      expect(repo.bulIstegi, sayi);
    });

    testWidgets('iptal: hazırlığa dönülür ve yoklama durur', (t) async {
      await vm.initialize();
      await vm.startSearch();

      await vm.cancelSearch();
      expect(vm.stage, MatchmakingStage.preparing);

      final sayi = repo.bulIstegi;
      await t.pump(GameRules.matchmakingPollInterval * 3);
      expect(repo.bulIstegi, sayi);
    });

    test('iptal ederken eşleşme olmuşsa maça girilir', () async {
      await vm.initialize();
      await vm.startSearch();

      repo.iptalSonucu = const MatchFindResult(
          status: MatchmakingStatus.inMatch, matchId: 'm-son-an');
      await vm.cancelSearch();

      expect(vm.stage, MatchmakingStage.found);
      expect(vm.foundMatchId, 'm-son-an');
    });

    test('maça geçildikten sonra ekran sıfırlanır', () async {
      repo.bulSonucu = const MatchFindResult(
          status: MatchmakingStatus.matched, matchId: 'm1');
      await vm.initialize();
      await vm.startSearch();

      vm.consumeFoundMatch();
      expect(vm.foundMatchId, isNull);
      expect(vm.stage, MatchmakingStage.preparing);
      expect(vm.searchDuration, Duration.zero);
    });
  });
}

late List<InventoryCard> repoKartlari;

class _Repo implements MatchmakingRepository {
  String? aktifMac;
  bool gecerli = true;
  MatchFindResult bulSonucu =
      const MatchFindResult(status: MatchmakingStatus.queued);
  MatchFindResult iptalSonucu =
      const MatchFindResult(status: MatchmakingStatus.cancelled);
  String? bulHatasi;

  int desteIstegi = 0;
  int bulIstegi = 0;
  List<String>? gonderilenKoruma;

  @override
  Future<Result<String?>> activeMatchId() async => Success(aktifMac);

  @override
  Future<Result<List<DeckSummary>>> fetchDecks() async {
    desteIstegi++;
    return const Success([
      DeckSummary(id: 'd1', name: 'Yedek'),
      DeckSummary(id: 'd2', name: 'Ana kadro', isActive: true, cardCount: 11),
    ]);
  }

  @override
  Future<Result<List<InventoryCard>>> fetchDeckCards(String deckId) async =>
      Success(repoKartlari);

  @override
  Future<Result<DeckValidation>> validateDeck(String deckId) async =>
      Success(DeckValidation(isValid: gecerli));

  @override
  Future<Result<MatchFindResult>> findMatch({
    required String deckId,
    List<String> protectedCardIds = const [],
  }) async {
    bulIstegi++;
    gonderilenKoruma = protectedCardIds;
    if (bulHatasi != null) {
      return Failure(
          AppException(message: bulHatasi!, type: AppErrorType.gameRule));
    }
    return Success(bulSonucu);
  }

  @override
  Future<Result<MatchFindResult>> cancelMatchmaking() async =>
      Success(iptalSonucu);
}

class _Soket implements WebSocketService {
  final _akis = StreamController<RealtimeEvent>.broadcast();

  void yayinla(RealtimeEvent e) => _akis.add(e);
  Future<void> kapat() => _akis.close();

  @override
  Stream<RealtimeEvent> get events => _akis.stream;

  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Depo extends TokenStorage {
  Map<String, dynamic>? k;
  @override
  Future<void> saveUser(Map<String, dynamic> u) async => k = u;
  @override
  Future<Map<String, dynamic>?> readUser() async => k;
  @override
  dynamic noSuchMethod(Invocation i) => null;
}
