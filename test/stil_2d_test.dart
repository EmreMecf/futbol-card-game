import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/di/injection.dart';
import 'package:futbol_card/core/theme/app_theme.dart';
import 'package:futbol_card/core/utils/result.dart';
import 'package:futbol_card/features/characters/data/character_repository.dart';
import 'package:futbol_card/features/characters/presentation/character_preview_view_model.dart';
import 'package:futbol_card/features/characters/presentation/style_prototype_view.dart';
import 'package:futbol_card/features/match/domain/clash_event.dart';
import 'package:futbol_card/features/match/presentation/arena/character_stage/character_stage.dart';
import 'package:futbol_card/features/match/presentation/arena/stage2d/duel_stage.dart';
import 'package:futbol_card/features/match/presentation/arena/stage2d/figure_painter.dart';
import 'package:futbol_card/features/match/presentation/arena/stage2d/figure_rig.dart';
import 'package:futbol_card/shared/widgets/arena_card/arena_card.dart';
import 'package:futbol_card/shared/widgets/arena_card/rarity_style.dart';
import 'package:futbol_card/shared/widgets/avatar2d/avatar_painter.dart';
import 'package:futbol_card/shared/widgets/avatar2d/avatar_spec.dart';
import 'package:futbol_card/shared/widgets/avatar2d/concept_characters.dart';
import 'package:shared_models/shared_models.dart';

import 'character_preview_test.dart' show sunucuCevabi;

/// Yeni 2D görsel yön: karakter tanımı, kart, iskelet, düello, prototip.
void main() {
  setUpAll(() => dotenv.loadFromString(envString: 'ENABLE_LOGGING=false'));

  group('Karakter tanımı (AvatarSpec)', () {
    test('10 konsept: adlar tekil, oyun tarzı mevkiye uygun, sadece Kaelen veritabanında', () {
      expect(kConceptCharacters, hasLength(10));
      expect(kConceptCharacters.map((k) => k.slug).toSet(), hasLength(10));
      expect(kConceptCharacters.where((k) => k.inDatabase).map((k) => k.slug), ['kaelen-brisvoy']);
      for (final k in kConceptCharacters) {
        expect(k.playstyle.position, k.position, reason: k.name);
      }
      // Her mevki en az bir konseptle temsil ediliyor (arena rakibi için)
      expect(kConceptCharacters.map((k) => k.position).toSet(), CardPosition.values.toSet());
    });

    test('her konsept JSON üzerinden kayıpsız gidip gelir', () {
      for (final k in kConceptCharacters) {
        expect(AvatarSpec.fromJson(k.spec.toJson()), k.spec, reason: k.name);
      }
    });

    test('bozuk JSON çökmez, makul varsayılan verir', () {
      final s = AvatarSpec.fromJson({'skin': 'yok', 'hair_color': 'kırmızı', 'shirt_number': 7});
      expect(s.skin, SkinTone.wheat);
      expect(s.shirtNumber, 7);
    });

    test('veritabanı görünüş metninden tahmini tanım: anahtar kelimeler ve determinizm', () {
      const a = CharacterAppearance(
        skinTone: 'açık buğday',
        hair: 'bakır',
        face: 'çilli',
        build: 'ince',
        accessory: 'turkuaz bileklik',
        shirtNumber: 17,
      );
      final s = AvatarSpec.fromAppearance('kaelen-brisvoy', a);
      expect(s.skin, SkinTone.wheat);
      expect(s.hairColor, const Color(0xFFC0622B));
      expect(s.freckles, isTrue);
      expect(s.build, BodyBuild.slim);
      expect(s.wristband, const Color(0xFF2EC4B6));
      expect(s.shirtNumber, 17);
      expect(AvatarSpec.fromAppearance('kaelen-brisvoy', a), s, reason: 'aynı slug her zaman aynı görünüş');
    });

    testWidgets('her konseptin portresi ve arena figürü hatasız çizilir', (t) async {
      await t.pumpWidget(MaterialApp(
        home: Wrap(children: [
          for (final k in kConceptCharacters) ...[
            AvatarPortrait(spec: k.spec, size: 60),
            SizedBox(width: 40, height: 60, child: CustomPaint(painter: FigurePainter(k.spec, const Pose()))),
          ],
        ]),
      ));
      expect(t.takeException(), isNull);
      expect(find.byType(AvatarPortrait), findsNWidgets(10));
    });
  });

  group('Arena kartı', () {
    testWidgets('5 nadirlik x 3 boyut taşmadan çizilir', (t) async {
      t.view.physicalSize = const Size(1400, 2400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final k = kConceptCharacters.first;
      await t.pumpWidget(MaterialApp(
        home: SingleChildScrollView(
          child: Wrap(children: [
            for (final tier in CardTier.values)
              for (final w in [96.0, 150.0, 260.0])
                ArenaCard(
                  spec: k.spec,
                  name: k.name,
                  position: k.position,
                  tier: tier,
                  power: 83,
                  subtitle: k.playstyle.label,
                  width: w,
                ),
          ]),
        ),
      ));
      await t.pump(const Duration(seconds: 2));
      expect(t.takeException(), isNull);
      expect(find.text('83'), findsNWidgets(15));
      // Küçük kartta alt satır gizli
      expect(find.text('Hızlı Kanat'), findsNWidgets(10));
    });

    testWidgets('portre yoksa PORTRE YOK açıkça yazılır', (t) async {
      await t.pumpWidget(const MaterialApp(
        home: Center(
          child: ArenaCard(
              spec: null, name: 'Eski', position: CardPosition.defender, tier: CardTier.bronze, power: 60),
        ),
      ));
      expect(find.text('PORTRE YOK'), findsOneWidget);
    });

    test('nadirlik tokenları: 5 farklı vurgu, efekt nadirlikle artar', () {
      expect(RarityStyle.all.map((s) => s.accent).toSet(), hasLength(5));
      for (var i = 1; i < RarityStyle.all.length; i++) {
        expect(RarityStyle.all[i].effect.index, greaterThan(RarityStyle.all[i - 1].effect.index));
        expect(RarityStyle.all[i].glow, greaterThan(RarityStyle.all[i - 1].glow));
      }
      for (final t in CardTier.values) {
        expect(RarityStyle.of(t).tier, t);
      }
    });
  });

  group('2D iskelet ve klipler', () {
    Iterable<List<String>> tumDiziler() sync* {
      for (final p in CardPosition.values) {
        for (final o in ClashOutcome.values) {
          yield clipsFor(p, o).clips;
        }
        yield clipsFor(p, ClashOutcome.win, iPassed: true).clips;
        yield clipsFor(p, ClashOutcome.win, opponentPassed: true).clips;
      }
    }

    test('koreografinin kullandığı her klibin 2D karşılığı var', () {
      for (final d in tumDiziler()) {
        for (final c in d) {
          expect(kFigureClips, contains(c), reason: c);
        }
      }
    });

    test('anahtar pozlar 0 ile başlar, 1 ile biter, sıralıdır', () {
      for (final c in kFigureClips.values) {
        expect(c.keys.first.t, 0, reason: c.name);
        expect(c.keys.last.t, 1, reason: c.name);
        for (var i = 1; i < c.keys.length; i++) {
          expect(c.keys[i].t, greaterThan(c.keys[i - 1].t), reason: c.name);
        }
        expect(c.durationMs, inInclusiveRange(400, 1200), reason: '${c.name}: kısa ve etkileyici');
      }
    });

    test('dizi oynatıcı: süre toplamı, klip geçişinde sıçrama yok, yol azalmaz', () {
      for (final d in tumDiziler()) {
        final o = ClipSequencePlayer(d);
        expect(o.durationMs, d.fold<int>(0, (a, n) => a + kFigureClips[n]!.durationMs));
        var bas = 0;
        for (var i = 0; i < o.clips.length - 1; i++) {
          bas += o.clips[i].durationMs;
          final once = o.poseAt(bas - 0.5);
          final sonra = o.poseAt(bas + 0.5);
          expect((once.torso - sonra.torso).abs(), lessThan(0.15), reason: '$d @ $bas');
          expect((once.legF - sonra.legF).abs(), lessThan(0.15), reason: '$d @ $bas');
        }
        var onceki = -1.0;
        for (var ms = 0.0; ms <= o.durationMs; ms += 40) {
          final y = o.travelAt(ms);
          expect(y, greaterThanOrEqualTo(onceki - 1e-9));
          onceki = y;
        }
        expect(o.clipAt(0), d.first);
        expect(o.clipAt(o.durationMs.toDouble()), d.last);
      }
    });

    test('bilinmeyen klip açık hata verir', () {
      expect(() => ClipSequencePlayer(['moonwalk']), throwsArgumentError);
    });

    test('kurtarışta top kalecinin elinde', () {
      final p = kFigureClips['save']!.poseAt(1);
      final g = FigureGeometry.of(p);
      expect((g.ball - g.handF).distance, lessThan(4));
    });

    test('2D zincirinde vektör karakter seçilir, dosya varlığı aranmaz', () {
      const bos = CharacterPresentation(
          characterId: 'c', mode: PresentationMode.fallback25d, missingAssets: ['portrait', 'model_glb', 'rig']);
      final k = selectRenderer(bos, renderers: kRenderers2d);
      expect(k.chosen, RendererKind.vector2d);
      expect(k.skipped, isEmpty);
    });
  });

  group('Karttan sahaya düello', () {
    const ben = DuelSide(spec: AvatarSpec(skin: SkinTone.light, head: HeadShape.oval, hair: HairStyle.crop,
        hairColor: Color(0xFF222222), jersey: Color(0xFF1FB5A8), jerseyTrim: Colors.white, shirtNumber: 7),
        name: 'Ben', tier: CardTier.gold, power: 83);

    test('evreler sırayla gelir', () {
      const p = CardPosition.forward, o = ClashOutcome.win;
      expect(DuelStage.phaseAt(0, p, o), DuelPhase.intro);
      expect(DuelStage.phaseAt(700, p, o), DuelPhase.launch);
      expect(DuelStage.phaseAt(1100, p, o), DuelPhase.materialize);
      expect(DuelStage.phaseAt(1400, p, o), DuelPhase.action);
      expect(DuelStage.phaseAt(DuelStage.totalMs(p, o) - 10.0, p, o), DuelPhase.result);
      expect(DuelStage.phaseAt(DuelStage.totalMs(p, o) + 10.0, p, o), DuelPhase.done);
      // Kısa ve etkileyici: tüm sahne 6 saniyeyi geçmez
      for (final m in CardPosition.values) {
        for (final s in ClashOutcome.values) {
          expect(DuelStage.totalMs(m, s), lessThan(6000), reason: '$m $s');
        }
      }
    });

    for (final (sonuc, yazi) in [
      (ClashOutcome.win, 'KAZANDIN'),
      (ClashOutcome.loss, 'KAYBETTİN'),
      (ClashOutcome.draw, 'BERABERE'),
    ]) {
      testWidgets('her mevkide sahne baştan sona oynar: $yazi', (t) async {
        for (final m in CardPosition.values) {
          var bitti = false;
          final rakip = kConceptCharacters.firstWhere((k) => k.position == m);
          await t.pumpWidget(MaterialApp(
            home: SizedBox(
              width: 400,
              height: 320,
              child: DuelStage(
                key: ValueKey('$m$sonuc'),
                me: ben,
                opponent: DuelSide(spec: rakip.spec, name: rakip.name, tier: CardTier.silver, power: 70),
                position: m,
                outcome: sonuc,
                onFinished: () => bitti = true,
              ),
            ),
          ));
          expect(find.byType(ArenaCard), findsNWidgets(2), reason: 'girişte iki kart');
          for (var ms = 0; ms < DuelStage.totalMs(m, sonuc) + 100; ms += 100) {
            await t.pump(const Duration(milliseconds: 100));
          }
          expect(t.takeException(), isNull);
          expect(find.byType(ArenaCard), findsNothing, reason: 'kartlar figüre dönüştü');
          expect(find.text(yazi), findsOneWidget);
          expect(find.text('83  -  70'), findsOneWidget);
          expect(bitti, isTrue);
        }
      });
    }
  });

  group('Prototip ekranı', () {
    Future<void> sekme(WidgetTester t, String ad) async {
      await t.tap(find.text(ad));
      for (var i = 0; i < 10; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> ac(WidgetTester t) async {
      await getIt.reset();
      getIt.registerFactory<CharacterPreviewViewModel>(
          () => CharacterPreviewViewModel(_Repo(Success(CharacterCardData.fromJson(sunucuCevabi())))));
      t.view.physicalSize = const Size(400, 1600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(theme: AppTheme.dark, home: const StylePrototypeView()));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
    }

    testWidgets('kart sekmesi: sunucu verisi, 5 nadirlik, portresiz örnek', (t) async {
      await ac(t);
      expect(t.takeException(), isNull);
      expect(find.text('KART'), findsOneWidget);
      expect(find.text('Prototip'), findsOneWidget);
      expect(find.textContaining('Gerçek nadirliği: ALTIN'), findsOneWidget);
      expect(find.text('KAELEN BRISVOY'), findsWidgets);
      expect(find.text('PORTRE YOK'), findsOneWidget);
    });

    testWidgets('detay, arena ve konsept sekmeleri açılır', (t) async {
      await ac(t);
      await sekme(t, 'DETAY');
      expect(find.text('Özellikler'), findsOneWidget);
      expect(find.text('86'), findsOneWidget); // ŞUT
      expect(find.textContaining('2D vektör karakter'), findsOneWidget);

      await sekme(t, 'ARENA');
      expect(find.byType(DuelStage), findsOneWidget);
      expect(find.textContaining('sonucu her zaman sunucu belirler'), findsOneWidget);
      expect(find.text('1 run · 2 dribble · 3 shoot · 4 celebrate'), findsOneWidget);
      for (var i = 0; i < 60; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('KAZANDIN'), findsOneWidget);

      await sekme(t, 'KONSEPTLER');
      expect(find.text('TASLAK KAYIT'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });
}

class _Repo implements CharacterRepository {
  final Result<CharacterCardData> cevap;
  _Repo(this.cevap);
  @override
  Future<Result<CharacterCardData>> fetchCard(String slug) async => cevap;
}
