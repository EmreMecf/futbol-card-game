// 042: öğretici ipucu metinleri adıma ve aşamaya göre doğru mu?
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/features/match/presentation/widgets/tutorial_hint.dart';
import 'package:shared_models/shared_models.dart';

MatchState _durum({required int adim, String? asama, bool lider = false, bool oynadim = false}) => MatchState(
      matchId: 'm',
      status: MatchStatus.active,
      roundNumber: 1,
      mode: 'tutorial',
      tutorialStep: adim,
      simultaneous: true,
      phase: asama,
      amILead: lider,
      iHavePlayed: oynadim,
    );

void main() {
  test('adım 1, mevki aşaması, inisiyatif bende: mevki seç', () {
    final (b, a) = TutorialHint.textFor(_durum(adim: 1, asama: 'position', lider: true));
    expect(b, 'MEVKİ SEÇ');
    expect(a, contains('mevkisini sen'));
  });

  test('mevki aşaması, rakip seçiyor', () {
    final (b, _) = TutorialHint.textFor(_durum(adim: 2, asama: 'position'));
    expect(b, 'RAKİP SEÇİYOR');
  });

  test('adım 2, seçim: gizli seçim anlatılır', () {
    final (b, a) = TutorialHint.textFor(_durum(adim: 2, asama: 'pick'));
    expect(b, 'GİZLİ SEÇİM');
    expect(a, contains('göremiyorsunuz'));
  });

  test('adım 3, seçim: taktik sayıları sunucuyla aynı', () {
    final (b, a) = TutorialHint.textFor(_durum(adim: 3, asama: 'pick'));
    expect(b, 'TAKTİK');
    for (final s in ['+9 (3 enerji)', '+13 (2 enerji)', '+6 (2 enerji)']) {
      expect(a, contains(s));
    }
  });

  test('kartımı oynadıysam: kart gizli, rakip bekleniyor', () {
    final (b, _) = TutorialHint.textFor(_durum(adim: 3, asama: 'pick', oynadim: true));
    expect(b, 'KARTIN GİZLİ');
  });

  testWidgets('ipucu paneli adımı gösterir ve taşmaz (320 px)', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: TutorialHint(state: _durum(adim: 3, asama: 'pick'), forceLegacy: true))),
    ));
    expect(find.textContaining('ÖĞRETİCİ 3/3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
