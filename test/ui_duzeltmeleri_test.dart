// Arayüz incelemesi düzeltmeleri: maç eli sırası, sonuç metinleri,
// öğretici düğmesi, sandık kaynağı ve günlük panel metni.
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/features/chests/presentation/view/chests_view.dart';
import 'package:futbol_card/features/daily/presentation/daily_panel.dart';
import 'package:futbol_card/features/match/presentation/view/match_view.dart';
import 'package:futbol_card/features/match/presentation/widgets/match_result_view.dart';
import 'package:shared_models/shared_models.dart';

HandCard _kart(String id, CardPosition p, int guc, {bool oynandi = false}) => HandCard(
      userCardId: id,
      cardId: id,
      fullName: id,
      position: p,
      tier: CardTier.bronze,
      power: guc,
      isPlayed: oynandi,
    );

void main() {
  group('maç eli sırası', () {
    final el = [
      _kart('kaleci', CardPosition.goalkeeper, 60),
      _kart('defans', CardPosition.defender, 55),
      _kart('forvet-zayif', CardPosition.forward, 50),
      _kart('orta', CardPosition.midfielder, 70),
      _kart('forvet-guclu', CardPosition.forward, 72),
      _kart('forvet-oynandi', CardPosition.forward, 90, oynandi: true),
    ];

    test('istenen mevkinin kartları başta, güçlü önce; oynananlar yok', () {
      final sira = handOrder(el, CardPosition.forward).map((k) => k.userCardId).toList();
      expect(sira, ['forvet-guclu', 'forvet-zayif', 'kaleci', 'defans', 'orta']);
    });

    test('mevki yoksa eski sıra korunur', () {
      expect(handOrder(el, null).map((k) => k.userCardId), ['kaleci', 'defans', 'forvet-zayif', 'orta', 'forvet-guclu']);
    });
  });

  group('maç sonucu', () {
    test('kart kaybı olmayan kuralda koruma açıklaması yok', () {
      const yeni = MatchResultSummary(matchId: 'm', didIWin: true, myScore: 12, cardTransfer: false);
      expect(yeni.noCardLossRules, isTrue);
      expect(yeni.subtitle, isNot(contains('korumasiz')));
      const ogretici = MatchResultSummary(matchId: 'm', mode: 'tutorial', didIWin: true);
      expect(ogretici.noCardLossRules, isTrue);
    });

    test('kart transferli ya da bilinmeyen kuralda eski metin', () {
      const eski = MatchResultSummary(matchId: 'm', didIWin: true, cardTransfer: true);
      expect(eski.noCardLossRules, isFalse);
      expect(eski.subtitle, contains('korumasiz'));
      const bilinmiyor = MatchResultSummary(matchId: 'm', didIWin: true);
      expect(bilinmiyor.noCardLossRules, isFalse);
    });

    test('sunucu JSON: card_transfer okunur', () {
      final s = MatchResultSummary.fromJson({'match_id': 'm', 'card_transfer': false});
      expect(s.cardTransfer, isFalse);
    });

    test('öğreticide ana düğme sıradaki adıma yönlendirir', () {
      expect(newMatchLabel(const MatchResultSummary(matchId: 'm')), 'YENİ MAÇ');
      expect(newMatchLabel(const MatchResultSummary(matchId: 'm', mode: 'training')), 'YENİ MAÇ');
      expect(newMatchLabel(const MatchResultSummary(matchId: 'm', mode: 'tutorial', tutorialStep: 1)), 'ÖĞRETİCİYE DEVAM');
      expect(newMatchLabel(const MatchResultSummary(matchId: 'm', mode: 'tutorial', tutorialStep: 3)), 'DERECELİ MAÇA GEÇ');
    });
  });

  test('sandık kaynağı okunur adla', () {
    expect(chestSourceLabel('daily'), 'Günlük sandık');
    expect(chestSourceLabel('match'), 'Maç ödülü');
    expect(chestSourceLabel('bilinmeyen'), 'Ödül');
  });

  test('günlük panel: yeni oyuncuya "Seri: 0 gün" yazılmaz', () {
    final (s, _) = DailyPanelTexts.texts(const DailyStatus(enabled: true, streak: 0, chestType: 'bronze'));
    expect(s, isNot(contains('Seri')));
  });
}
