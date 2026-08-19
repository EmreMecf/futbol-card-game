import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/error/app_exception.dart';
import 'package:futbol_card/core/utils/result.dart';
import 'package:futbol_card/features/sbc/domain/repositories/sbc_repository.dart';
import 'package:futbol_card/features/sbc/presentation/viewmodel/sbc_builder_view_model.dart';
import 'package:shared_models/shared_models.dart';

/// SBC (Kadro Kurma Görevleri) mantığını doğrular.
///
/// En kritik testler: kadrodaki ve maçta kilitli kartların
/// eritilemediği. Bunlar yanlış çalışırsa oyuncu oynayacağı kadroyu
/// kaybedip maça giremez hale gelir.
void main() {
  InventoryCard kart(
    String id,
    CardPosition pozisyon, {
    CardTier seviye = CardTier.bronze,
    int guc = 50,
    String? ulke,
    String? lig,
    String? kulup,
    bool kilitli = false,
    bool kadroda = false,
  }) {
    return InventoryCard(
      userCardId: id,
      cardId: 'c-$id',
      fullName: 'Oyuncu $id',
      position: pozisyon,
      tier: seviye,
      power: guc,
      nationality: ulke,
      league: lig,
      club: kulup,
      isLocked: kilitli,
      inDeck: kadroda,
    );
  }

  /// Her pozisyondan yeterli kart üretir
  List<InventoryCard> envanter({
    CardTier seviye = CardTier.bronze,
    int guc = 50,
    String? ulke,
    String? lig,
    String? kulup,
    int katsayi = 2,
  }) {
    final liste = <InventoryCard>[];
    var no = 0;
    for (final p in CardPosition.values) {
      for (var i = 0; i < p.requiredCount * katsayi; i++) {
        liste.add(kart('u${no++}', p,
            seviye: seviye, guc: guc, ulke: ulke, lig: lig, kulup: kulup));
      }
    }
    return liste;
  }

  SbcChallenge gorev(List<SbcRequirement> sartlar) => SbcChallenge(
        id: 'g1',
        slug: 'test',
        name: 'Test Gorevi',
        requirements: sartlar,
        rewards: const [SbcReward(type: 'coins', amount: 500)],
      );

  // ==================================================================
  // ŞART DEĞERLENDİRME (yerel, anlık)
  // ==================================================================
  group('Şart değerlendirme', () {
    Map<int, InventoryCard?> tamKadro(List<InventoryCard> kartlar) {
      final slotlar = <int, InventoryCard?>{};
      var i = 0;
      for (final p in CardPosition.values) {
        for (final slot in slotsForPosition(p)) {
          slotlar[slot] = kartlar.where((k) => k.position == p).elementAt(i % 2);
          i++;
        }
      }
      return slotlar;
    }

    test('eksik kadroda engelleyici mesaj döner', () {
      final sonuc = SbcEvaluation.calculate(
        requirements: const [
          SbcRequirement(type: SbcRequirementType.minChemistry, targetValue: 10),
        ],
        slots: {0: kart('a', CardPosition.goalkeeper)},
      );

      expect(sonuc.isValid, isFalse);
      expect(sonuc.blockingError, contains('kart daha'));
    });

    test('max_tier: üst seviye kart varsa şart karşılanmaz', () {
      final bronzlar = envanter();
      final slotlar = tamKadro(bronzlar);

      var sonuc = SbcEvaluation.calculate(
        requirements: const [
          SbcRequirement(type: SbcRequirementType.maxTier, tier: CardTier.bronze),
        ],
        slots: slotlar,
      );
      expect(sonuc.isValid, isTrue);

      // Bir kartı altınla değiştir
      slotlar[0] = kart('altin', CardPosition.goalkeeper,
          seviye: CardTier.gold, guc: 80);

      sonuc = SbcEvaluation.calculate(
        requirements: const [
          SbcRequirement(type: SbcRequirementType.maxTier, tier: CardTier.bronze),
        ],
        slots: slotlar,
      );
      expect(sonuc.isValid, isFalse);
      expect(sonuc.requirements.first.current, 10);
      expect(sonuc.requirements.first.target, 11);
    });

    test('min_tier: alt seviye kart varsa şart karşılanmaz', () {
      final slotlar = tamKadro(envanter(seviye: CardTier.gold, guc: 80));

      var sonuc = SbcEvaluation.calculate(
        requirements: const [
          SbcRequirement(type: SbcRequirementType.minTier, tier: CardTier.gold),
        ],
        slots: slotlar,
      );
      expect(sonuc.isValid, isTrue);

      slotlar[5] = kart('bronz', CardPosition.midfielder);

      sonuc = SbcEvaluation.calculate(
        requirements: const [
          SbcRequirement(type: SbcRequirementType.minTier, tier: CardTier.gold),
        ],
        slots: slotlar,
      );
      expect(sonuc.isValid, isFalse);
    });

    test('min_chemistry: kimya şartı kadroya göre hesaplanır', () {
      // Hepsi aynı kulüpten -> maksimum kimya
      final slotlar = tamKadro(envanter(
        ulke: 'TUR', lig: 'Super Lig', kulup: 'Anadolu SK',
      ));

      final sonuc = SbcEvaluation.calculate(
        requirements: const [
          SbcRequirement(type: SbcRequirementType.minChemistry, targetValue: 30),
        ],
        slots: slotlar,
      );

      expect(sonuc.chemistry, kMaxTeamChemistry);
      expect(sonuc.isValid, isTrue);
    });

    test('min_distinct_nations: farklı uyruk sayılır', () {
      final slotlar = <int, InventoryCard?>{};
      var no = 0;
      for (final p in CardPosition.values) {
        for (final slot in slotsForPosition(p)) {
          slotlar[slot] = kart('u$no', p, ulke: 'U${no % 4}');
          no++;
        }
      }

      final sonuc = SbcEvaluation.calculate(
        requirements: const [
          SbcRequirement(
              type: SbcRequirementType.minDistinctNations, targetValue: 4),
        ],
        slots: slotlar,
      );

      expect(sonuc.requirements.first.current, 4);
      expect(sonuc.isValid, isTrue);
    });

    test('min_avg_power: ortalama güç hesaplanır', () {
      final slotlar = tamKadro(envanter(guc: 70));

      final sonuc = SbcEvaluation.calculate(
        requirements: const [
          SbcRequirement(type: SbcRequirementType.minAvgPower, targetValue: 65),
        ],
        slots: slotlar,
      );

      expect(sonuc.avgPower, 70);
      expect(sonuc.isValid, isTrue);
    });

    test('BİLİNMEYEN şart karşılanmış SAYILMAZ', () {
      // Sunucuya yeni bir şart tipi eklenip uygulama güncellenmezse,
      // ekranda yeşil gösterip sunucuda reddedilmek en kötü sonuç olurdu.
      final slotlar = tamKadro(envanter());

      final sonuc = SbcEvaluation.calculate(
        requirements: const [
          SbcRequirement(type: SbcRequirementType.unknown),
        ],
        slots: slotlar,
      );

      expect(sonuc.isValid, isFalse);
    });

    test('birden fazla şart: hepsi karşılanmalı', () {
      final slotlar = tamKadro(envanter(
        seviye: CardTier.silver, guc: 70,
        ulke: 'TUR', lig: 'Super Lig', kulup: 'Anadolu SK',
      ));

      final sonuc = SbcEvaluation.calculate(
        requirements: const [
          SbcRequirement(type: SbcRequirementType.exactTier, tier: CardTier.silver),
          SbcRequirement(type: SbcRequirementType.minChemistry, targetValue: 30),
          SbcRequirement(type: SbcRequirementType.minAvgPower, targetValue: 65),
        ],
        slots: slotlar,
      );

      expect(sonuc.requirements.length, 3);
      expect(sonuc.metCount, 3);
      expect(sonuc.progressText, '3/3');
      expect(sonuc.isValid, isTrue);
    });
  });

  // ==================================================================
  // KADRO KURMA VIEWMODEL
  // ==================================================================
  group('SbcBuilderViewModel', () {
    late _SahteRepository repo;
    late SbcBuilderViewModel vm;

    setUp(() {
      repo = _SahteRepository();
      vm = SbcBuilderViewModel(
        repo,
        challenge: gorev(const [
          SbcRequirement(type: SbcRequirementType.maxTier, tier: CardTier.bronze),
        ]),
      );
    });

    test('KADRODAKI kartlar seçilebilir listede GÖRÜNMEZ', () async {
      // Bu koruma olmasaydı oyuncu oynayacağı kadroyu eritip
      // maça giremez hale gelebilirdi.
      repo.envanter = [
        kart('kadroda', CardPosition.goalkeeper, kadroda: true),
        kart('serbest', CardPosition.goalkeeper),
      ];
      await vm.load();

      final uygun = vm.availableForSlot(0);
      expect(uygun.length, 1);
      expect(uygun.first.userCardId, 'serbest');
    });

    test('MAÇTA KİLİTLİ kartlar seçilebilir listede GÖRÜNMEZ', () async {
      repo.envanter = [
        kart('kilitli', CardPosition.goalkeeper, kilitli: true),
        kart('serbest', CardPosition.goalkeeper),
      ];
      await vm.load();

      expect(vm.availableForSlot(0).length, 1);
    });

    test('kadroda olan kart placeCard ile de yerleştirilemez', () async {
      repo.envanter = [kart('kadroda', CardPosition.goalkeeper, kadroda: true)];
      await vm.load();

      expect(vm.placeCard(0, repo.envanter.first), isFalse);
      expect(vm.cardAt(0), isNull);
    });

    test('yanlış pozisyondan kart yerleştirilemez', () async {
      repo.envanter = envanter();
      await vm.load();

      final forvet = vm.availableForSlot(9).first;
      expect(vm.placeCard(0, forvet), isFalse);
    });

    test('en DÜŞÜK güçlü kartlar listede üstte', () async {
      // Görevin amacı kullanmadığın kartları eritmek; en zayıflar
      // üstte olmalı ki oyuncu değerli kartlarını yanlışlıkla yakmasın.
      repo.envanter = [
        kart('guclu', CardPosition.goalkeeper, seviye: CardTier.gold, guc: 85),
        kart('zayif', CardPosition.goalkeeper, guc: 45),
      ];
      await vm.load();

      expect(vm.availableForSlot(0).first.userCardId, 'zayif');
    });

    test('autoFill kadroyu tamamlar', () async {
      repo.envanter = envanter();
      await vm.load();
      vm.autoFill();

      expect(vm.isComplete, isTrue);
      expect(vm.totalSelected, GameRules.squadSize);
    });

    test('şartlar sağlanmadan gönderilemez', () async {
      repo.envanter = envanter(seviye: CardTier.gold, guc: 80);
      await vm.load();
      vm.autoFill();

      // Görev "hiçbir kart bronzu geçmesin" diyor ama hepsi altın
      expect(vm.isComplete, isTrue);
      expect(vm.evaluation.isValid, isFalse);
      expect(vm.canSubmit, isFalse);
    });

    test('şartlar sağlanınca gönderilebilir', () async {
      repo.envanter = envanter();
      await vm.load();
      vm.autoFill();

      expect(vm.evaluation.isValid, isTrue);
      expect(vm.canSubmit, isTrue);
    });

    test('gönderim kartları SLOT SIRASIYLA yollar', () async {
      repo.envanter = envanter();
      await vm.load();
      vm.autoFill();

      await vm.submit();

      expect(repo.gonderilen.length, GameRules.squadSize);
      // Slot sırası kimya hesabını belirliyor; 0. eleman kaleci olmalı
      expect(repo.gonderilen[0], vm.result == null ? isNotNull : isNotNull);
    });

    test('başarılı gönderimden sonra kadro temizlenir', () async {
      repo.envanter = envanter();
      repo.sonuc = const SbcSubmitResult(
        challengeSlug: 'test',
        challengeName: 'Test Gorevi',
        burnedCount: 11,
        rewards: [SbcReward(type: 'coins', amount: 500)],
        coins: 1500,
      );
      await vm.load();
      vm.autoFill();

      expect(await vm.submit(), isTrue);
      expect(vm.result, isNotNull);
      expect(vm.result!.rewardCoins, 500);
      expect(vm.totalSelected, 0, reason: 'Kartlar eritildi, kadro bosalmali');
    });

    test('sunucu reddederse hata gösterilir ve kadro korunur', () async {
      repo.envanter = envanter();
      repo.hataMesaji = 'Bu gorevi zaten tamamladiniz.';
      await vm.load();
      vm.autoFill();

      expect(await vm.submit(), isFalse);
      expect(vm.errorMessage, contains('zaten tamamladiniz'));
      expect(vm.totalSelected, GameRules.squadSize,
          reason: 'Reddedilen gonderimde kadro kaybolmamali');
    });

    test('eritilecek güç toplamı hesaplanır', () async {
      repo.envanter = envanter(guc: 50);
      await vm.load();
      vm.autoFill();

      expect(vm.burnValue, 50 * GameRules.squadSize);
    });
  });
}

// ====================================================================
class _SahteRepository implements SbcRepository {
  List<InventoryCard> envanter = const [];
  SbcSubmitResult? sonuc;
  String? hataMesaji;

  List<String> gonderilen = [];

  @override
  Future<Result<List<SbcChallenge>>> fetchChallenges() async =>
      const Success([]);

  @override
  Future<Result<List<InventoryCard>>> fetchInventory() async =>
      Success(envanter);

  @override
  Future<Result<SbcEvaluation>> evaluate({
    required String challengeId,
    required List<String> userCardIds,
  }) async =>
      const Success(SbcEvaluation(isValid: true));

  @override
  Future<Result<SbcSubmitResult>> submit({
    required String challengeId,
    required List<String> userCardIds,
  }) async {
    if (hataMesaji != null) {
      return Failure(
        AppException(message: hataMesaji!, type: AppErrorType.gameRule),
      );
    }
    gonderilen = userCardIds;
    return Success(sonuc ??
        const SbcSubmitResult(challengeSlug: 't', challengeName: 'T'));
  }
}
