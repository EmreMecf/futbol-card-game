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
    // KIMYA
    // ================================================================
    group('kimya hesabi', () {
      test('bos kadroda kimya sifir', () async {
        repo.envanter = zenginEnvanter();
        await vm.load();

        expect(vm.chemistry.total, 0);
        expect(vm.chemistry.isComplete, isFalse);
      });

      test('ayni kulupten iki kart YESIL bag kurar (+2)', () async {
        repo.envanter = [
          kart('a', CardPosition.defender, 60,
              ulke: 'TUR', lig: 'Super Lig', kulup: 'Anadolu SK'),
          kart('b', CardPosition.defender, 60,
              ulke: 'BRA', lig: 'Super Lig', kulup: 'Anadolu SK'),
        ];
        await vm.load();

        vm.placeCard(1, repo.envanter[0]);
        vm.placeCard(2, repo.envanter[1]);

        expect(vm.chemistryAt(1), 2);
        expect(vm.chemistryAt(2), 2);
        expect(vm.chemistry.total, 2);
        expect(vm.chemistry.strongCount, 1);
      });

      test('sadece ayni uyruk SARI bag kurar (+1)', () async {
        repo.envanter = [
          kart('a', CardPosition.defender, 60,
              ulke: 'TUR', lig: 'Super Lig', kulup: 'Anadolu SK'),
          kart('b', CardPosition.defender, 60,
              ulke: 'TUR', lig: 'La Liga', kulup: 'Madrid Real'),
        ];
        await vm.load();

        vm.placeCard(1, repo.envanter[0]);
        vm.placeCard(2, repo.envanter[1]);

        expect(vm.chemistryAt(1), 1);
        expect(vm.chemistry.weakCount, 1);
      });

      test('ortak nokta yoksa KIRMIZI bag (0)', () async {
        repo.envanter = [
          kart('a', CardPosition.defender, 60,
              ulke: 'TUR', lig: 'Super Lig', kulup: 'Anadolu SK'),
          kart('b', CardPosition.defender, 60,
              ulke: 'BRA', lig: 'La Liga', kulup: 'Madrid Real'),
        ];
        await vm.load();

        vm.placeCard(1, repo.envanter[0]);
        vm.placeCard(2, repo.envanter[1]);

        expect(vm.chemistryAt(1), 0);
        expect(vm.chemistry.noneCount, 1);
      });

      test('BAGLI OLMAYAN slotlar birbirini etkilemez', () async {
        repo.envanter = [
          kart('a', CardPosition.defender, 60,
              ulke: 'TUR', lig: 'Super Lig', kulup: 'Anadolu SK'),
          kart('b', CardPosition.defender, 60,
              ulke: 'TUR', lig: 'Super Lig', kulup: 'Anadolu SK'),
        ];
        await vm.load();

        // Slot 1 ile 4 formasyonda BAGLI DEGIL
        vm.placeCard(1, repo.envanter[0]);
        vm.placeCard(4, repo.envanter[1]);

        expect(vm.chemistry.total, 0,
            reason: 'Slot 1 ile 4 arasinda formasyon bagi yok');
      });

      test('DIZILIS degisince kimya degisir (ayni kartlar)', () async {
        final turk1 = kart('t1', CardPosition.defender, 60,
            ulke: 'TUR', lig: 'Super Lig', kulup: 'Anadolu SK');
        final turk2 = kart('t2', CardPosition.defender, 60,
            ulke: 'TUR', lig: 'Super Lig', kulup: 'Anadolu SK');
        final bre1 = kart('b1', CardPosition.defender, 60,
            ulke: 'BRA', lig: 'La Liga', kulup: 'Madrid Real');
        final bre2 = kart('b2', CardPosition.defender, 60,
            ulke: 'BRA', lig: 'La Liga', kulup: 'Madrid Real');

        repo.envanter = [turk1, turk2, bre1, bre2];
        await vm.load();

        // DIZILIS A: uyumlular ayrik (T B T B)
        vm.placeCard(1, turk1);
        vm.placeCard(2, bre1);
        vm.placeCard(3, turk2);
        vm.placeCard(4, bre2);
        final dizilisA = vm.chemistry.total;

        // DIZILIS B: uyumlular yan yana (T T B B)
        vm.clearAll();
        vm.placeCard(1, turk1);
        vm.placeCard(2, turk2);
        vm.placeCard(3, bre1);
        vm.placeCard(4, bre2);
        final dizilisB = vm.chemistry.total;

        expect(dizilisB, greaterThan(dizilisA),
            reason: 'Uyumlulari yan yana dizmek kimyayi artirmali');
      });

      test('kimya onizlemesi kart secmeden once hesaplanir', () async {
        final turk = kart('t', CardPosition.defender, 60,
            ulke: 'TUR', lig: 'Super Lig', kulup: 'Anadolu SK');
        final ayniKulup = kart('a', CardPosition.defender, 55,
            ulke: 'BRA', lig: 'Super Lig', kulup: 'Anadolu SK');
        final yabanci = kart('y', CardPosition.defender, 62,
            ulke: 'JPN', lig: 'J-Lig', kulup: 'Tokyo Blue');

        repo.envanter = [turk, ayniKulup, yabanci];
        await vm.load();
        vm.placeCard(1, turk);

        expect(vm.chemistryIfPlaced(2, ayniKulup), 2);
        expect(vm.chemistryIfPlaced(2, yabanci), 0);
      });

      // ================================================================
      // KIMYA / GUC DENGESI
      // ================================================================
      // Bu iki test sistemin en onemli dengesini belgeliyor.
      //
      // MATEMATIK: Her bag puanini BAGLADIGI IKI KARTA birden ekler.
      // Yani 1 takim kimyasi puani = 2 guc puani eder. 17 bagin tamami
      // yesil olsa takim kimyasi 34 olur; bu da 11 karta dagilan
      // 68 guc puani, yani kart basina ortalama +6.2 demektir.
      //
      // Sonuc: kimya kart basina ~6 guc degerinde. Aradaki guc farki
      // bundan buyukse gucu, kucukse kimyayi secmek mantikli.
      // Otomatik dizilim bu hesabi yapiyor.

      /// Uyumlu (hepsi ayni kulup) ve uyumsuz (her biri farkli) kartlardan
      /// olusan envanter uretir. [gucFarki] iki grup arasindaki guc farki.
      List<InventoryCard> dengeliEnvanter(int gucFarki) {
        final liste = <InventoryCard>[];
        var no = 0;
        for (final p in CardPosition.values) {
          for (var i = 0; i < p.requiredCount; i++) {
            liste.add(kart('uyum${no++}', p, 50,
                ulke: 'TUR', lig: 'Super Lig', kulup: 'Anadolu SK'));
            liste.add(kart('guc$no', p, 50 + gucFarki,
                ulke: 'U$no', lig: 'L$no', kulup: 'K$no'));
            no++;
          }
        }
        return liste;
      }

      test('guc farki KUCUKSE kimyali kartlar secilir', () async {
        // Guc farki 4: kimyanin verdigi ~6 puan daha degerli
        repo.envanter = dengeliEnvanter(4);
        await vm.load();

        vm.autoFillByChemistry();

        expect(vm.isComplete, isTrue);
        expect(vm.chemistry.total, greaterThan(0),
            reason: 'Kimya guce degdiginde uyumlu kartlar secilmeli');

        // Kimyali dizilim, saf guc diziliminden daha guclu olmali
        final kimyaliEtkinGuc = vm.averageEffectivePower;
        vm.clearAll();
        vm.autoFillBest();
        final gucluEtkinGuc = vm.averageEffectivePower;

        expect(kimyaliEtkinGuc, greaterThanOrEqualTo(gucluEtkinGuc));
      });

      test('guc farki BUYUKSE guc tercih edilir (kimya bosuna feda edilmez)',
          () async {
        // Guc farki 12: kimyanin verdigi ~6 puan yetmiyor
        repo.envanter = dengeliEnvanter(12);
        await vm.load();

        vm.autoFillByChemistry();

        expect(vm.isComplete, isTrue);

        // Kadro tamamen guclu kartlardan olusmali
        final secilenler = vm.selectedCards;
        expect(
          secilenler.every((k) => k.power == 62),
          isTrue,
          reason: 'Kimya guce degmiyorsa guclu kartlar secilmeli',
        );
      });

      test('autoFillByChemistry etkin gucu artirir ya da korur', () async {
        repo.envanter = dengeliEnvanter(4);
        await vm.load();

        vm.autoFillBest();
        final oncesi = vm.averageEffectivePower;

        vm.autoFillByChemistry();
        final sonrasi = vm.averageEffectivePower;

        expect(sonrasi, greaterThanOrEqualTo(oncesi),
            reason: 'Iyilestirme algoritmasi kadroyu kotulestirmemeli');
      });

      test('kimya ortalama gucu yukseltir', () async {
        repo.envanter = [
          for (var i = 0; i < 4; i++)
            kart('d$i', CardPosition.defender, 60,
                ulke: 'TUR', lig: 'Super Lig', kulup: 'Anadolu SK'),
        ];
        await vm.load();

        for (var i = 0; i < 4; i++) {
          vm.placeCard(i + 1, repo.envanter[i]);
        }

        expect(vm.averagePower, 60);
        expect(vm.averageEffectivePower, greaterThan(60),
            reason: 'Kimya bonusu efektif gucu artirmali');
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

    test('ihtimal yuzdeleri dogru bicimlenir', () {
      expect(
        const TierOdds(tier: CardTier.bronze, weight: 5500).displayPercent,
        '%55',
      );
      expect(
        const TierOdds(tier: CardTier.diamond, weight: 190).displayPercent,
        '%1.9',
      );
      expect(
        const TierOdds(tier: CardTier.legend, weight: 10).displayPercent,
        '%0.10',
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
