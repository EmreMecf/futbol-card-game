// 042: öğretici ipucu metinleri adıma ve aşamaya göre doğru mu?
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/ui_v21/screens/match/v21_tutorial_hint.dart';
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
    final (b, a) = V21TutorialHint.textFor(_durum(adim: 1, asama: 'position', lider: true));
    expect(b, 'MEVKİ SEÇ');
    expect(a, contains('mevkisini sen'));
  });

  test('mevki aşaması, rakip seçiyor', () {
    final (b, _) = V21TutorialHint.textFor(_durum(adim: 2, asama: 'position'));
    expect(b, 'RAKİP SEÇİYOR');
  });

  test('adım 2, seçim: gizli seçim anlatılır', () {
    final (b, a) = V21TutorialHint.textFor(_durum(adim: 2, asama: 'pick'));
    expect(b, 'GİZLİ SEÇİM');
    expect(a, contains('göremiyorsunuz'));
  });

  test('adım 3, seçim: taktik sayıları sunucuyla aynı', () {
    final (b, a) = V21TutorialHint.textFor(_durum(adim: 3, asama: 'pick'));
    expect(b, 'TAKTİK');
    for (final s in ['+9 (3 enerji)', '+13 (2 enerji)', '+6 (2 enerji)']) {
      expect(a, contains(s));
    }
  });

  test('kartımı oynadıysam: kart gizli, rakip bekleniyor', () {
    final (b, _) = V21TutorialHint.textFor(_durum(adim: 3, asama: 'pick', oynadim: true));
    expect(b, 'KARTIN GİZLİ');
  });

}
