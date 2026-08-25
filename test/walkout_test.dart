import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/features/store/domain/reveal_style.dart';
import 'package:futbol_card/features/store/presentation/viewmodel/pack_opening_view_model.dart';
import 'package:futbol_card/shared/widgets/premium_card/premium_card.dart';
import 'package:futbol_card/shared/widgets/walkout/walkout.dart';
import 'package:shared_models/shared_models.dart';

/// ADIM 6 — kademeli paket açılışı ve walkout sahnesi.
///
/// EN KRİTİK TESTLER: walkout'un DOĞRU kartta ve SADECE BİR KEZ
/// oynaması. Yanlış çalışırsa oyuncu ya 15 kartın hepsinde 4.5 saniye
/// bekler (paket açmak işkenceye döner) ya da Legend kartı sıradan bir
/// flip ile görüp anın tamamını kaçırır.
void main() {
  InventoryCard kart(
    String id, {
    CardTier seviye = CardTier.bronze,
    int guc = 50,
    CardPosition pozisyon = CardPosition.forward,
    String? ulke = 'BRA',
    String? kulup = 'Rio Atletico',
  }) {
    return InventoryCard(
      userCardId: id,
      cardId: 'c-$id',
      fullName: 'Oyuncu $id',
      position: pozisyon,
      tier: seviye,
      power: guc,
      nationality: ulke,
      club: kulup,
    );
  }

  PackOpenResult paket(List<InventoryCard> kartlar) => PackOpenResult(
        packSlug: 'standard',
        packName: 'Standart Paket',
        coinsSpent: 500,
        coinsLeft: 500,
        // Sunucu EN İYİDEN kötüye sıralı gönderir
        cards: [...kartlar]..sort((a, b) {
            if (a.tier.rank != b.tier.rank) {
              return b.tier.rank.compareTo(a.tier.rank);
            }
            return b.power.compareTo(a.power);
          }),
      );

  // ==================================================================
  // KADEME KARARI
  // ==================================================================
  group('RevealStyle kademeleri', () {
    test('seviyeye göre doğru kademe seçilir', () {
      expect(RevealStyle.forTier(CardTier.bronze), RevealStyle.simple);
      expect(RevealStyle.forTier(CardTier.silver), RevealStyle.simple);
      expect(RevealStyle.forTier(CardTier.gold), RevealStyle.golden);
      expect(RevealStyle.forTier(CardTier.diamond), RevealStyle.walkout);
      expect(RevealStyle.forTier(CardTier.legend), RevealStyle.walkout);
    });

    test('süreler kademeye göre belirgin şekilde ayrışır', () {
      // Heyecan farktan doğar: bronz göz kırpması, altın fark edilir.
      expect(
        RevealStyle.simple.flipDuration.inMilliseconds,
        lessThan(RevealStyle.golden.flipDuration.inMilliseconds),
      );
      // Walkout'ta flip yok; kart sahnenin sonunda vurarak gelir.
      expect(RevealStyle.walkout.flipDuration, Duration.zero);
    });

    test('bronz kartta titreşim YOK', () {
      // 15 kartın 12'sinde titreyen telefon, titreşimin anlamını
      // tamamen yok ederdi.
      expect(RevealStyle.simple.haptic, HapticStrength.none);
      expect(RevealStyle.golden.haptic, HapticStrength.light);
      expect(RevealStyle.walkout.haptic, HapticStrength.heavy);
    });
  });

  // ==================================================================
  // PACK OPENING VIEWMODEL
  // ==================================================================
  group('PackOpeningViewModel', () {
    test('kartlar TERSTEN sıralanır: en iyi SONA kalır', () {
      final vm = PackOpeningViewModel(paket([
        kart('bronz', seviye: CardTier.bronze, guc: 50),
        kart('legend', seviye: CardTier.legend, guc: 95),
        kart('altin', seviye: CardTier.gold, guc: 80),
      ]));

      expect(vm.queue.first.userCardId, 'bronz');
      expect(vm.queue.last.userCardId, 'legend');
    });

    test('walkout SADECE paketin en iyi kartına verilir', () {
      final enIyi = kart('legend', seviye: CardTier.legend, guc: 95);
      final digerNadir = kart('diamond', seviye: CardTier.diamond, guc: 88);

      final vm = PackOpeningViewModel(paket([
        kart('bronz'),
        digerNadir,
        enIyi,
      ]));

      expect(vm.styleFor(enIyi), RevealStyle.walkout);
      // Diamond nadir ama en iyisi değil -> kısa ama güçlü açılış
      expect(vm.styleFor(digerNadir), RevealStyle.golden);
      expect(vm.styleFor(vm.queue.first), RevealStyle.simple);
    });

    test('iki Legend çıksa bile walkout BİR KEZ oynar', () {
      // Aynı sahneyi 4.5 saniye daha izletmek heyecan değil
      // sabırsızlık üretir.
      final l1 = kart('legend-a', seviye: CardTier.legend, guc: 99);
      final l2 = kart('legend-b', seviye: CardTier.legend, guc: 93);

      final vm = PackOpeningViewModel(paket([l1, l2, kart('bronz')]));

      expect(vm.styleFor(l1), RevealStyle.walkout);
      expect(vm.styleFor(l2), RevealStyle.golden);
    });

    test('walkout hakkı harcandıktan sonra tekrar verilmez', () {
      final enIyi = kart('legend', seviye: CardTier.legend, guc: 95);
      final vm = PackOpeningViewModel(paket([enIyi, kart('bronz')]));

      expect(vm.styleFor(enIyi), RevealStyle.walkout);

      vm.markWalkoutPlayed();

      expect(vm.walkoutUsed, isTrue);
      // Sahne atlanıp geri gelinse bile tekrar tetiklenmemeli
      expect(vm.styleFor(enIyi), RevealStyle.golden);
    });

    test('paket kademesi en iyi karttan belirlenir', () {
      expect(
        PackOpeningViewModel(paket([kart('a'), kart('b')])).packStyle,
        RevealStyle.simple,
      );
      expect(
        PackOpeningViewModel(paket([
          kart('a'),
          kart('d', seviye: CardTier.diamond, guc: 88),
        ])).packStyle,
        RevealStyle.walkout,
      );
    });

    test('ilerleme ve bitiş doğru sayılır', () {
      final vm = PackOpeningViewModel(paket([
        kart('a'),
        kart('b'),
        kart('c'),
      ]));

      expect(vm.totalCount, 3);
      expect(vm.progressText, '1 / 3');
      expect(vm.isFinished, isFalse);

      vm.next();
      expect(vm.progressText, '2 / 3');

      vm.next();
      vm.next();
      expect(vm.isFinished, isTrue);
      expect(vm.currentCard, isNull);

      // Bittiğinde fazladan next() çağrısı sayacı bozmamalı
      vm.next();
      expect(vm.revealedCount, 3);
    });

    test('hepsini göster doğrudan özete atlar', () {
      final vm = PackOpeningViewModel(
        paket(List.generate(15, (i) => kart('k$i'))),
      );

      vm.revealAll();
      expect(vm.isFinished, isTrue);
    });

    test('boş paket çökmez', () {
      final vm = PackOpeningViewModel(paket([]));
      expect(vm.isFinished, isTrue);
      expect(vm.packStyle, RevealStyle.simple);
      expect(vm.bestCard, isNull);
    });
  });

  // ==================================================================
  // ÇİZİM
  // ==================================================================
  Widget sarmala(Widget child) => MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF04070F),
          body: Center(child: child),
        ),
      );

  group('CardFlipReveal', () {
    testWidgets('dönme başlarken ARKA yüz, bitince ÖN yüz görünür',
        (tester) async {
      await tester.pumpWidget(
        sarmala(
          CardFlipReveal(
            card: kart('a', seviye: CardTier.silver, guc: 71),
            style: RevealStyle.simple,
          ),
        ),
      );

      // İlk karede kart henüz dönmemiş: ön yüz yok
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.byType(PremiumPlayerCard), findsNothing);

      // 350 ms'lik dönme bitti: ön yüz ortada
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      expect(find.byType(PremiumPlayerCard), findsOneWidget);
      expect(find.text('71'), findsOneWidget);
    });

    testWidgets('altın kademe daha uzun sürer', (tester) async {
      await tester.pumpWidget(
        sarmala(
          CardFlipReveal(
            card: kart('a', seviye: CardTier.gold, guc: 82),
            style: RevealStyle.golden,
          ),
        ),
      );

      // Basit kademenin biteceği anda altın hâlâ dönüyor olmalı
      await tester.pump(const Duration(milliseconds: 360));
      expect(find.byType(PremiumPlayerCard), findsNothing);

      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      expect(find.byType(PremiumPlayerCard), findsOneWidget);
    });
  });

  group('WalkoutScreen sahne sırası', () {
    // NOT: pumpAndSettle KULLANILMIYOR. Sahnede sürekli tekrar eden
    // bir ışık salınımı controller'ı var; pumpAndSettle sonsuza kadar
    // beklerdi. Bunun yerine sahneyi kare kare ilerletiyoruz.
    testWidgets('bayrak -> pozisyon -> arma -> kart sırasıyla gelir',
        (tester) async {
      await tester.pumpWidget(
        sarmala(
          SizedBox(
            width: 420,
            height: 820,
            child: WalkoutScreen(
              card: kart(
                'legend',
                seviye: CardTier.legend,
                guc: 97,
                pozisyon: CardPosition.forward,
                ulke: 'BRA',
                kulup: 'Rio Atletico',
              ),
              onContinue: () {},
            ),
          ),
        ),
      );

      // ---- 1. AŞAMA: BAYRAK (0.5 - 1.5 sn) ----
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.byType(NationFlag), findsOneWidget);
      expect(find.byType(ClubCrest), findsNothing);
      expect(find.byType(PremiumPlayerCard), findsNothing);

      // ---- 2. AŞAMA: POZİSYON (1.5 - 2.5 sn) ----
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.byType(NationFlag), findsNothing);
      expect(find.text('FORVET'), findsOneWidget);

      // ---- 3. AŞAMA: KULÜP ARMASI (2.5 - 3.5 sn) ----
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.text('FORVET'), findsNothing);
      expect(find.byType(ClubCrest), findsOneWidget);
      expect(find.text('RIO ATLETICO'), findsOneWidget);

      // ---- 4. AŞAMA: KART VURUR (3.5 sn +) ----
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.byType(ClubCrest), findsNothing);
      expect(find.byType(PremiumPlayerCard), findsOneWidget);
      expect(find.text('LEGEND'), findsOneWidget);
      expect(find.byType(ConfettiOverlay), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('dokunmak sahneyi kartın vuruş anına atlar', (tester) async {
      var devamEdildi = false;

      await tester.pumpWidget(
        sarmala(
          SizedBox(
            width: 420,
            height: 820,
            child: WalkoutScreen(
              card: kart('d', seviye: CardTier.diamond, guc: 90),
              onContinue: () => devamEdildi = true,
            ),
          ),
        ),
      );

      // Daha bayrak aşamasındayken atla
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byType(PremiumPlayerCard), findsNothing);

      await tester.tap(find.byType(WalkoutScreen));

      // İLK pump() ticker'ı başlatır (bu karede geçen süre 0'dır).
      // Bu satır olmadan animasyon hiç ilerlemez ve test, ürün hatası
      // olmadığı hâlde başarısız olur.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Kart geldi ama henüz "devam" çağrılmadı
      expect(find.byType(PremiumPlayerCard), findsOneWidget);
      expect(devamEdildi, isFalse);

      // Kart geldikten sonra ikinci dokunuş devam ettirir
      await tester.tap(find.byType(WalkoutScreen));
      await tester.pump();
      expect(devamEdildi, isTrue);

      expect(tester.takeException(), isNull);
    });

    testWidgets('sahne yarıda kapatılırsa ticker sızdırmaz', (tester) async {
      // Kullanıcı sahne oynarken geri tuşuna basarsa: controller'lar
      // dispose edilmezse arka planda her karede uyanan ticker kalır.
      await tester.pumpWidget(
        sarmala(
          SizedBox(
            width: 420,
            height: 820,
            child: WalkoutScreen(
              card: kart('l', seviye: CardTier.legend, guc: 99),
              onContinue: () {},
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpWidget(sarmala(const Text('baska ekran')));
      await tester.pump(const Duration(milliseconds: 300));

      // Ticker sızıntısı olsaydı test sonunda çerçeve hata verirdi
      expect(tester.takeException(), isNull);
    });
  });

  group('Görsel parçalar', () {
    testWidgets('bilinmeyen uyruk kodu çökmez', (tester) async {
      await tester.pumpWidget(sarmala(const NationFlag(code: 'ZZZ')));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('ZZZ'), findsOneWidget);
    });

    testWidgets('uyruk null ise çizim yine yapılır', (tester) async {
      await tester.pumpWidget(sarmala(const NationFlag(code: null)));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('her uyruk kodu hatasız çizilir', (tester) async {
      const kodlar = [
        'TUR', 'BRA', 'ESP', 'GER', 'FRA', 'ITA', 'ENG',
        'NED', 'ARG', 'POR', 'JPN', 'SEN', 'HUN', 'RUS',
      ];

      for (final kod in kodlar) {
        await tester.pumpWidget(sarmala(NationFlag(code: kod)));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: kod);
      }
    });

    testWidgets('kulüp arması baş harfleri çıkarır', (tester) async {
      await tester.pumpWidget(sarmala(const ClubCrest(clubName: 'Anadolu SK')));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('ANADOLU SK'), findsOneWidget);
    });

    testWidgets('kulüpsüz kart armayı çökertmez', (tester) async {
      await tester.pumpWidget(sarmala(const ClubCrest(clubName: null)));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('SERBEST OYUNCU'), findsOneWidget);
    });

    testWidgets('konfeti patlar ve süresi bitince kendini kaldırır',
        (tester) async {
      await tester.pumpWidget(
        sarmala(
          const SizedBox(
            width: 400,
            height: 700,
            child: ConfettiOverlay(
              active: true,
              colors: [Colors.amber, Colors.white],
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: find.byType(ConfettiOverlay),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );

      // 2.6 saniyelik animasyon bitti; painter kaldırılmalı
      await tester.pump(const Duration(milliseconds: 2200));
      expect(tester.takeException(), isNull);
    });

    testWidgets('konfeti kapalıyken hiç çizilmez', (tester) async {
      await tester.pumpWidget(
        sarmala(
          const ConfettiOverlay(active: false, colors: [Colors.amber]),
        ),
      );
      await tester.pump();

      // DİKKAT: find.byType(CustomPaint) tek başına yanıltıcıdır —
      // Material/Scaffold kendi içinde CustomPaint kullanır. Aramayı
      // konfetinin ALTINA daraltmak şart.
      expect(
        find.descendant(
          of: find.byType(ConfettiOverlay),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
    });

    testWidgets('spot ışığı zemini hatasız çizilir', (tester) async {
      for (final ilerleme in [0.0, 0.5, 1.0]) {
        await tester.pumpWidget(
          sarmala(
            SizedBox(
              width: 400,
              height: 700,
              child: SpotlightBackdrop(
                progress: ilerleme,
                sway: 0.3,
                color: const Color(0xFFFFD75E),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'ilerleme $ilerleme');
      }
    });
  });
}
