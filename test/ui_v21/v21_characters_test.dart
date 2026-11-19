import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/ui_v21/ui_v21.dart';

/// 550 karakter yalnız kartlarda; maskot Efsane Kaptan ayrı görsellerde kalır.
void main() {
  test('550 kart karakteri eksiksiz ve maskot görselleri yerinde', () {
    final files = Directory('assets/v21/characters').listSync().whereType<File>().toList();
    expect(files, hasLength(V21Characters.count));
    for (var i = 0; i < V21Characters.count; i++) {
      expect(File(V21Characters.assetAt(i)).existsSync(), isTrue, reason: V21Characters.assetAt(i));
    }
    for (final a in [V21Assets.homeHero, V21Assets.victoryMascot, V21Assets.loginHeroes, V21Assets.loadingSplash]) {
      expect(File(a).existsSync(), isTrue, reason: a);
    }
  });

  test('anahtar her zaman aynı karaktere gider ve aralık dışına çıkmaz', () {
    expect(V21Characters.assetFor('Emre Yilmaz'), V21Characters.assetFor('emre yilmaz '));
    for (var i = 0; i < 2000; i++) {
      expect(V21Characters.indexFor('oyuncu-$i'), inInclusiveRange(0, V21Characters.count - 1));
    }
  });

  test('katalogdaki futbolcuların karakterleri birbirinden farklı', () {
    final sql = File('database/migrations/010_seed_cards.sql').readAsStringSync();
    final names = RegExp(
      r"^\s*\('[a-z0-9-]+', '([^']+)', '(?:GK|DEF|MID|FWD)'",
      multiLine: true,
    ).allMatches(sql).map((m) => m[1]!).toSet();
    expect(names.length, greaterThanOrEqualTo(90));
    final used = names.map(V21Characters.indexFor).toSet();
    expect(used.length, names.length);
  });

  test('eski tasarım ve yüz çizicisi kodda yok', () {
    final banned = RegExp(r'AvatarPortrait\(|AvatarSpec\.|ref_tokens|forceLegacy|kV21Home');
    final hits = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && banned.hasMatch(f.readAsStringSync()))
        .map((f) => f.path)
        .toList();
    expect(hits, isEmpty);
  });
}
