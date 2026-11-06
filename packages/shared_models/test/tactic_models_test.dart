import 'package:shared_models/shared_models.dart';
import 'package:test/test.dart';

/// Taktik sistemi (021_tactics.sql) için ortak model testleri.
void main() {
  group('MatchTactic', () {
    test('maliyetler SQL tactic_cost() ile aynı', () {
      expect(MatchTactic.none.cost, 0);
      expect(MatchTactic.defensiveWall.cost, 1);
      expect(MatchTactic.counterAttack.cost, 2);
      expect(MatchTactic.highPress.cost, 3);
    });

    test('taş-kâğıt-makas döngüsü tutarlı', () {
      for (final t in MatchTactic.playable) {
        expect(t.beats!.beatenBy, t);
        expect(t.beats, isNot(t.beatenBy));
      }
      expect(MatchTactic.highPress.beats, MatchTactic.defensiveWall);
      expect(MatchTactic.defensiveWall.beats, MatchTactic.counterAttack);
      expect(MatchTactic.counterAttack.beats, MatchTactic.highPress);
      expect(MatchTactic.none.beats, isNull);
    });

    test('enerji yetiyor mu?', () {
      expect(MatchTactic.highPress.isAffordable(2), isFalse);
      expect(MatchTactic.highPress.isAffordable(3), isTrue);
      expect(MatchTactic.none.isAffordable(0), isTrue);
    });

    test('kod dönüşümü; bilinmeyen kod "taktik yok" olur', () {
      for (final t in MatchTactic.values) {
        expect(MatchTactic.fromCode(t.code), t);
      }
      expect(MatchTactic.fromCode('hile'), MatchTactic.none);
      expect(MatchTactic.fromCode(null), MatchTactic.none);
    });
  });

  group('MatchMove taktik alanları', () {
    test('sunucu JSON\'u okunur, etkin güç bonusu içerir', () {
      final m = MatchMove.fromJson({
        'round_number': 3,
        'user_id': 'u1',
        'power': 80,
        'chemistry': 2,
        'tactic': 'high_press',
        'tactic_bonus': 9,
      });
      expect(m.tactic, MatchTactic.highPress);
      expect(m.tacticBonus, 9);
      expect(m.effectivePower, 91);
      expect(m.hasTactic, isTrue);
    });

    test('gizli taktik (null) okunur ve "taktik var" sayılmaz', () {
      final m = MatchMove.fromJson({
        'round_number': 1,
        'user_id': 'u2',
        'power': 70,
        'tactic': null,
      });
      expect(m.tactic, isNull);
      expect(m.tacticBonus, 0);
      expect(m.hasTactic, isFalse);
      expect(m.effectivePower, 70);
    });

    test('JSON gidiş-dönüş korunur', () {
      const m = MatchMove(
        roundNumber: 2,
        userId: 'u1',
        power: 75,
        tactic: MatchTactic.defensiveWall,
        tacticBonus: 6,
      );
      final json = m.toJson();
      expect(json['tactic'], 'defensive_wall');
      expect(json['tactic_bonus'], 6);
      expect(MatchMove.fromJson(json), m);
    });
  });

  group('MatchState enerji alanları', () {
    test('sunucu JSON\'u okunur', () {
      final s = MatchState.fromJson({
        'match_id': 'm1',
        'status': 'active',
        'round_number': 4,
        'my_energy': 3,
        'opponent_energy': 1,
        'max_energy': 5,
      });
      expect(s.myEnergy, 3);
      expect(s.opponentEnergy, 1);
      expect(s.maxEnergy, 5);
    });

    test('eski sunucu (enerji alanı yok) varsayılanla açılır', () {
      final s = MatchState.fromJson({
        'match_id': 'm1',
        'status': 'active',
        'round_number': 1,
      });
      expect(s.myEnergy, 0);
      expect(s.maxEnergy, 5);
    });
  });
}
