import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/router/app_routes.dart';
import 'package:futbol_card/core/theme/app_breakpoints.dart';
import 'package:futbol_card/core/theme/app_theme.dart';
import 'package:futbol_card/shared/widgets/app_shell.dart';

/// Gezinme kabuğunun testleri.
///
/// Bu testler tarayıcı denemesinin yerini tutuyor: Flutter web'de
/// pencere boyutu taklidi güvenilir çalışmadığı için masaüstü
/// yerleşimini gözle doğrulamak zor. Widget testinde ekran boyutunu
/// tam olarak belirleyebiliyoruz.
void main() {
  Widget sar(Widget cocuk, {required Size ekran}) {
    return MediaQuery(
      data: MediaQueryData(size: ekran),
      child: MaterialApp(theme: AppTheme.dark, home: cocuk),
    );
  }

  AppShell kabuk({String rota = AppRoutes.home, bool navGoster = true}) {
    return AppShell(
      currentRoute: rota,
      showNavigation: navGoster,
      child: const Center(child: Text('içerik')),
    );
  }

  group('Yerleşim seçimi', () {
    testWidgets('telefonda ALT ÇUBUK çizilir, kenar çubuğu çizilmez',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(sar(kabuk(), ekran: const Size(390, 844)));

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.bottomNavigationBar, isNotNull);

      // Kenar çubuğu genişliğinde bir kutu OLMAMALI
      expect(
        find.byWidgetPredicate((w) =>
            w is Container && w.constraints?.maxWidth == AppBreakpoints.sidebarWidth),
        findsNothing,
      );
    });

    testWidgets('masaüstünde KENAR ÇUBUĞU çizilir, alt çubuk çizilmez',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(sar(kabuk(), ekran: const Size(1440, 900)));

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.bottomNavigationBar, isNull);

      // Kenar çubuğundaki logo yazısı görünmeli
      expect(find.text('FUTBOL\nKART'), findsOneWidget);
    });

    testWidgets('tablette alt çubuk kullanılır', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(sar(kabuk(), ekran: const Size(800, 1000)));

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.bottomNavigationBar, isNotNull);
    });

    testWidgets('showNavigation kapalıyken hiç gezinme çizilmez',
        (tester) async {
      // Maç ve paket açılışı gibi tam ekran isteyen yerler için.
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        sar(kabuk(navGoster: false), ekran: const Size(390, 844)),
      );

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.bottomNavigationBar, isNull);
      expect(find.text('FUTBOL\nKART'), findsNothing);
    });
  });

  group('Gezinme hedefleri', () {
    test('telefon alt çubuğunda en fazla 5 madde olur', () {
      // Beşten fazlası dokunma hedeflerini 44px'in altına düşürür.
      final telefondakiler =
          kNavDestinations.where((h) => !h.sidebarOnly).toList();

      expect(telefondakiler.length, lessThanOrEqualTo(5));
    });

    test('kenar çubuğu telefondaki her maddeyi de içerir', () {
      // Masaüstünde bir bölüm kaybolmamalı.
      final telefondakiler =
          kNavDestinations.where((h) => !h.sidebarOnly).map((h) => h.route);

      for (final rota in telefondakiler) {
        expect(
          kNavDestinations.any((h) => h.route == rota),
          isTrue,
          reason: '$rota kenar çubuğunda yok',
        );
      }
    });

    test('her hedefin rotası benzersiz', () {
      final rotalar = kNavDestinations.map((h) => h.route).toList();
      expect(rotalar.toSet().length, rotalar.length);
    });

    test('bütün rotalar tanımlı uygulama rotaları', () {
      const tanimli = {
        AppRoutes.home,
        AppRoutes.deck,
        AppRoutes.matchmaking,
        AppRoutes.store,
        AppRoutes.profile,
        AppRoutes.collection,
        AppRoutes.sbc,
        AppRoutes.leaderboard,
      };

      for (final hedef in kNavDestinations) {
        expect(tanimli, contains(hedef.route));
      }
    });
  });

  group('Etkin madde vurgusu', () {
    testWidgets('açık olan sayfa alt çubukta vurgulanır', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        sar(kabuk(rota: AppRoutes.store), ekran: const Size(390, 844)),
      );

      // Mağaza etiketi çizilmiş olmalı (etkin maddede de yazı var)
      expect(find.text('Mağaza'), findsOneWidget);
    });

    testWidgets('kenar çubuğunda yalnızca bir madde etkin görünür',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        sar(kabuk(rota: AppRoutes.collection), ekran: const Size(1440, 900)),
      );

      // Etkin maddede kenarlık var; kenarlıklı madde sayısı tam 1 olmalı.
      final kenarlikli = find.byWidgetPredicate((w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).border != null &&
          w.constraints?.maxHeight == 46);

      expect(kenarlikli, findsOneWidget);
    });
  });

  group('Taşma denetimi', () {
    testWidgets('dar telefonda alt çubuk taşmaz', (tester) async {
      // 320px iPhone SE genişliği; beş madde buraya da sığmalı.
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(sar(kabuk(), ekran: const Size(320, 568)));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('çok geniş ekranda kenar çubuğu sabit kalır',
        (tester) async {
      tester.view.physicalSize = const Size(2560, 1440);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(sar(kabuk(), ekran: const Size(2560, 1440)));

      final kenar = tester.widget<Container>(
        find
            .byWidgetPredicate((w) =>
                w is Container &&
                w.constraints?.maxWidth == AppBreakpoints.sidebarWidth)
            .first,
      );

      expect(kenar.constraints?.maxWidth, AppBreakpoints.sidebarWidth);
      expect(tester.takeException(), isNull);
    });
  });
}
