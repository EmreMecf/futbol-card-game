import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/ui_v21/components/v21_character.dart';

void main() {
  test('reviewed artwork pools are disjoint and refer to valid bundled files', () {
    final seen = <int>{};
    for (final entry in V21Characters.reviewedByPosition.entries) {
      expect(entry.value, isNotEmpty, reason: entry.key);
      for (final number in entry.value) {
        expect(number, inInclusiveRange(1, 550));
        expect(seen.add(number), isTrue,
            reason: 'Illustration c$number assigned to multiple positions');
      }
    }
    expect(seen.length, V21Characters.reviewedCount);
    expect(seen.length, 550, reason: 'Every original illustration must be mapped once');
    for (var id = 1; id <= 550; id++) {
      expect(seen.contains(id), isTrue, reason: 'Unassigned image c$id');
    }
  });

  test('every card can only receive a reviewed illustration of its position', () {
    for (final entry in V21Characters.reviewedByPosition.entries) {
      final approved = entry.value.map((id) =>
        'assets/v21/characters/c${id.toString().padLeft(3, '0')}.webp'
      ).toSet();
      for (var i = 0; i < 1000; i++) {
        final portrait = V21Characters.assetFor('footballer_$i',
            position: entry.key);
        expect(approved.contains(portrait), isTrue,
            reason: 'Wrong position asset for ${entry.key}: $portrait');
        expect(V21Characters.assetFor('footballer_$i',
            position: entry.key), portrait);
      }
    }
  });

  test('different positions cannot share a portrait even with same name', () {
    for (var i = 0; i < 100; i++) {
      final values = <String>{};
      for (final role in const ['GK', 'DEF', 'MID', 'FWD']) {
        values.add(V21Characters.assetFor('same_name_$i', position: role));
      }
      expect(values.length, 4);
    }
  });

  test('six renamed legends keep their same in-position portrait', () {
    const names = <(String, String, String)>[
      ('Pele', 'Aren Solmar', 'FWD'),
      ('Diego Maradona', 'Nerio Valtan', 'MID'),
      ('Johan Cruyff', 'Elias Veyron', 'MID'),
      ('Franz Beckenbauer', 'Borek Kaldren', 'DEF'),
      ('Lev Yashin', 'Taren Volsk', 'GK'),
      ('Ferenc Puskas', 'Miran Korvek', 'FWD'),
    ];
    for (final (original, updated, position) in names) {
      expect(V21Characters.assetFor(original, position: position),
          V21Characters.assetFor(updated, position: position));
    }
  });

  test('unrecognized roles fail closed rather than selecting random assets', () {
    expect(() => V21Characters.assetFor('sample', position: 'ST'),
        throwsArgumentError);
  });
}
