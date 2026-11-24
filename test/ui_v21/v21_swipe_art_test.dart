import 'package:material_ui/material_ui.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:futbol_card/ui_v21/layouts/v21_tab_swipe.dart';
import 'package:futbol_card/ui_v21/ui_v21.dart';

/// Alt menü sekmeleri arasında kaydırma + vektör sandık/eşya çizimleri
void main() {
  setUpAll(() => dotenv.loadFromString(envString: 'ENABLE_LOGGING=false'));

  group('Sekmeler arası kaydırma', () {
    const tabs = ['/kartlar', '/kadro', '/arena', '/magaza', '/sezon'];

    test('sola kaydırma sonraki, sağa kaydırma önceki sekme; uçta durur', () {
      expect(V21TabSwipe.targetFor(tabs, '/arena', -1), '/magaza');
      expect(V21TabSwipe.targetFor(tabs, '/arena', 1), '/kadro');
      expect(V21TabSwipe.targetFor(tabs, '/kartlar', 1), isNull);
      expect(V21TabSwipe.targetFor(tabs, '/sezon', -1), isNull);
      expect(V21TabSwipe.targetFor(tabs, '/profil', -1), isNull, reason: 'sekme olmayan sayfada kapalı');
      expect(V21TabSwipe.targetFor(tabs, '/arena', 0), isNull);
    });

    test('yön mesafeden alınır; ters işaretli hız yönü değiştirmez', () {
      expect(V21TabSwipe.direction(200, -900), 200, reason: 'sağa 200 px: hız ters gelse de sağa');
      expect(V21TabSwipe.direction(-200, 900), -200);
      expect(V21TabSwipe.direction(30, 800), 30, reason: 'kısa ama hızlı fiske');
      expect(V21TabSwipe.direction(30, -800), 0, reason: 'kısa ve çelişkili: geçiş yok');
      expect(V21TabSwipe.direction(10, 2000), 0, reason: 'dokunuş titremesi');
    });

    testWidgets('ekranda sola kaydırınca sonraki sekmeye geçer, sağa kaydırınca döner', (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);

      GoRoute route(String path) => GoRoute(
        path: path,
        pageBuilder: (context, state) => V21TabPages.page(
          state: state,
          tabs: tabs,
          route: path,
          child: Scaffold(body: Center(child: Text('SAYFA $path'))),
        ),
      );
      final router = GoRouter(initialLocation: '/arena', routes: [for (final p in tabs) route(p)]);
      addTearDown(router.dispose);
      await t.pumpWidget(MaterialApp.router(routerConfig: router));
      await t.pumpAndSettle();
      expect(find.text('SAYFA /arena'), findsOneWidget);

      await t.fling(find.text('SAYFA /arena'), const Offset(-250, 0), 1200);
      await t.pumpAndSettle();
      expect(find.text('SAYFA /magaza'), findsOneWidget);

      await t.fling(find.text('SAYFA /magaza'), const Offset(250, 0), 1200);
      await t.pumpAndSettle();
      expect(find.text('SAYFA /arena'), findsOneWidget);

      // Kısa ve yavaş bir dokunuş sekme değiştirmez
      await t.drag(find.text('SAYFA /arena'), const Offset(-20, 0));
      await t.pumpAndSettle();
      expect(find.text('SAYFA /arena'), findsOneWidget);
    });
  });

  group('Vektör çizimler', () {
    testWidgets('her nadirlikte sandık ve her eşya hatasız çizilir', (t) async {
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Wrap(
                children: [
                  for (final tier in ['bronze', 'silver', 'gold', 'diamond', 'legend', null]) ...[
                    V21ChestArt.tier(tier, width: 120),
                    V21ChestArt.tier(tier, height: 40, glowing: true),
                  ],
                  const SizedBox(width: 80, height: 70, child: V21ChestArt()),
                  for (final c in ['joker', 'mastery_book', 'chest_key', 'energy_drink', 'level_discount', 'kit'])
                    for (final tier in ['bronze', 'legend', null]) V21ItemArt(category: c, tier: tier, size: 64),
                ],
              ),
            ),
          ),
        ),
      );
      await t.pump();
      expect(t.takeException(), isNull);
      expect(find.byType(V21ChestArt), findsNWidgets(13));
      expect(find.byType(V21ItemArt), findsNWidgets(18));
    });

    test('eşya slug\'ından nadirlik okunur', () {
      expect(v21ItemTier('joker_bronze'), 'bronze');
      expect(v21ItemTier('mastery_book_legend'), 'legend');
      expect(v21ItemTier('chest_key'), isNull);
    });

    test('sandık vurgu renginden doğru metal paleti', () {
      expect(V21TierPalette.ofAccent(V21Colors.rarityBronze), V21TierPalette.bronze);
      expect(V21TierPalette.ofAccent(V21Colors.raritySilver), V21TierPalette.silver);
      expect(V21TierPalette.ofAccent(V21Colors.rarityLegend), V21TierPalette.legend);
      expect(V21TierPalette.ofAccent(V21Colors.rarityGold), V21TierPalette.gold);
    });
  });
}
