import 'package:shared_models/shared_models.dart';
import 'package:test/test.dart';

/// 022_match_league_change.sql cevabinin modeli.
void main() {
  Map<String, dynamic> rank(String kod, String ad, int seviye, int tier,
          int mmr) =>
      {
        'mmr': mmr,
        'tier_id': tier,
        'league_code': kod,
        'league_name': ad,
        'division': seviye,
        'color': '#22D3EE',
        'tier_min_mmr': 1300,
        'next_tier_mmr': 1400,
        'progress': 0.15,
        'is_top_tier': false,
      };

  test('sunucu JSON\'u okunur: Amatör 3 -> Usta 1 yükselme', () {
    final s = MatchResultSummary.fromJson({
      'match_id': 'm1',
      'did_i_win': true,
      'league_change': {
        'mmr_before': 1290,
        'mmr_after': 1315,
        'mmr_delta': 25,
        'rank_before': rank('amateur', 'Amatör', 3, 3, 1290),
        'rank_after': rank('usta', 'Usta', 1, 4, 1315),
        'direction': 'promoted',
      },
    });
    final d = s.leagueChange!;
    expect(d.isPromoted, isTrue);
    expect(d.isDemoted, isFalse);
    expect(d.changedLeague, isTrue);
    expect(d.mmrDelta, 25);
    expect(d.rankAfter.label, 'Usta 1');
  });

  test('aynı ligde seviye düşüşü: lig değişmedi', () {
    final d = MatchLeagueChange.fromJson({
      'mmr_before': 1405,
      'mmr_after': 1380,
      'mmr_delta': -25,
      'rank_before': rank('usta', 'Usta', 2, 5, 1405),
      'rank_after': rank('usta', 'Usta', 1, 4, 1380),
      'direction': 'demoted',
    });
    expect(d.isDemoted, isTrue);
    expect(d.changedLeague, isFalse);
  });

  test('eski maç: lig değişimi yok (null)', () {
    final s = MatchResultSummary.fromJson({'match_id': 'm1'});
    expect(s.leagueChange, isNull);
  });
}
