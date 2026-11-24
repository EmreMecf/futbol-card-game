// 043: KUPA YOLU — model metni, ViewModel ve Ligler ekranındaki gösterim.
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/features/leaderboard/presentation/viewmodel/league_tiers_view_model.dart';
import 'package:shared_models/shared_models.dart';

import 'goldens/sahte_veri.dart';

const _yol = TrophyRoad(enabled: true, currentTier: 5, bestTier: 5, tiers: [
  TrophyRoadTier(tierId: 1, leagueCode: 'amateur', status: 'reached_before'),
  TrophyRoadTier(tierId: 2, leagueCode: 'amateur', reward: {'chest': 'silver', 'coins': 50}, status: 'granted'),
  TrophyRoadTier(tierId: 4, leagueCode: 'usta',
      reward: {'chest': 'gold', 'coins': 100, 'cosmetic': 'frame_league_usta'}, status: 'granted'),
  TrophyRoadTier(tierId: 10, leagueCode: 'master_class', reward: {'chest': 'legend', 'coins': 300}, status: 'locked'),
]);

void main() {
  test('ödül metni sunucu tablosuyla aynı', () {
    expect(_yol.tiers[1].rewardText, 'Gümüş sandık · +50 altın');
    expect(_yol.tiers[2].rewardText, 'Altın sandık · +100 altın · çerçeve');
    expect(_yol.tiers[3].rewardText, 'Efsane sandık · +300 altın');
    expect(_yol.tiers[0].rewardText, '', reason: 'Amatör 1 ödülsüz');
  });

  test('JSON: sunucunun snake_case alanları okunur', () {
    final y = TrophyRoad.fromJson({
      'enabled': true,
      'current_tier': 2,
      'tiers': [
        {'tier_id': 2, 'league_code': 'amateur', 'min_mmr': 1100, 'reward': {'chest': 'silver', 'coins': 50}, 'status': 'granted'},
      ],
    });
    expect(y.tiers.single.isGranted, isTrue);
    expect(y.tiers.single.minMmr, 1100);
  });

  test('ViewModel: kayıt yoksa kupa yolu yok (bugünkü ekran)', () async {
    final vm = LeagueTiersViewModel(GoldenLeaderboardRepo());
    await vm.initialize();
    expect(vm.trophyRoad, isNull);
    expect(vm.trophyTier(2), isNull);
  });

  test('ViewModel: anahtar kapalıysa gösterilmez', () async {
    final vm = LeagueTiersViewModel(GoldenLeaderboardRepo(),
        trophyRoad: () async => const TrophyRoad(enabled: false, tiers: [TrophyRoadTier(tierId: 2)]));
    await vm.initialize();
    expect(vm.trophyRoad, isNull);
  });

  test('ViewModel: açıkken basamak bilgisi', () async {
    final vm = LeagueTiersViewModel(GoldenLeaderboardRepo(), trophyRoad: () async => _yol);
    await vm.initialize();
    expect(vm.trophyTier(4)?.isGranted, isTrue);
    expect(vm.trophyTier(10)?.isLocked, isTrue);
    expect(vm.trophyTier(7), isNull);
  });

  testWidgets('ödül metni dar basamak kutusunda taşmaz', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Row(children: [
          for (final t in _yol.tiers.skip(1))
            Expanded(child: Text(t.rewardText, textAlign: TextAlign.center, maxLines: 3, style: const TextStyle(fontSize: 9))),
        ]),
      ),
    ));
    expect(tester.takeException(), isNull);
  });
}
