import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/theme/app_theme.dart';
import 'package:futbol_card/features/match/domain/clash_event.dart';
import 'package:futbol_card/features/match/presentation/widgets/tactic_widgets.dart';
import 'package:shared_models/shared_models.dart';

/// Taktik sistemi (021_tactics.sql) arayüz testleri.
///
/// Bu testler istemcinin HİÇBİR SONUÇ HESAPLAMADIĞINI da gözetir:
/// çatışma açıklamaları sunucunun kaydettiği bonus ve kazanandan
/// türetilir.
void main() {
  const ben = 'u-ben';

  MatchMove hamle({
    required bool mine,
    required int power,
    int chemistry = 0,
    MatchTactic? tactic = MatchTactic.none,
    int bonus = 0,
    bool lead = false,
    CardTier tier = CardTier.gold,
  }) =>
      MatchMove(
        roundNumber: 3,
        userId: mine ? ben : 'rakip',
        isMine: mine,
        isLead: lead,
        position: CardPosition.midfielder,
        tier: tier,
        power: power,
        chemistry: chemistry,
        tactic: tactic,
        tacticBonus: bonus,
      );

  ClashEvent olay(MatchMove benim, MatchMove rakip, {String? kazanan}) =>
      ClashEvent.fromServer(
        round: MatchRound(
          roundNumber: 3,
          winnerId: kazanan,
          isDraw: kazanan == null,
        ),
        moves: [benim, rakip],
        myUserId: ben,
      );

  group('Çatışma açıklaması (sunucu sonucunu açıklar, hesaplamaz)', () {
    test('taktiğim eli çevirdiyse söylenir', () {
      final e = olay(
        hamle(mine: true, power: 80, tactic: MatchTactic.highPress, bonus: 9),
        hamle(mine: false, power: 85),
        kazanan: ben,
      );
      expect(e.wonByTactic, isTrue);
      expect(e.detail, 'Yüksek Pres eli çevirdi! (+9)');
    });

    test('rakibin taktiği eli çevirdiyse söylenir', () {
      final e = olay(
        hamle(mine: true, power: 88, tactic: MatchTactic.highPress, bonus: 0),
        hamle(
            mine: false,
            power: 80,
            tactic: MatchTactic.counterAttack,
            bonus: 13),
        kazanan: 'rakip',
      );
      expect(e.wonByTactic, isTrue);
      expect(e.detail, contains('Rakibin Kontra Atak taktiği'));
    });

    test('zaten güçlü olan kazandıysa "taktik çevirdi" denmez', () {
      final e = olay(
        hamle(mine: true, power: 90, tactic: MatchTactic.highPress, bonus: 9),
        hamle(mine: false, power: 80),
        kazanan: ben,
      );
      expect(e.wonByTactic, isFalse);
    });

    test('kırılan taktik açıklanır', () {
      final e = olay(
        hamle(
            mine: true,
            power: 85,
            tactic: MatchTactic.counterAttack,
            bonus: 0),
        hamle(
            mine: false,
            power: 86,
            tactic: MatchTactic.defensiveWall,
            bonus: 6),
        kazanan: 'rakip',
      );
      expect(e.myTacticCountered, isTrue);
      expect(e.detail,
          'Kontra Atak boşa gitti: rakip Savunma Duvarı oynadı.');
    });

    test('Legend kuralı açıklaması taktikten önce gelir', () {
      final e = olay(
        hamle(mine: true, power: 60, tier: CardTier.legend),
        hamle(
            mine: false,
            power: 95,
            tier: CardTier.diamond,
            tactic: MatchTactic.highPress,
            bonus: 9),
        kazanan: ben,
      );
      expect(e.wonByLegendRule, isTrue);
      expect(e.wonByTactic, isFalse);
      expect(e.detail, startsWith('Legend kuralı'));
    });
  });

  Widget sar(Widget w) => MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(body: Center(child: w)),
      );

  group('Taktik çubuğu', () {
    testWidgets('üç taktik ve enerji görünür; yetmeyen pasif', (t) async {
      final secilenler = <MatchTactic>[];
      await t.pumpWidget(sar(SizedBox(
        width: 340,
        child: TacticBar(
          energy: 2,
          maxEnergy: 5,
          selected: MatchTactic.none,
          isEnabled: (x) => x.isAffordable(2),
          onSelect: secilenler.add,
        ),
      )));

      expect(find.text('PRES'), findsOneWidget);
      expect(find.text('KONTRA'), findsOneWidget);
      expect(find.text('DUVAR'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      await t.tap(find.text('PRES'));
      await t.tap(find.text('KONTRA'));
      expect(secilenler, [MatchTactic.counterAttack],
          reason: 'Enerji 2 iken pres (3) seçilememeli');
      expect(t.takeException(), isNull);
    });

    testWidgets('en dar telefonda (320px) taşmaz', (t) async {
      await t.pumpWidget(sar(SizedBox(
        width: 288, // 320 - iki yanda 16px boşluk
        child: TacticBar(
          energy: 5,
          maxEnergy: 5,
          selected: MatchTactic.highPress,
          isEnabled: (_) => true,
          onSelect: (_) {},
        ),
      )));
      expect(t.takeException(), isNull);
    });
  });

  group('Taktik rozeti', () {
    testWidgets('gizli taktik "TAKTİK ?" olarak görünür', (t) async {
      await t.pumpWidget(sar(TacticBadge(
        move: hamle(mine: false, power: 80, tactic: null, lead: true),
        resolved: false,
      )));
      expect(find.text('TAKTİK ?'), findsOneWidget);
    });

    testWidgets('bonus alan taktik "+bonus" gösterir', (t) async {
      await t.pumpWidget(sar(TacticBadge(
        move: hamle(mine: true, power: 80, tactic: MatchTactic.highPress, bonus: 9),
      )));
      expect(find.text('PRES +9'), findsOneWidget);
    });

    testWidgets('kırılan taktik üstü çizili gösterilir', (t) async {
      await t.pumpWidget(sar(TacticBadge(
        move: hamle(
            mine: true, power: 80, tactic: MatchTactic.highPress, bonus: 0),
      )));
      final metin = t.widget<Text>(find.text('PRES'));
      expect(metin.style?.decoration, TextDecoration.lineThrough);
    });

    testWidgets('taktik yoksa rozet çizilmez', (t) async {
      await t.pumpWidget(sar(TacticBadge(
        move: hamle(mine: true, power: 80),
      )));
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('çözülmemiş turda kendi taktiğim bonussuz görünür',
        (t) async {
      await t.pumpWidget(sar(TacticBadge(
        move: hamle(mine: true, power: 80, tactic: MatchTactic.defensiveWall),
        resolved: false,
      )));
      expect(find.text('DUVAR'), findsOneWidget);
      final metin = t.widget<Text>(find.text('DUVAR'));
      expect(metin.style?.decoration, isNot(TextDecoration.lineThrough));
    });
  });
}
