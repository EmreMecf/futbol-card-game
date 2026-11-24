import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/auth/session_manager.dart';
import 'package:futbol_card/core/error/app_exception.dart';
import 'package:futbol_card/core/storage/token_storage.dart';
import 'package:futbol_card/core/utils/result.dart';
import 'package:futbol_card/features/deck/domain/repositories/deck_repository.dart';
import 'package:futbol_card/features/deck/presentation/viewmodel/deck_view_model.dart';
import 'package:futbol_card/features/store/domain/repositories/store_repository.dart';
import 'package:futbol_card/features/store/presentation/viewmodel/store_view_model.dart';
import 'package:shared_models/shared_models.dart';

void main() {
  // ==================================================================
  // KADRO DUZENLEME
  // ==================================================================
  group('DeckViewModel - slot tabanli kadro', () {
    late _SahteDeckRepository repo;
    late DeckViewModel vm;

    InventoryCard kart(
      String id,
      CardPosition pozisyon,
      int guc, {
      String? ulke,
      String? lig,
      String? kulup,
      bool kilitli = false,
    }) {
      return InventoryCard(
        userCardId: id,
        cardId: 'c-$id',
        fullName: 'Oyuncu $id',
        position: pozisyon,
        tier: CardTier.bronze,
        power: guc,
        nationality: ulke,
        league: lig,
        club: kulup,
        isLocked: kilitli,
      );
    }

    /// Her pozisyondan bol kart
    List<InventoryCard> zenginEnvanter() {
      final liste = <InventoryCard>[];
      var no = 0;
      for (final p in CardPosition.values) {
        for (var i = 0; i < p.requiredCount * 2; i++) {
          liste.add(kart('u${no++}', p, 50 + i * 3));
        }
      }
      return liste;
    }

    setUp(() {
      repo = _SahteDeckRepository();
      vm = DeckViewModel(repo);
    });

    test('bos kadro ile acilis: eksikler listelenir', () async {
      repo.envanter = zenginEnvanter();
      await vm.load();

      expect(vm.totalSelected, 0);
      expect(vm.isComplete, isFalse);
      expect(vm.missingMessage, contains('kaleci'));
      expect(vm.canSave, isFalse);
    });

    test('kayitli dizilis slotlara yuklenir', () async {
      repo.envanter = zenginEnvanter();
      repo.slotlar = {
        0: kart('gk', CardPosition.goalkeeper, 60),
        for (var i = 1; i <= 4; i++) i: kart('d$i', CardPosition.defender, 55),
        for (var i = 5; i <= 8; i++) i: kart('m$i', CardPosition.midfielder, 55),
        for (var i = 9; i <= 10; i++) i: kart('f$i', CardPosition.forward, 55),
      };
      await vm.load();

      expect(vm.totalSelected, GameRules.squadSize);
      expect(vm.isComplete, isTrue);
      expect(vm.hasUnsavedChanges, isFalse);
      expect(vm.cardAt(0)!.userCardId, 'gk');
    });

    test('slota YANLIS pozisyondan kart konamaz', () async {
      repo.envanter = zenginEnvanter();
      await vm.load();

      final forvet = vm.availableForSlot(9).first;
      expect(vm.placeCard(0, forvet), isFalse);
      expect(vm.cardAt(0), isNull);
    });

    test('KILITLI kart secilebilir listede gorunmez', () async {
      repo.envanter = [
        kart('kilitli', CardPosition.goalkeeper, 90, kilitli: true),
        kart('serbest', CardPosition.goalkeeper, 60),
      ];
      await vm.load();

      final uygun = vm.availableForSlot(0);
      expect(uygun.length, 1);
      expect(uygun.first.userCardId, 'serbest');
    });

    test('ayni kart baska slota tasinirsa eski slot bosalir', () async {
      repo.envanter = zenginEnvanter();
      await vm.load();

      final defans = vm.availableForSlot(1).first;
      vm.placeCard(1, defans);
      expect(vm.cardAt(1)!.userCardId, defans.userCardId);

      vm.placeCard(3, defans);
      expect(vm.cardAt(1), isNull, reason: 'Eski slot bosalmali');
      expect(vm.cardAt(3)!.userCardId, defans.userCardId);
    });

    test('dolu slota tasima YER DEGISTIRME yapar', () async {
      repo.envanter = zenginEnvanter();
      await vm.load();

      final a = vm.availableForSlot(1)[0];
      final b = vm.availableForSlot(1)[1];
      vm.placeCard(1, a);
      vm.placeCard(2, b);

      vm.placeCard(2, a);

      expect(vm.cardAt(2)!.userCardId, a.userCardId);
      expect(vm.cardAt(1)!.userCardId, b.userCardId);
      expect(vm.totalSelected, 2, reason: 'Kart kaybolmamali');
    });

    test('swapSlots ayni pozisyonda calisir, farklida calismaz', () async {
      repo.envanter = zenginEnvanter();
      await vm.load();

      final a = vm.availableForSlot(1)[0];
      final b = vm.availableForSlot(1)[1];
      vm.placeCard(1, a);
      vm.placeCard(2, b);

      vm.swapSlots(1, 2);
      expect(vm.cardAt(1)!.userCardId, b.userCardId);
      expect(vm.cardAt(2)!.userCardId, a.userCardId);

      final forvet = vm.availableForSlot(9).first;
      vm.placeCard(9, forvet);
      vm.swapSlots(1, 9);
      expect(vm.cardAt(9)!.userCardId, forvet.userCardId,
          reason: 'Farkli pozisyonlar takas edilemez');
    });

    test('autoFillBest kadroyu tamamlar', () async {
      repo.envanter = zenginEnvanter();
      await vm.load();
      vm.autoFillBest();

      expect(vm.isComplete, isTrue);
      expect(vm.totalSelected, GameRules.squadSize);
      expect(vm.canSave, isTrue);
    });

    test('kaydetme kartlari SLOT SIRASIYLA gonderir', () async {
      repo.envanter = zenginEnvanter();
      await vm.load();
      vm.autoFillBest();

      await vm.save();

      expect(repo.kaydedilenler.length, GameRules.squadSize);
      expect(repo.kaydedilenler[0], vm.cardAt(0)!.userCardId);
      expect(repo.kaydedilenler[10], vm.cardAt(10)!.userCardId);
    });

    test('sunucu kadroyu reddederse mesaj gosterilir', () async {
      repo.envanter = zenginEnvanter();
      repo.kayitGecerli = false;
      repo.kayitMesaji = 'Bazi kartlar formasyonda yanlis pozisyonda duruyor.';
      await vm.load();
      vm.autoFillBest();

      expect(await vm.save(), isFalse);
      expect(vm.saveMessage, contains('yanlis pozisyonda'));
      expect(vm.hasUnsavedChanges, isTrue);
    });

    // ================================================================
    // KIMYA KALDIRILDI (055): kart yalniz kendi gucuyle oynar
    // ================================================================
    group('kimya kaldirildi', () {
      test('ayni kulupten kartlar da kimya kazandirmaz', () async {
        repo.envanter = [
          for (var i = 0; i < 4; i++)
            kart('d$i', CardPosition.defender, 60, ulke: 'TUR', lig: 'Super Lig', kulup: 'Anadolu SK'),
        ];
        await vm.load();
        for (var i = 0; i < 4; i++) {
          vm.placeCard(i + 1, repo.envanter[i]);
        }

        expect(vm.chemistry.total, 0);
        expect(vm.chemistryAt(1), 0);
        expect(vm.chemistryIfPlaced(2, repo.envanter[1]), 0);
        expect(vm.averageEffectivePower, vm.averagePower, reason: 'etkin guc = guc');
      });

      test('otomatik dizilim en guclu kartlari secer', () async {
        final liste = <InventoryCard>[];
        var no = 0;
        for (final p in CardPosition.values) {
          for (var i = 0; i < p.requiredCount; i++) {
            liste.add(kart('uyum${no++}', p, 50, ulke: 'TUR', lig: 'Super Lig', kulup: 'Anadolu SK'));
            liste.add(kart('guc$no', p, 54, ulke: 'U$no', lig: 'L$no', kulup: 'K$no'));
            no++;
          }
        }
        repo.envanter = liste;
        await vm.load();

        vm.autoFillBest();
        expect(vm.isComplete, isTrue);
        expect(vm.selectedCards.every((k) => k.power == 54), isTrue);

        vm.clearAll();
        vm.autoFillByChemistry();
        expect(vm.selectedCards.every((k) => k.power == 54), isTrue,
            reason: 'kimya yokken ayni kulup kartlari guce tercih edilmez');
      });
    });
  });

  // ==================================================================
  // MAGAZA
  // ==================================================================
  group('StoreViewModel', () {
    late _SahteStoreRepository repo;
    late SessionManager session;
    late StoreViewModel vm;

    const standart = PackType(
      slug: 'standard',
      name: 'Standart Paket',
      cardCount: 5,
      priceCoins: 500,
      odds: [
        TierOdds(tier: CardTier.bronze, weight: 5500),
        TierOdds(tier: CardTier.legend, weight: 10),
      ],
    );

    setUp(() async {
      repo = _SahteStoreRepository();
      session = SessionManager(_BellektekiDepo());
      await session.save(
        tokens: const AuthTokens(accessToken: 'a', refreshToken: 'r'),
        user: const UserModel(id: 'u1', username: 'test', coins: 1000),
      );
      vm = StoreViewModel(repo, session);
    });

    test('044: gunun teklifi kayit yoksa yok, alinamaz', () async {
      await vm.load();
      expect(vm.dailyOffer, isNull);
      expect(await vm.buyDailyOffer(), isFalse);
    });

    test('044: gunun teklifi indirimli fiyatla alinir, acilis gosterilir', () async {
      var alindi = false;
      final yeni = StoreViewModel(
        repo,
        session,
        dailyOffer: () async => DailyShopStatus(
            enabled: true, packSlug: 'standard', name: 'Standart Paket', cardCount: 5,
            price: 500, discountPct: 25, discountedPrice: 375, boughtToday: alindi),
        buyDailyOffer: () async {
          alindi = true;
          return const PackOpenResult(packSlug: 'standard', packName: 'Standart Paket', coinsLeft: 625);
        },
      );
      await yeni.load();
      expect(yeni.dailyOffer?.discountedPrice, 375);
      expect(yeni.canBuyDailyOffer, isTrue);
      expect(await yeni.buyDailyOffer(), isTrue);
      expect(yeni.lastOpening?.packSlug, 'standard');
      expect(yeni.coins, 625, reason: 'oturumdaki altin sunucunun kalan degeriyle guncellenir');
      expect(yeni.dailyOffer?.boughtToday, isTrue, reason: 'teklif yeniden yuklenir');
      expect(yeni.canBuyDailyOffer, isFalse);
    });

    test('044: altin yetmezse gunun teklifi istenmez', () async {
      var cagri = 0;
      await session.updateUser(const UserModel(id: 'u1', username: 'test', coins: 100));
      final yeni = StoreViewModel(repo, session,
          dailyOffer: () async => const DailyShopStatus(enabled: true, packSlug: 'standard', discountedPrice: 375),
          buyDailyOffer: () async {
            cagri++;
            return const PackOpenResult(packSlug: 'standard', packName: '');
          });
      await yeni.load();
      expect(yeni.canBuyDailyOffer, isFalse);
      expect(await yeni.buyDailyOffer(), isFalse);
      expect(cagri, 0);
    });

    test('paketler yuklenir', () async {
      repo.paketler = [standart];
      await vm.load();

      expect(vm.packs.length, 1);
      expect(vm.packs.first.name, 'Standart Paket');
    });

    test('coin yetiyorsa paket acilabilir', () async {
      repo.paketler = [standart];
      await vm.load();

      expect(vm.coins, 1000);
      expect(vm.canAfford(standart), isTrue);
    });

    test('coin yetmiyorsa istek SUNUCUYA GITMEZ', () async {
      await session.updateUser(
        const UserModel(id: 'u1', username: 'test', coins: 100),
      );
      repo.paketler = [standart];
      await vm.load();

      expect(vm.canAfford(standart), isFalse);

      final basarili = await vm.openPack(standart);

      expect(basarili, isFalse);
      expect(repo.acilanPaketler, isEmpty,
          reason: 'Gereksiz istek atilmamali');
    });

    test('paket acilinca coin dususu oturuma yansir', () async {
      repo.paketler = [standart];
      repo.sonuc = const PackOpenResult(
        packSlug: 'standard',
        packName: 'Standart Paket',
        coinsSpent: 500,
        coinsLeft: 500,
        cards: [
          InventoryCard(
            userCardId: 'x1',
            cardId: 'c1',
            fullName: 'Yeni Kart',
            position: CardPosition.forward,
            tier: CardTier.gold,
            power: 82,
          ),
        ],
      );
      await vm.load();

      final basarili = await vm.openPack(standart);

      expect(basarili, isTrue);
      expect(repo.acilanPaketler, ['standard']);
      expect(vm.lastOpening!.cards.length, 1);
      expect(vm.coins, 500, reason: 'Coin dususu oturuma yazilmali');
    });

    test('nadir kart cikisi isaretlenir', () async {
      repo.paketler = [standart];
      repo.sonuc = const PackOpenResult(
        packSlug: 'standard',
        packName: 'Standart Paket',
        cards: [
          InventoryCard(
            userCardId: 'x1',
            cardId: 'c1',
            fullName: 'Maradona',
            position: CardPosition.midfielder,
            tier: CardTier.legend,
            power: 99,
          ),
          InventoryCard(
            userCardId: 'x2',
            cardId: 'c2',
            fullName: 'Sade Kart',
            position: CardPosition.defender,
            tier: CardTier.bronze,
            power: 50,
          ),
        ],
      );
      await vm.load();
      await vm.openPack(standart);

      expect(vm.lastOpening!.hasRareCard, isTrue);
      expect(vm.lastOpening!.bestCard!.fullName, 'Maradona');
    });

    test('sunucu hatasi kullaniciya gosterilir', () async {
      repo.paketler = [standart];
      repo.hataMesaji = 'Yeterli coin yok. Gerekli: 500, mevcut: 100';
      await vm.load();

      final basarili = await vm.openPack(standart);

      expect(basarili, isFalse);
      expect(vm.errorMessage, contains('Yeterli coin yok'));
    });

    test('paket kutusu EN COK CIKAN seviyeden renk alir', () {
      // Onceki mantik bestPossibleTier kullaniyordu. Neredeyse her
      // pakette Legend ihtimali sifirdan buyuk oldugu icin UC PAKET DE
      // ayni mor kutuyla ciziliyordu; oyuncu farki goremiyordu.
      const standart = PackType(
        slug: 'standard',
        name: 'Standart Paket',
        cardCount: 5,
        priceCoins: 500,
        odds: [
          TierOdds(tier: CardTier.bronze, weight: 5500),
          TierOdds(tier: CardTier.silver, weight: 3000),
          TierOdds(tier: CardTier.gold, weight: 1300),
          TierOdds(tier: CardTier.diamond, weight: 190),
          TierOdds(tier: CardTier.legend, weight: 10),
        ],
      );
      const premium = PackType(
        slug: 'premium',
        name: 'Premium Paket',
        cardCount: 5,
        priceCoins: 2500,
        odds: [
          TierOdds(tier: CardTier.gold, weight: 6200),
          TierOdds(tier: CardTier.diamond, weight: 3200),
          TierOdds(tier: CardTier.legend, weight: 600),
        ],
      );

      expect(standart.signatureTier, CardTier.bronze);
      expect(premium.signatureTier, CardTier.gold);

      // Iki paket AYNI renkte olmamali
      expect(standart.signatureTier, isNot(premium.signatureTier));
    });

    test('esit agirlikta YUKSEK seviye secilir', () {
      // Premium pakette Gumus ve Altin ikisi de %35. Siralamada once
      // gelen Gumus secilirse premium paket GRI kutuyla cizilir ve
      // oyuncunun gozunde ucuz gorunur.
      const premium = PackType(
        slug: 'premium',
        name: 'Premium Paket',
        cardCount: 5,
        priceCoins: 2500,
        odds: [
          TierOdds(tier: CardTier.silver, weight: 3500),
          TierOdds(tier: CardTier.gold, weight: 3500),
          TierOdds(tier: CardTier.bronze, weight: 2000),
          TierOdds(tier: CardTier.diamond, weight: 900),
          TierOdds(tier: CardTier.legend, weight: 100),
        ],
      );

      expect(premium.signatureTier, CardTier.gold);
    });

    test('ust sinirli pakette imza seviyesi siniri asmaz', () {
      // Baslangic paketinde Diamond ve Legend cikmaz; kutu da o
      // seviyelerin renginde olmamali.
      const baslangic = PackType(
        slug: 'starter',
        name: 'Baslangic Paketi',
        cardCount: 15,
        maxTier: CardTier.gold,
        odds: [
          TierOdds(tier: CardTier.legend, weight: 9000),
        ],
      );

      expect(baslangic.signatureTier, CardTier.gold);
    });

    test('ihtimal yuzdeleri TURKCE bicimlenir', () {
      // ONDALIK AYRACI VIRGUL OLMALI.
      // Onceki surum nokta kullaniyordu: "%0.10". Turkce'de nokta
      // BINLIK ayracidir; oyuncu bunu yuzde on diye okuyabilirdi.
      // Cikma ihtimalinde bu ciddi bir yanlis anlama olurdu.
      expect(
        const TierOdds(tier: CardTier.bronze, weight: 5500).displayPercent,
        '%55',
        reason: 'Tam sayida ondalik hic yazilmamali',
      );
      expect(
        const TierOdds(tier: CardTier.diamond, weight: 190).displayPercent,
        '%1,9',
      );
      expect(
        const TierOdds(tier: CardTier.legend, weight: 10).displayPercent,
        '%0,1',
        reason: 'Sondaki gereksiz sifir atilmali',
      );
      expect(
        const TierOdds(tier: CardTier.legend, weight: 5).displayPercent,
        '%0,05',
        reason: 'Cok kucuk ihtimallerde iki basamak korunmali',
      );
    });
  });
}

// ====================================================================
// SAHTE BAGIMLILIKLAR
// ====================================================================

class _SahteDeckRepository implements DeckRepository {
  List<InventoryCard> envanter = const [];
  Map<int, InventoryCard> slotlar = const {};
  bool kayitGecerli = true;
  String? kayitMesaji;

  List<String> kaydedilenler = [];

  @override
  Future<Result<List<DeckSummary>>> fetchDecks() async => const Success([
        DeckSummary(id: 'd1', name: 'Kadrom', isActive: true, cardCount: 11),
      ]);

  @override
  Future<Result<List<InventoryCard>>> fetchDeckCards(String deckId) async =>
      Success(slotlar.values.toList());

  @override
  Future<Result<Map<int, InventoryCard>>> fetchDeckSlots(String deckId) async =>
      Success(slotlar);

  @override
  Future<Result<DeckChemistry>> fetchChemistry(String deckId) async =>
      const Success(DeckChemistry());

  @override
  Future<Result<List<InventoryCard>>> fetchInventory() async =>
      Success(envanter);

  @override
  Future<Result<DeckValidation>> validateDeck(String deckId) async =>
      const Success(DeckValidation(isValid: true));

  @override
  Future<Result<DeckValidation>> saveDeck({
    required String deckId,
    required List<String> userCardIds,
    bool setActive = true,
  }) async {
    kaydedilenler = userCardIds;
    return Success(
      DeckValidation(isValid: kayitGecerli, message: kayitMesaji),
    );
  }

  @override
  Future<Result<DeckSummary>> createDeck(String name) async =>
      Success(DeckSummary(id: 'yeni', name: name));
}

class _SahteStoreRepository implements StoreRepository {
  List<PackType> paketler = const [];
  PackOpenResult? sonuc;
  String? hataMesaji;

  final List<String> acilanPaketler = [];

  @override
  Future<Result<List<PackType>>> fetchPacks() async => Success(paketler);

  @override
  Future<Result<PackOpenResult>> openPack(String slug) async {
    if (hataMesaji != null) {
      return Failure(
        AppException(message: hataMesaji!, type: AppErrorType.gameRule),
      );
    }
    acilanPaketler.add(slug);
    return Success(sonuc ?? const PackOpenResult(packSlug: '', packName: ''));
  }
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
