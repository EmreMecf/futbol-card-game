// BİLDİRİM + ALT MENÜ: alttan çıkan bildirim (SnackBar) menünün üstüne
// binip dokunmayı yutmamalı (uçtan uca testte bulundu: kayıttan sonraki
// "Hesabın oluşturuldu" bildirimi 3 sn boyunca KARTLAR'ı engelliyordu).
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/ui_v21/ui_v21.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('bildirim açıkken alt menüye dokunulabilir', (t) async {
    t.view.physicalSize = const Size(500, 749);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    var basildi = 0;
    late BuildContext govde;

    await t.pumpWidget(MaterialApp(
      home: V21ScreenLayout(
        background: const SizedBox.expand(),
        body: (context, _) {
          govde = context;
          return const SizedBox.expand();
        },
        bottomNavigation: (context, sc) => V21BottomNavigation(
          items: [
            for (final ad in ['KARTLAR', 'KADRO', 'ARENA'])
              V21NavItem(label: ad, route: '/$ad', icon: (s) => SizedBox(width: s, height: s)),
          ],
          activeIndex: 2,
          scale: sc.s,
          onSelect: (_) => basildi++,
        ),
      ),
    ));

    ScaffoldMessenger.of(govde).showSnackBar(
      const SnackBar(content: Text('Hesabın oluşturuldu!'), duration: Duration(seconds: 3)),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 400)); // açılma animasyonu
    expect(find.text('Hesabın oluşturuldu!'), findsOneWidget);

    // Bildirim görünürken menü düğmesi hâlâ dokunmayı alıyor
    expect(find.text('KARTLAR').hitTestable(), findsOneWidget);
    await t.tap(find.text('KARTLAR'));
    expect(basildi, 1);

    // Bildirim menünün üstünde durur, ona binmez
    // (SnackBar kutusu kenar boşluğunu da içerir; yazının altına bakılır)
    final bildirimAlti = t.getBottomLeft(find.text('Hesabın oluşturuldu!')).dy;
    final menuUstu = t.getTopLeft(find.byType(V21BottomNavigation)).dy;
    expect(bildirimAlti, lessThanOrEqualTo(menuUstu));
  });
}
