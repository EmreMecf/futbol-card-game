// Canlı testte bulunan: 4-4 biten (hükmen) maçta sonuç ekranı ve geçmiş
// "kaybettin" diyordu, oyuncu nedenini anlamıyordu.
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/ui_v21/screens/rewards/v21_match_result.dart';
import 'package:shared_models/shared_models.dart';

MatchResultSummary _sonuc({required bool kazandim, required int ben, required int rakip, bool berabere = false}) =>
    MatchResultSummary(matchId: 'm', didIWin: kazandim, isDraw: berabere, myScore: ben, opponentScore: rakip);

void main() {
  test('skorla biten maç hükmen sayılmaz', () {
    expect(matchEndedByForfeit(_sonuc(kazandim: true, ben: 12, rakip: 4)), isFalse);
    expect(matchEndedByForfeit(_sonuc(kazandim: false, ben: 4, rakip: 12)), isFalse);
    expect(matchEndedByForfeit(_sonuc(kazandim: false, ben: 6, rakip: 6, berabere: true)), isFalse);
  });

  test('eşit ya da önde biterken kaybedilen maç hükmendir', () {
    expect(matchEndedByForfeit(_sonuc(kazandim: false, ben: 4, rakip: 4)), isTrue);
    expect(matchEndedByForfeit(_sonuc(kazandim: false, ben: 6, rakip: 2)), isTrue);
  });

  test('geride ya da eşitken kazanılan maç hükmendir (rakip bıraktı)', () {
    expect(matchEndedByForfeit(_sonuc(kazandim: true, ben: 0, rakip: 0)), isTrue);
    expect(matchEndedByForfeit(_sonuc(kazandim: true, ben: 2, rakip: 4)), isTrue);
  });
}
