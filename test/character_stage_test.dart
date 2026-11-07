import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/features/match/domain/clash_event.dart';
import 'package:futbol_card/features/match/presentation/arena/character_stage/character_stage.dart';
import 'package:shared_models/shared_models.dart';

/// Aşama A1: karakter sahnesi çekirdeği (koreografi + çizici seçimi).
void main() {
  /// 025'teki animation_clip_requirements: mevki -> klipler
  Map<String, Set<String>> dbKlipleri() {
    final sql = File('database/migrations/025_character_catalog.sql').readAsStringSync();
    final m = <String, Set<String>>{};
    for (final e in RegExp(r"\('(GK|DEF|MID|FWD)', '([a-z]+)'\)").allMatches(sql)) {
      m.putIfAbsent(e.group(1)!, () => {}).add(e.group(2)!);
    }
    return m;
  }

  group('Koreografi', () {
    test('kullanılan her klip veritabanında o mevkinin gerekli klipleri içinde', () {
      final db = dbKlipleri();
      expect(db.keys, containsAll(['GK', 'DEF', 'MID', 'FWD']));
      for (final p in CardPosition.values) {
        for (final o in ClashOutcome.values) {
          for (final c in clipsFor(p, o).clips) {
            expect(db[p.code], contains(c), reason: '${p.code} $o: $c');
          }
        }
        for (final c in [...clipsFor(p, ClashOutcome.win, iPassed: true).clips,
                         ...clipsFor(p, ClashOutcome.win, opponentPassed: true).clips]) {
          expect(db[p.code], contains(c), reason: '${p.code} pas: $c');
        }
      }
    });

    test('forvet kazanırsa şut ve sevinç, kaybederse sevinç yok', () {
      expect(clipsFor(CardPosition.forward, ClashOutcome.win).clips,
          ['run', 'dribble', 'shoot', 'celebrate']);
      expect(clipsFor(CardPosition.forward, ClashOutcome.loss).clips, isNot(contains('celebrate')));
    });

    test('sonuç sunucudan: iki tarafın koreografisi birbirinin tersi', () {
      const e = ClashEvent(
        roundNumber: 3,
        outcome: ClashOutcome.win,
        position: CardPosition.forward,
        myMove: MatchMove(roundNumber: 3, userId: 'a', isMine: true, power: 83),
        opponentMove: MatchMove(roundNumber: 3, userId: 'b', power: 80),
      );
      final k = choreographFor(e);
      expect(k.mine.clips.last, 'celebrate');
      expect(k.opponent.clips.last, 'lose');
    });

    test('pas geçen taraf boyun eğer, rakip kazanır', () {
      const e = ClashEvent(
        roundNumber: 1,
        outcome: ClashOutcome.loss,
        position: CardPosition.defender,
        myMove: MatchMove(roundNumber: 1, userId: 'a', isMine: true, isPass: true),
        opponentMove: MatchMove(roundNumber: 1, userId: 'b', power: 70),
      );
      final k = choreographFor(e);
      expect(k.mine.clips, ['idle', 'lose']);
      expect(k.opponent.clips, ['walk', 'win']);
    });
  });

  group('Çizici seçimi: hiçbir şey hazırmış gibi gösterilmez', () {
    const bos = CharacterPresentation(
      characterId: 'c',
      mode: PresentationMode.fallback25d,
      missingClips: ['shoot', 'celebrate'],
      missingAssets: ['portrait', 'model_glb', 'rig'],
    );

    test('varlık yokken 2.5B yedek seçilir, gerekçeler listelenir', () {
      final k = selectRenderer(bos);
      expect(k.chosen, RendererKind.fallback25d);
      expect(k.skipped[RendererKind.gltf3d], contains('model_glb'));
      expect(k.skipped[RendererKind.gltf3d], contains('2 animasyon klibi'));
      expect(k.skipped[RendererKind.sprite], 'Onaylı sprite sayfası yok');
    });

    test('varlıklar tam ama 3B çalıştırıcı yoksa 3B SEÇİLMEZ', () {
      const tam = CharacterPresentation(
        characterId: 'c', mode: PresentationMode.threeD,
        modelUri: 'm.glb', rigUri: 'r.glb', portraitUri: 'p.png');
      final k = selectRenderer(tam);
      expect(k.chosen, isNot(RendererKind.gltf3d));
      expect(k.skipped[RendererKind.gltf3d], contains('çalıştırıcı'));
    });

    test('çalıştırıcı kurulduğunda (gelecek) tam varlıkla 3B seçilir', () {
      const tam = CharacterPresentation(
        characterId: 'c', mode: PresentationMode.threeD, modelUri: 'm.glb', rigUri: 'r.glb');
      final k = selectRenderer(tam, renderers: const [
        GltfRenderer(runtimeInstalled: true),
        Fallback25dRenderer(),
      ]);
      expect(k.chosen, RendererKind.gltf3d);
      expect(k.skipped, isEmpty);
    });

    test('sprite sayfası var ama oynatıcı yazılmadıysa yedeğe düşer', () {
      const s = CharacterPresentation(
        characterId: 'c', mode: PresentationMode.sprite, spriteUri: 's.webp');
      final k = selectRenderer(s);
      expect(k.chosen, RendererKind.fallback25d);
      expect(k.skipped[RendererKind.sprite], contains('oynatıcı'));
    });
  });

  test('sprite sayfası düzeni: kare konumu ve zaman', () {
    const d = SpriteSheetLayout(columns: 4, frameCount: 10, frameWidth: 128, frameHeight: 160);
    expect(d.frameAt(0), 0);
    expect(d.frameAt(1), 9);
    expect(d.frameAt(0.55), 5);
    expect(d.rectOf(5), (128.0, 160.0, 128.0, 160.0));
  });
}
