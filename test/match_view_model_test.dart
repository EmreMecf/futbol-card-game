import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/auth/session_manager.dart';
import 'package:futbol_card/core/error/app_exception.dart';
import 'package:futbol_card/core/network/websocket_service.dart';
import 'package:futbol_card/core/storage/token_storage.dart';
import 'package:futbol_card/core/utils/result.dart';
import 'package:futbol_card/features/match/domain/repositories/match_repository.dart';
import 'package:futbol_card/features/match/presentation/viewmodel/match_view_model.dart';
import 'package:shared_models/shared_models.dart';

/// MatchViewModel'in ince mantigini dogrular.
///
/// Ozellikle SAYAC: sunucu saatiyle cihaz saati arasindaki farkin
/// dogru uygulandigini test ediyoruz. Bu, hile onleme acisindan kritik;
/// oyuncu telefon saatini degistirerek kendine sure kazandiramamali.
void main() {
  late _SahteRepository repo;
  late SessionManager session;
  late MatchViewModel vm;

  const macId = 'm-1';
  const benimId = 'u-1';

  /// Elimde 1 GK, 2 DEF, 1 MID kart olsun
  List<HandCard> testEli() => const [
        HandCard(
          userCardId: 'k1',
          cardId: 'c1',
          fullName: 'Kaleci',
          position: CardPosition.goalkeeper,
          tier: CardTier.gold,
          power: 80,
        ),
        HandCard(
          userCardId: 'k2',
          cardId: 'c2',
          fullName: 'Defans A',
          position: CardPosition.defender,
          tier: CardTier.silver,
          power: 70,
        ),
        HandCard(
          userCardId: 'k3',
          cardId: 'c3',
          fullName: 'Defans B',
          position: CardPosition.defender,
          tier: CardTier.bronze,
          power: 55,
        ),
        HandCard(
          userCardId: 'k4',
          cardId: 'c4',
          fullName: 'Orta Saha',
          position: CardPosition.midfielder,
          tier: CardTier.legend,
          power: 97,
          isProtected: true,
        ),
      ];

  /// Sunucu saatini istedigimiz gibi kurgulayabildigimiz durum uretici
  MatchState durum({
    bool isMyTurn = true,
    CardPosition? requiredPosition,
    Duration kalanSure = const Duration(seconds: 30),
    Duration cihazSaatiSapmasi = Duration.zero,
    MatchStatus status = MatchStatus.active,
  }) {
    // Sunucunun "simdi"si = cihaz saati + sapma
    final sunucuSimdi = DateTime.now().add(cihazSaatiSapmasi);

    return MatchState(
      matchId: macId,
      status: status,
      roundNumber: 1,
      isMyTurn: isMyTurn,
      requiredPosition: requiredPosition,
      serverTime: sunucuSimdi,
      turnDeadline: sunucuSimdi.add(kalanSure),
      myCardsLeft: 4,
      opponentCardsLeft: 4,
    );
  }

  setUp(() {
    repo = _SahteRepository();
    session = SessionManager(_BellektekiDepo());
    vm = MatchViewModel(repo, _SahteSocket(), session, matchId: macId);
  });

  // ==================================================================
  // SAYAC
  // ==================================================================
  group('Sayac - sunucu saatiyle calisir', () {
    test('normal durumda kalan sure dogru hesaplanir', () async {
      repo.durum = durum(kalanSure: const Duration(seconds: 30));
      await vm.initialize();

      // 1 saniyelik islem payi birakiyoruz
      expect(vm.remainingSeconds, inInclusiveRange(28, 30));
    });

    test('CIHAZ SAATI 1 SAAT GERI ise sayac yine dogru calisir', () async {
      // Oyuncu telefon saatini 1 saat geri aldi.
      // Sunucu saati cihazdan 1 saat ILERIDE gorunuyor.
      repo.durum = durum(
        kalanSure: const Duration(seconds: 30),
        cihazSaatiSapmasi: const Duration(hours: 1),
      );
      await vm.initialize();

      // Sayac hala 30 saniye gostermeli, 1 saat 30 saniye degil
      expect(vm.remainingSeconds, inInclusiveRange(28, 30),
          reason: 'Cihaz saati degistirilerek sure kazanilamaz');
    });

    test('CIHAZ SAATI 1 SAAT ILERI ise sayac yine dogru calisir', () async {
      repo.durum = durum(
        kalanSure: const Duration(seconds: 30),
        cihazSaatiSapmasi: const Duration(hours: -1),
      );
      await vm.initialize();

      expect(vm.remainingSeconds, inInclusiveRange(28, 30),
          reason: 'Cihaz saati ileri alinarak rakip AFK gosterilemez');
    });

    test('sure bittiyse sifir doner, negatife dusmez', () async {
      repo.durum = durum(kalanSure: const Duration(seconds: -10));
      await vm.initialize();

      expect(vm.remainingTime, Duration.zero);
    });

    test('son 10 saniyede aciliyet isareti yanar', () async {
      repo.durum = durum(kalanSure: const Duration(seconds: 8));
      await vm.initialize();

      expect(vm.isTimeRunningOut, isTrue);
    });
  });

  // ==================================================================
  // SURE ASIMI TALEBI
  // ==================================================================
  group('Sure asimi talebi', () {
    test('sira BENDEYKEN talep edilemez', () async {
      repo.durum = durum(
        isMyTurn: true,
        kalanSure: const Duration(seconds: -100),
      );
      await vm.initialize();

      expect(vm.canClaimTimeout, isFalse,
          reason: 'Kendi surem dolunca kendimi hukmen galip ilan edemem');
    });

    test('rakibin suresi dolmus ama AFK toleransi dolmamissa beklenir',
        () async {
      // Tur suresi 5 saniye once doldu; AFK toleransi 15 saniye
      repo.durum = durum(
        isMyTurn: false,
        kalanSure: const Duration(seconds: -5),
      );
      await vm.initialize();

      expect(vm.canClaimTimeout, isFalse,
          reason: 'AFK toleransi bitmeden talep edilmemeli');
    });

    test('AFK toleransi da dolduysa talep edilebilir', () async {
      // 20 saniye gecti: 45 sn tur + 15 sn tolerans siniri asildi
      repo.durum = durum(
        isMyTurn: false,
        kalanSure: const Duration(seconds: -20),
      );
      await vm.initialize();

      expect(vm.canClaimTimeout, isTrue);
    });

    test('mac bittiyse talep edilemez', () async {
      repo.durum = durum(
        isMyTurn: false,
        kalanSure: const Duration(seconds: -100),
        status: MatchStatus.finished,
      );
      await vm.initialize();

      expect(vm.canClaimTimeout, isFalse);
    });
  });

  // ==================================================================
  // OYNANABILIR KARTLAR
  // ==================================================================
  group('Oynanabilir kartlar', () {
    test('turu ben aciyorsam TUM kartlarim oynanabilir', () async {
      repo.durum = durum(isMyTurn: true, requiredPosition: null);
      repo.el = testEli();
      await vm.initialize();

      expect(vm.canChoosePosition, isTrue);
      expect(vm.playableCards.length, 4);
      expect(vm.mustPass, isFalse);
    });

    test('zorunlu pozisyon varsa sadece o pozisyon oynanabilir', () async {
      repo.durum = durum(
        isMyTurn: true,
        requiredPosition: CardPosition.defender,
      );
      repo.el = testEli();
      await vm.initialize();

      expect(vm.canChoosePosition, isFalse);
      expect(vm.playableCards.length, 2, reason: 'Elimde 2 defans var');
      expect(
        vm.playableCards.every((k) => k.position == CardPosition.defender),
        isTrue,
      );
    });

    test('oynanmis kartlar listeye girmez', () async {
      repo.durum = durum(isMyTurn: true);
      repo.el = [
        ...testEli().take(2),
        const HandCard(
          userCardId: 'k9',
          cardId: 'c9',
          fullName: 'Oynanmis',
          position: CardPosition.forward,
          tier: CardTier.bronze,
          power: 50,
          isPlayed: true,
        ),
      ];
      await vm.initialize();

      expect(vm.playableCards.length, 2);
    });

    test('zorunlu pozisyonda kart yoksa PAS gecmek zorundayim', () async {
      repo.durum = durum(
        isMyTurn: true,
        requiredPosition: CardPosition.forward,
      );
      repo.el = testEli(); // elimde forvet yok
      await vm.initialize();

      expect(vm.playableCards, isEmpty);
      expect(vm.mustPass, isTrue);
    });

    test('sira rakipteyse pas zorunlulugu olusmaz', () async {
      repo.durum = durum(
        isMyTurn: false,
        requiredPosition: CardPosition.forward,
      );
      repo.el = testEli();
      await vm.initialize();

      expect(vm.mustPass, isFalse);
    });
  });

  // ==================================================================
  // HAMLE GONDERME
  // ==================================================================
  group('Hamle gonderme', () {
    test('sira bende degilken kart oynanamaz', () async {
      repo.durum = durum(isMyTurn: false);
      repo.el = testEli();
      await vm.initialize();

      final sonuc = await vm.playCard(repo.el.first);

      expect(sonuc, isFalse);
      expect(repo.oynananKartlar, isEmpty,
          reason: 'Sunucuya istek bile gitmemeli');
    });

    test('gecerli hamle sunucuya gider', () async {
      repo.durum = durum(isMyTurn: true);
      repo.el = testEli();
      await vm.initialize();

      final sonuc = await vm.playCard(repo.el.first);

      expect(sonuc, isTrue);
      expect(repo.oynananKartlar, ['k1']);
    });

    test('sunucu reddederse hata gosterilir', () async {
      repo.durum = durum(isMyTurn: true);
      repo.el = testEli();
      repo.hataMesaji = 'Sira sizde degil.';
      await vm.initialize();

      final sonuc = await vm.playCard(repo.el.first);

      expect(sonuc, isFalse);
      expect(vm.errorMessage, 'Sira sizde degil.');
    });

    test('mac bittiyse hamle yapilamaz', () async {
      repo.durum = durum(isMyTurn: true, status: MatchStatus.finished);
      repo.el = testEli();
      await vm.initialize();

      expect(vm.isOver, isTrue);
      expect(await vm.playCard(repo.el.first), isFalse);
    });
  });

  // ==================================================================
  // MAC SONUCU
  // ==================================================================
  test('mac bitince sonuc otomatik cekilir ve profil guncellenir',
      () async {
    repo.durum = durum(status: MatchStatus.finished);
    repo.sonuc = const MatchResultSummary(
      matchId: macId,
      didIWin: true,
      myScore: 14,
      opponentScore: 8,
      myProfile: UserModel(
        id: benimId,
        username: 'ben',
        coins: 1100,
        mmr: 1025,
        protectionSlots: 4,
        wins: 1,
      ),
    );

    await vm.initialize();

    expect(vm.result, isNotNull);
    expect(vm.result!.didIWin, isTrue);
    expect(vm.result!.headline, 'Kazandin!');

    // Mac sonrasi profil oturuma yazilmali (coin/MMR/koruma degisti)
    expect(session.protectionSlots, 4);
    expect(session.user?.coins, 1100);
  });
}

// ====================================================================
// SAHTE BAGIMLILIKLAR
// ====================================================================

class _SahteRepository implements MatchRepository {
  MatchState? durum;
  List<HandCard> el = const [];
  MatchHistory gecmis = const MatchHistory();
  MatchResultSummary? sonuc;

  /// Doluysa playCard hata dondurur
  String? hataMesaji;

  final List<String?> oynananKartlar = [];

  @override
  Future<Result<MatchState>> fetchState(String matchId) async =>
      Success(durum!);

  @override
  Future<Result<List<HandCard>>> fetchHand(String matchId) async =>
      Success(el);

  @override
  Future<Result<MatchHistory>> fetchHistory(String matchId) async =>
      Success(gecmis);

  /// Profil ekranindaki mac listesi. Bu testler mac ekranini
  /// dogruladigi icin bos donmesi yeterli.
  List<MatchHistoryEntry> macListesi = const [];

  @override
  Future<Result<List<MatchHistoryEntry>>> fetchMatchHistoryList({
    int limit = 20,
    int offset = 0,
  }) async =>
      Success(macListesi);

  @override
  Future<Result<MatchResultSummary>> fetchResult(String matchId) async {
    final s = sonuc;
    if (s == null) {
      return const Failure(AppException(message: 'Sonuc yok'));
    }
    return Success(s);
  }

  @override
  Future<Result<PlayCardResult>> playCard({
    required String matchId,
    String? userCardId,
  }) async {
    if (hataMesaji != null) {
      // Sunucunun dondugu oyun kurali hatasini taklit ediyoruz
      return Failure(
        AppException(message: hataMesaji!, type: AppErrorType.gameRule),
      );
    }
    oynananKartlar.add(userCardId);
    return const Success(PlayCardResult());
  }

  @override
  Future<Result<Map<String, dynamic>>> claimTimeout(String matchId) async =>
      const Success({});

  @override
  Future<Result<Map<String, dynamic>>> surrender(String matchId) async =>
      const Success({});
}

class _SahteSocket implements WebSocketService {
  // Testlerde gercek zamanli olay uretmiyoruz; ViewModel'in
  // hesaplamalarini yalitilmis olarak olcuyoruz.
  @override
  Stream<RealtimeEvent> get events => const Stream<RealtimeEvent>.empty();

  @override
  Stream<bool> get connectionState => const Stream<bool>.empty();

  @override
  bool get isConnected => true;

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> reconnect() async {}

  @override
  Future<void> dispose() async {}
}

class _BellektekiDepo extends TokenStorage {
  Map<String, dynamic>? _kullanici;

  @override
  Future<String?> readAccessToken() async => 'jeton';

  @override
  Future<String?> readRefreshToken() async => 'yenileme';

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {}

  @override
  Future<void> saveUser(Map<String, dynamic> user) async => _kullanici = user;

  @override
  Future<Map<String, dynamic>?> readUser() async => _kullanici;

  @override
  Future<void> clear() async => _kullanici = null;
}
