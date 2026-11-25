// KLAVYE ERİŞİMİ (web / masaüstü): Tab ile odak, Enter / Boşluk ile basma,
// odak halkası yalnız klavyeyle gezinirken görünür.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/ui_v21/ui_v21.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Widget host(List<Widget> children) => MaterialApp(home: Scaffold(body: Column(children: children)));

  testWidgets('oyun düğmesi: Tab ile odak, Enter ve Boşluk ile basılır', (t) async {
    var a = 0;
    var b = 0;
    await t.pumpWidget(host([
      V21GameButton(label: 'BİRİNCİ', onPressed: () => a++),
      V21GameButton(label: 'İKİNCİ', onPressed: () => b++),
    ]));
    expect(find.byKey(const ValueKey('v21-odak-halkasi')), findsNothing, reason: 'dokunmatikte halka yok');

    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pump();
    expect(find.byKey(const ValueKey('v21-odak-halkasi')), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pump();
    expect(a, 1);

    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.space);
    await t.pump();
    expect(b, 1);
    expect(a, 1);
  });

  testWidgets('pasif düğme odak almaz ve basılmaz', (t) async {
    var a = 0;
    await t.pumpWidget(host([
      const V21GameButton(label: 'PASİF', onPressed: null),
      V21GameButton(label: 'AKTİF', onPressed: () => a++),
    ]));
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pump();
    expect(a, 1, reason: 'Tab pasif düğmeyi atlayıp aktif olana gitmeli');
  });

  testWidgets('dokunma alanı (V21Tap): Tab ile odak, Enter ile çalışır', (t) async {
    var a = 0;
    await t.pumpWidget(host([
      const V21Tap(child: SizedBox(width: 40, height: 40)),
      V21Tap(onTap: () => a++, child: const SizedBox(width: 40, height: 40)),
    ]));
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pump();
    expect(find.byKey(const ValueKey('v21-odak-halkasi')), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pump();
    expect(a, 1);
  });

  testWidgets('dokunmayla basınca da çalışır (eski davranış korunur)', (t) async {
    var a = 0;
    await t.pumpWidget(host([V21GameButton(label: 'BAS', onPressed: () => a++)]));
    await t.tap(find.text('BAS'));
    await t.pump();
    expect(a, 1);
    expect(find.byKey(const ValueKey('v21-odak-halkasi')), findsNothing);
  });
}
