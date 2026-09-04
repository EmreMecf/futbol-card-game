import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/constants/app_colors.dart';
import 'package:futbol_card/core/theme/app_breakpoints.dart';
import 'package:futbol_card/core/theme/app_theme.dart';
import 'package:futbol_card/core/theme/app_typography.dart';
import 'package:futbol_card/features/match/presentation/widgets/match_widgets.dart';
import 'package:futbol_card/shared/widgets/stat_chip.dart';
import 'package:shared_models/shared_models.dart';

/// Tasarım sisteminin ve yeni maç ekranı parçalarının testleri.
///
/// Buradaki testler "güzel görünüyor mu" diye sormaz; görselliği test
/// etmek kırılgandır. Bunun yerine YANLIŞ OLURSA OYUNCUYU YANILTACAK
/// davranışları kilitler: kimya rozetinin doğru sayıyı göstermesi,
/// kırılma noktalarının doğru yerleşimi seçmesi, sayaç halkasının
/// süre bitince taşmaması gibi.
void main() {
  HandCard kart({
    String id = 'k1',
    String ad = 'Test Oyuncu',
    CardPosition pozisyon = CardPosition.midfielder,
    CardTier seviye = CardTier.gold,
    int guc = 83,
    int kimya = 0,
  }) {
    return HandCard(
      userCardId: id,
      cardId: 'c-$id',
      fullName: ad,
      position: pozisyon,
      tier: seviye,
      power: guc,
      chemistry: kimya,
    );
  }

  Widget sar(Widget cocuk, {Size boyut = const Size(400, 800)}) {
    return MediaQuery(
      data: MediaQueryData(size: boyut),
      child: MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(body: Center(child: cocuk)),
      ),
    );
  }

  // ==================================================================
  // KIRILMA NOKTALARI
  // ==================================================================
  group('Kırılma noktaları', () {
    test('genişliğe göre doğru ekran sınıfı seçilir', () {
      expect(AppBreakpoints.fromWidth(390), ScreenSize.mobile);
      expect(AppBreakpoints.fromWidth(599), ScreenSize.mobile);
      expect(AppBreakpoints.fromWidth(600), ScreenSize.tablet);
      expect(AppBreakpoints.fromWidth(1023), ScreenSize.tablet);
      expect(AppBreakpoints.fromWidth(1024), ScreenSize.desktop);
      expect(AppBreakpoints.fromWidth(1920), ScreenSize.desktop);
    });

    test('kenar çubuğu SADECE masaüstünde kullanılır', () {
      // Alt sekme çubuğu 1440px genişlikte absürt görünür; kenar
      // çubuğu da 390px telefonda ekranın yarısını yer.
      expect(ScreenSize.mobile.usesSidebar, isFalse);
      expect(ScreenSize.tablet.usesSidebar, isFalse);
      expect(ScreenSize.desktop.usesSidebar, isTrue);
    });

    test('çok sütunlu maç yerleşimi telefonda kullanılmaz', () {
      expect(ScreenSize.mobile.usesWideLayout, isFalse);
      expect(ScreenSize.tablet.usesWideLayout, isTrue);
      expect(ScreenSize.desktop.usesWideLayout, isTrue);
    });

    test('sayfa kenar boşluğu ekran büyüdükçe artar', () {
      final mobil = AppBreakpoints.pagePadding(ScreenSize.mobile);
      final tablet = AppBreakpoints.pagePadding(ScreenSize.tablet);
      final masaustu = AppBreakpoints.pagePadding(ScreenSize.desktop);

      expect(mobil, lessThan(tablet));
      expect(tablet, lessThan(masaustu));
    });

    testWidgets('ResponsiveBuilder pencereyi değil AYRILAN ALANI ölçer',
        (tester) async {
      // Bir yan panelin içindeki widget, pencere geniş diye masaüstü
      // yerleşimi çizmemeli. Ölçüt widget'a verilen genişlik olmalı.
      late ScreenSize olculen;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: ResponsiveBuilder(
                builder: (context, boyut) {
                  olculen = boyut;
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );

      expect(olculen, ScreenSize.mobile);
    });

    testWidgets('ContentWidth geniş ekranda içeriği sınırlar',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 2400,
              child: ContentWidth(child: SizedBox.expand()),
            ),
          ),
        ),
      );

      final kutu = tester.getSize(find.byType(ConstrainedBox).first);
      expect(kutu.width, lessThanOrEqualTo(AppBreakpoints.maxContentWidth));
    });
  });

  // ==================================================================
  // TİPOGRAFİ
  // ==================================================================
  group('Tipografi', () {
    test('başlık ve rakamlar Barlow Condensed kullanır', () {
      expect(AppTypography.cardPower.fontFamily, AppTypography.displayFamily);
      expect(AppTypography.h1.fontFamily, AppTypography.displayFamily);
      expect(AppTypography.button.fontFamily, AppTypography.displayFamily);
      expect(AppTypography.label.fontFamily, AppTypography.displayFamily);
    });

    test('metinler Nunito kullanır', () {
      expect(AppTypography.bodyM.fontFamily, AppTypography.bodyFamily);
      expect(AppTypography.bodyS.fontFamily, AppTypography.bodyFamily);
      expect(AppTypography.name.fontFamily, AppTypography.bodyFamily);
    });

    test('Nunito DEĞİŞKEN font olduğu için wght ekseni yazılır', () {
      // fontWeight tek başına yeterli olmuyor; bkz. AppTypography
      // sınıf açıklaması. Bu test o düzeltmenin geri alınmasını
      // engellemek için var.
      final stil = AppTypography.body(size: 14, weight: FontWeight.w800);

      expect(stil.fontVariations, isNotNull);
      expect(stil.fontVariations!.single.axis, 'wght');
      expect(stil.fontVariations!.single.value, 800);
      expect(stil.fontWeight, FontWeight.w800);
    });

    test('yedek aileler tanımlı: font yüklenemezse yazı taşmasın', () {
      // Barlow Condensed DAR bir font. Yedeği geniş bir aile olursa
      // 3 haneli kart gücü karta sığmaz.
      expect(AppTypography.cardPower.fontFamilyFallback, isNotEmpty);
      expect(
        AppTypography.cardPower.fontFamilyFallback,
        contains('Arial Narrow'),
      );
    });

    test('tema metin ölçeği de aynı ailelere bağlanır', () {
      final tema = AppTheme.dark;

      expect(tema.textTheme.titleLarge?.fontFamily,
          AppTypography.displayFamily);
      expect(tema.textTheme.bodyMedium?.fontFamily, AppTypography.bodyFamily);
    });
  });

  // ==================================================================
  // SAYAÇ HAPI
  // ==================================================================
  group('StatChip', () {
    testWidgets('binlik ayracı Türkçe biçimde nokta ile yazılır',
        (tester) async {
      await tester.pumpWidget(sar(StatChip.coins(51000)));
      expect(find.text('51.000'), findsOneWidget);
    });

    testWidgets('dört basamaktan küçük sayıda ayraç yok', (tester) async {
      await tester.pumpWidget(sar(StatChip.rating(999)));
      expect(find.text('999'), findsOneWidget);
    });

    testWidgets('koruma hakkı "kullanılan/üst sınır" gösterir',
        (tester) async {
      await tester.pumpWidget(sar(StatChip.protection(5, 10)));
      expect(find.text('5'), findsOneWidget);
      expect(find.text('/10'), findsOneWidget);
    });
  });

  // ==================================================================
  // ELDEKİ KART — KİMYA ROZETİ
  // ==================================================================
  group('HandCardTile kimya rozeti', () {
    testWidgets('kimyası olan kartta "+N" rozeti görünür', (tester) async {
      await tester.pumpWidget(sar(
        HandCardTile(card: kart(kimya: 3), isPlayable: true, width: 110),
      ));

      expect(find.text('+3'), findsOneWidget);
    });

    testWidgets('kimyası SIFIR olan kartta rozet YOK', (tester) async {
      // Sıfır bonusu "+0" diye göstermek gürültüdür; oyuncu her karta
      // rozet görünce rozetin anlamını kaybeder.
      await tester.pumpWidget(sar(
        HandCardTile(card: kart(kimya: 0), isPlayable: true, width: 110),
      ));

      expect(find.textContaining('+'), findsNothing);
    });

    testWidgets('seçili kartta MAÇTAKİ GERÇEK güç yazılır', (tester) async {
      // Turu belirleyen sayı 83 değil 86. Oyuncu kararını bu sayıya
      // bakarak vermeli.
      await tester.pumpWidget(sar(
        HandCardTile(
          card: kart(guc: 83, kimya: 3),
          isPlayable: true,
          isSelected: true,
          width: 110,
        ),
      ));

      expect(find.text('MAÇTA 86'), findsOneWidget);
    });

    testWidgets('seçili DEĞİLSE gerçek güç etiketi gösterilmez',
        (tester) async {
      await tester.pumpWidget(sar(
        HandCardTile(
          card: kart(guc: 83, kimya: 3),
          isPlayable: false,
          width: 110,
        ),
      ));

      expect(find.text('MAÇTA 86'), findsNothing);
    });

    testWidgets('oynanamayan kart soluk çizilir ama SİLİNMEZ',
        (tester) async {
      // Oyuncunun elinde ne olduğunu görmesi taktik için gerekli.
      await tester.pumpWidget(sar(
        HandCardTile(card: kart(), isPlayable: false, width: 110),
      ));

      final opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(HandCardTile),
          matching: find.byType(Opacity),
        ).first,
      );

      expect(opacity.opacity, lessThan(1.0));
      expect(opacity.opacity, greaterThan(0.0));
    });

    testWidgets('devre dışıyken dokunma hamle tetiklemez', (tester) async {
      var dokunuldu = false;

      await tester.pumpWidget(sar(
        HandCardTile(
          card: kart(),
          isPlayable: true,
          isEnabled: false,
          width: 110,
          onTap: () => dokunuldu = true,
        ),
      ));

      await tester.tap(find.byType(HandCardTile), warnIfMissed: false);
      await tester.pump();

      expect(dokunuldu, isFalse);
    });
  });

  // ==================================================================
  // SAYAÇ HALKASI
  // ==================================================================
  group('TurnRing', () {
    testWidgets('kalan saniye yazılır', (tester) async {
      await tester.pumpWidget(sar(const TurnRing(
        remaining: Duration(seconds: 32),
        isMyTurn: true,
        isUrgent: false,
      )));

      expect(find.text('32'), findsOneWidget);
    });

    testWidgets('süre bitince NEGATİF sayı gösterilmez', (tester) async {
      // Sunucu saatiyle cihaz saati arasındaki fark yüzünden kalan
      // süre eksiye düşebiliyor. "-3 SANİYE" yazmak hatalı görünür.
      await tester.pumpWidget(sar(const TurnRing(
        remaining: Duration(seconds: -5),
        isMyTurn: true,
        isUrgent: true,
      )));

      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('süre dolmak üzereyken renk tehlikeye döner',
        (tester) async {
      await tester.pumpWidget(sar(const TurnRing(
        remaining: Duration(seconds: 4),
        isMyTurn: true,
        isUrgent: true,
      )));

      final metin = tester.widget<Text>(find.text('4'));
      expect(metin.style?.color, AppColors.danger);
    });

    testWidgets('sıra rakipteyken sayaç sönük çizilir', (tester) async {
      await tester.pumpWidget(sar(const TurnRing(
        remaining: Duration(seconds: 30),
        isMyTurn: false,
        isUrgent: false,
      )));

      final metin = tester.widget<Text>(find.text('30'));
      expect(metin.style?.color, AppColors.textSecondary);
    });
  });

  // ==================================================================
  // MASADAKİ KART
  // ==================================================================
  group('PlayedMoveCard', () {
    testWidgets('pas geçilen hamle "PAS GEÇTİ" olarak çizilir',
        (tester) async {
      await tester.pumpWidget(sar(const PlayedMoveCard(
        move: MatchMove(roundNumber: 3, userId: 'u1', isPass: true),
        width: 120,
      )));

      expect(find.text('PAS GEÇTİ'), findsOneWidget);
    });

    testWidgets('eksik kart bilgisi çökmeye yol açmaz', (tester) async {
      // Sunucudan pozisyonu/seviyesi olmayan bir hamle gelirse ekran
      // kırmızı hata vermek yerine pas kartı çizmeli.
      await tester.pumpWidget(sar(const PlayedMoveCard(
        move: MatchMove(roundNumber: 3, userId: 'u1'),
        width: 120,
      )));

      expect(tester.takeException(), isNull);
    });

    testWidgets('oynanan kartın kimya rozeti masada da görünür',
        (tester) async {
      await tester.pumpWidget(sar(const PlayedMoveCard(
        move: MatchMove(
          roundNumber: 3,
          userId: 'u1',
          position: CardPosition.forward,
          tier: CardTier.gold,
          power: 84,
          chemistry: 2,
          fullName: 'Galli',
        ),
        width: 120,
      )));

      expect(find.text('+2'), findsOneWidget);
    });
  });

  // ==================================================================
  // BOŞ YUVA
  // ==================================================================
  group('EmptyPlaySlot', () {
    testWidgets('verilen yönerge yazılır', (tester) async {
      await tester.pumpWidget(sar(const EmptyPlaySlot(
        width: 120,
        message: 'Orta saha kartı seç',
      )));

      expect(find.text('Orta saha kartı seç'), findsOneWidget);
    });

    testWidgets('sıra rakipteyken yuva sönük renkte olur', (tester) async {
      await tester.pumpWidget(sar(const EmptyPlaySlot(
        width: 120,
        message: 'Sıra rakipte',
        isActive: false,
      )));

      final metin = tester.widget<Text>(find.text('Sıra rakipte'));
      expect(metin.style?.color, AppColors.textSecondary);
    });
  });
}
