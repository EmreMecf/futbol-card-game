import 'package:shared_models/shared_models.dart';
import 'package:test/test.dart';

/// Kart ozelliklerinin (SUT / HIZ / FIZIK / DEFANS / DRIBLING / HIZLANMA)
/// tel uzerinde dogru tasindigini ve arayuze verilen yardimcilarin
/// dogru davrandigini dogrular.
void main() {
  const ornek = CardAttributes(
    shooting: 88,
    pace: 92,
    physical: 71,
    defending: 44,
    dribbling: 85,
    acceleration: 90,
  );

  group('CardAttributes', () {
    test('sunucunun gonderdigi JSON aynen okunur', () {
      // Sunucu tarafinda card_attributes_json() bu alan adlarini
      // uretiyor. Isimlerden biri degisirse bu test kirilmali.
      final json = {
        'shooting': 88,
        'pace': 92,
        'physical': 71,
        'defending': 44,
        'dribbling': 85,
        'acceleration': 90,
      };

      expect(CardAttributes.fromJson(json), ornek);
    });

    test('gidis donus kayipsiz', () {
      expect(CardAttributes.fromJson(ornek.toJson()), ornek);
    });

    test('eksik alanlar sifir sayilir, hata firlatmaz', () {
      // Eski bir sunucu surumu sadece bir kismini gonderirse
      // uygulamanin cokmemesi gerekir.
      final kismi = CardAttributes.fromJson({'shooting': 70});
      expect(kismi.shooting, 70);
      expect(kismi.pace, 0);
    });

    test('bos ozellik seti taninir', () {
      expect(const CardAttributes().isEmpty, isTrue);
      expect(ornek.isEmpty, isFalse);
      expect(ornek.isNotEmpty, isTrue);
    });

    test('en iyi ozellik dogru secilir', () {
      expect(ornek.best.label, 'HIZ');
      expect(ornek.best.value, 92);
    });

    test('ortalama alti ozelligin ortalamasidir', () {
      // (88 + 92 + 71 + 44 + 85 + 90) / 6 = 78.33 -> 78
      expect(ornek.average, 78);
    });

    test('arayuz sirasi sabit: SUT, HIZ, DRP, HZL, DEF, FIZ', () {
      // Izgara ilk ucunu sol, son ucunu sag sutuna koyuyor.
      // Sira degisirse kart uzerindeki yerlesim bozulur.
      expect(
        ornek.entries.map((e) => e.label).toList(),
        ['SUT', 'HIZ', 'DRP', 'HZL', 'DEF', 'FIZ'],
      );
    });

    test('oran 0-1 arasina kirpilir', () {
      expect(const CardAttributeEntry('SUT', 1).ratio, 0.0);
      expect(const CardAttributeEntry('SUT', 30).ratio, 0.0);
      expect(const CardAttributeEntry('SUT', 99).ratio, 1.0);

      final orta = const CardAttributeEntry('SUT', 65).ratio;
      expect(orta, greaterThan(0.4));
      expect(orta, lessThan(0.6));
    });
  });

  group('Kart modelleri ozellikleri tasir', () {
    test('InventoryCard JSON uzerinden ozellikleri korur', () {
      const kart = InventoryCard(
        userCardId: 'uc1',
        cardId: 'c1',
        fullName: 'Test Oyuncu',
        position: CardPosition.forward,
        tier: CardTier.gold,
        power: 84,
        attributes: ornek,
      );

      final geri = InventoryCard.fromJson(kart.toJson());
      expect(geri.attributes, ornek);
    });

    test('toCardModel ozellikleri de tasir', () {
      const kart = InventoryCard(
        userCardId: 'uc1',
        cardId: 'c1',
        fullName: 'Test Oyuncu',
        position: CardPosition.forward,
        tier: CardTier.gold,
        power: 84,
        attributes: ornek,
      );

      expect(kart.toCardModel().attributes, ornek);
    });

    test('HandCard ozellikleri tasir ama GUC hesabina karismaz', () {
      // EN KRITIK BEKLENTI: ozellikler eklendi diye turun sonucu
      // degismemeli. Masaya cikan guc hala power + chemistry.
      const el = HandCard(
        userCardId: 'uc1',
        cardId: 'c1',
        fullName: 'Test Oyuncu',
        position: CardPosition.forward,
        tier: CardTier.gold,
        power: 84,
        chemistry: 3,
        attributes: ornek,
      );

      expect(el.attributes, ornek);
      expect(el.effectivePower, 87);
    });

    test('ozellik gelmezse null kalir', () {
      const kart = CardModel(
        cardId: 'c1',
        fullName: 'Ozelliksiz',
        position: CardPosition.defender,
        tier: CardTier.bronze,
        power: 50,
      );

      expect(kart.attributes, isNull);
      expect(CardModel.fromJson(kart.toJson()).attributes, isNull);
    });
  });
}
