import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/shared/widgets/premium_card/premium_card.dart';
import 'package:shared_models/shared_models.dart';

/// PremiumPlayerCard'in her seviyede sorunsuz cizildigini dogrular.
///
/// CustomPainter ve ShaderMask iceren widget'larda hatalar cogu zaman
/// derleme aninda degil, CIZIM aninda ortaya cikar. Bu testler kartı
/// gercekten cizerek o hatalari yakalar.
void main() {
  Widget sarmala(Widget child) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF0B1120),
        body: Center(child: child),
      ),
    );
  }

  group('PremiumPlayerCard cizimi', () {
    for (final seviye in CardTier.values) {
      testWidgets('${seviye.label} kart hatasiz cizilir', (tester) async {
        await tester.pumpWidget(
          sarmala(
            PremiumPlayerCard(
              fullName: 'Test Oyuncu',
              position: CardPosition.midfielder,
              tier: seviye,
              power: 85,
              nationality: 'TUR',
              club: 'Test FC',
              width: 200,
            ),
          ),
        );

        // Animasyonlu kartlar (Legend, Diamond, Gold) surekli doner;
        // pumpAndSettle sonsuza kadar bekler. Bu yuzden sabit sayida
        // kare ilerletiyoruz.
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
        expect(find.byType(PremiumPlayerCard), findsOneWidget);
        expect(find.text('85'), findsOneWidget);
        expect(find.text('TEST OYUNCU'), findsOneWidget);
        expect(find.text('OS'), findsOneWidget, reason: 'Pozisyon rozeti');
      });
    }

    testWidgets('etkilesimsiz modda animasyon calismaz', (tester) async {
      await tester.pumpWidget(
        sarmala(
          const PremiumPlayerCard(
            fullName: 'Liste Karti',
            position: CardPosition.goalkeeper,
            tier: CardTier.legend,
            power: 95,
            width: 120,
            interactive: false,
          ),
        ),
      );

      // interactive: false iken hicbir animasyon donmedigi icin
      // pumpAndSettle takilmadan tamamlanmali.
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('95'), findsOneWidget);
    });

    testWidgets('surukleme ile egilme hata vermez', (tester) async {
      await tester.pumpWidget(
        sarmala(
          const PremiumPlayerCard(
            fullName: 'Egilen Kart',
            position: CardPosition.forward,
            tier: CardTier.gold,
            power: 88,
            width: 200,
          ),
        ),
      );

      final kart = find.byType(PremiumPlayerCard);

      // Kartin uzerinde parmagi gezdir
      final hareket = await tester.startGesture(tester.getCenter(kart));
      await hareket.moveBy(const Offset(40, -30));
      await tester.pump(const Duration(milliseconds: 16));
      await hareket.moveBy(const Offset(-70, 50));
      await tester.pump(const Duration(milliseconds: 16));
      await hareket.up();

      // Merkeze donus animasyonu
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
    });

    testWidgets('koruma ve kilit rozetleri gosterilir', (tester) async {
      await tester.pumpWidget(
        sarmala(
          const PremiumPlayerCard(
            fullName: 'Korunan Kart',
            position: CardPosition.defender,
            tier: CardTier.silver,
            power: 70,
            width: 200,
            isProtected: true,
            isLocked: true,
            interactive: false,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.shield), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('gorsel yoksa siluet gosterilir, cokmez', (tester) async {
      await tester.pumpWidget(
        sarmala(
          const PremiumPlayerCard(
            fullName: 'Gorselsiz',
            position: CardPosition.midfielder,
            tier: CardTier.bronze,
            power: 55,
            imageUrl: 'cards/olmayan_dosya.png', // gecersiz yol
            width: 180,
            interactive: false,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.person), findsOneWidget,
          reason: 'Gorsel yuklenemeyince siluet gosterilmeli');
    });

    testWidgets('cok kucuk boyutta da tasma olmaz', (tester) async {
      await tester.pumpWidget(
        sarmala(
          const PremiumPlayerCard(
            fullName: 'Cok Uzun Bir Futbolcu Ismi Buraya',
            position: CardPosition.forward,
            tier: CardTier.diamond,
            power: 91,
            club: 'Cok Uzun Kulup Adi Olan Takim',
            width: 90, // liste kucugu
            interactive: false,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Tasma (overflow) hatasi cizim aninda exception olarak gelir
      expect(tester.takeException(), isNull);
    });
  });

  group('Model fabrikalari', () {
    testWidgets('fromHand korunan karti dogru gosterir', (tester) async {
      const el = HandCard(
        userCardId: 'uc-1',
        cardId: 'c-1',
        fullName: 'Pele',
        position: CardPosition.forward,
        tier: CardTier.legend,
        power: 98,
        isProtected: true,
      );

      await tester.pumpWidget(
        sarmala(PremiumPlayerCard.fromHand(el, interactive: false)),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('98'), findsOneWidget);
      expect(find.text('PELE'), findsOneWidget);
      expect(find.byIcon(Icons.shield), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('fromInventory kilitli karti soluk gosterir', (tester) async {
      const kart = InventoryCard(
        userCardId: 'uc-2',
        cardId: 'c-2',
        fullName: 'Franco Baresi',
        position: CardPosition.defender,
        tier: CardTier.legend,
        power: 93,
        isLocked: true,
      );

      await tester.pumpWidget(
        sarmala(PremiumPlayerCard.fromInventory(kart, interactive: false)),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.lock), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Seviye temalari', () {
    test('sadece Legend kartta donen cerceve var', () {
      expect(CardTierTheme.of(CardTier.legend).hasAnimatedBorder, isTrue);

      for (final t in [
        CardTier.bronze,
        CardTier.silver,
        CardTier.gold,
        CardTier.diamond,
      ]) {
        expect(CardTierTheme.of(t).hasAnimatedBorder, isFalse,
            reason: '${t.label} kartta donen cerceve olmamali');
      }
    });

    test('holografik parlama Altin ve ustunde acik', () {
      expect(CardTierTheme.of(CardTier.bronze).hasHolographicSweep, isFalse);
      expect(CardTierTheme.of(CardTier.silver).hasHolographicSweep, isFalse);
      expect(CardTierTheme.of(CardTier.gold).hasHolographicSweep, isTrue);
      expect(CardTierTheme.of(CardTier.diamond).hasHolographicSweep, isTrue);
      expect(CardTierTheme.of(CardTier.legend).hasHolographicSweep, isTrue);
    });

    test('seviye yukseldikce isik yaricapi artar', () {
      final yaricaplar = CardTier.values
          .map((t) => CardTierTheme.of(t).glowRadius)
          .toList();

      for (var i = 1; i < yaricaplar.length; i++) {
        expect(yaricaplar[i], greaterThan(yaricaplar[i - 1]),
            reason: 'Ust seviye kartlar daha cok parlamali');
      }
    });
  });
}
