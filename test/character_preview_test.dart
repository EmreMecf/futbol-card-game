import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/di/injection.dart';
import 'package:futbol_card/core/error/app_exception.dart';
import 'package:futbol_card/core/theme/app_theme.dart';
import 'package:futbol_card/core/utils/result.dart';
import 'package:futbol_card/features/characters/data/character_repository.dart';
import 'package:futbol_card/features/characters/presentation/character_preview_view.dart';
import 'package:futbol_card/features/characters/presentation/character_preview_view_model.dart';
import 'package:futbol_card/shared/widgets/avatar2d/avatar_painter.dart';
import 'package:futbol_card/shared/widgets/premium_card/premium_card.dart';
import 'package:shared_models/shared_models.dart';

/// Sunucunun `GET /api/characters/kaelen-brisvoy` cevabıyla aynı yapı
/// (027 get_character_card; değerler 026 örnek forvetinden).
Map<String, dynamic> sunucuCevabi() => {
      'character': {
        'id': '6b1f2c4e-0a3d-4f5e-9c7b-1d2e3f4a5b6c',
        'slug': 'kaelen-brisvoy',
        'catalog_version': 'v2-ozgun',
        'given_name': 'Kaelen',
        'family_name': 'Brisvoy',
        'display_name': 'Kaelen Brisvoy',
        'region_code': 'SLV',
        'club_code': 'LRF',
        'primary_position': 'FWD',
        'secondary_position': 'MID',
        'playstyle': 'hizli_kanat',
        'personality': ['sabırsız', 'cesur', 'şakacı', 'takım ruhlu'],
        'bio_short': 'Liman mahallesinde rüzgâra karşı koşarak büyüyen kanat.',
        'bio_long': 'Selvarra Kıyıları\'nın liman kasabasında büyüdü.',
        'appearance': {
          'skin_tone': 'açık buğday',
          'hair': 'bakır',
          'face': 'çilli',
          'build': 'ince',
          'accessory': 'turkuaz bileklik',
          'shirt_number': 17,
        },
        'visual_prompt': 'Original stylized 3D footballer',
        'animation_profile': 'gosterisci',
        'status': 'draft',
        'created_by': 'ai_assisted',
        'generator': 'claude-code-oturumu',
        'generator_model': 'claude-opus-5-5',
      },
      'proposal': {
        'character_id': '6b1f2c4e-0a3d-4f5e-9c7b-1d2e3f4a5b6c',
        'tier': 'gold',
        'power': 83,
        'attributes': {
          'shooting': 86, 'pace': 95, 'physical': 75,
          'defending': 56, 'dribbling': 89, 'acceleration': 89,
        },
        'slot': 'gold-FWD-1',
        'balance_engine_version': 'balance-v1',
      },
      'presentation': {
        'character_id': '6b1f2c4e-0a3d-4f5e-9c7b-1d2e3f4a5b6c',
        'mode': '2.5d',
        'portrait_uri': null,
        'model_uri': null,
        'rig_uri': null,
        'sprite_uri': null,
        'approved_clips': <String>[],
        'missing_clips': ['celebrate', 'dribble', 'idle', 'lose', 'run', 'shoot', 'tackle', 'walk', 'win'],
        'missing_assets': ['portrait', 'model_glb', 'rig'],
      },
      'club_name': 'Liman Rüzgârı FK',
      'region_name': 'Selvarra Kıyıları',
    };

class _Repo implements CharacterRepository {
  final Result<CharacterCardData> cevap;
  _Repo(this.cevap);
  @override
  Future<Result<CharacterCardData>> fetchCard(String slug) async => cevap;
}

void main() {
  setUpAll(() => dotenv.loadFromString(envString: 'ENABLE_LOGGING=false'));

  Future<void> ac(WidgetTester t, CharacterRepository repo) async {
    await getIt.reset();
    getIt.registerFactory<CharacterPreviewViewModel>(() => CharacterPreviewViewModel(repo));
    t.view.physicalSize = const Size(390, 1800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(theme: AppTheme.dark, home: const CharacterPreviewView()));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
  }

  test('sunucu cevabı modellere birebir oturuyor', () {
    final d = CharacterCardData.fromJson(sunucuCevabi());
    expect(d.character.displayName, 'Kaelen Brisvoy');
    expect(d.proposal!.power, 83);
    expect(d.presentation.mode, PresentationMode.fallback25d);
  });

  testWidgets('önizleme: kart, PORTRE YOK, eksikler ve 2.5B yedek açıkça görünür', (t) async {
    await ac(t, _Repo(Success(CharacterCardData.fromJson(sunucuCevabi()))));

    expect(t.takeException(), isNull);
    expect(find.text('PROTOTİP'), findsOneWidget);
    // Ana kart + 5 seviye çerçevesi (+ çatışma sahnesinin kendi kartları)
    expect(find.byType(PremiumPlayerCard), findsAtLeastNWidgets(1 + CardTier.values.length));
    // Yeni kart sistemi: portre dosyası yoksa karakterin kendi 2D yüzü
    // çizilir (siluet + "PORTRE YOK" yerine). Eksik varlıklar aşağıdaki
    // listede yine açıkça "YOK" yazar.
    expect(find.text('PORTRE YOK'), findsNothing);
    expect(find.byType(AvatarPortrait), findsWidgets);
    // (Oyun tarzı rozeti eski kartın parçasıydı; referans kartta yok)
    expect(find.textContaining('Kullanılan katman: 2.5B yedek'), findsOneWidget);
    expect(find.textContaining('Onaylı 3B varlık eksik'), findsOneWidget);
    expect(find.textContaining('Eksik animasyon klipleri (9)'), findsOneWidget);
    expect(find.textContaining('1 run · 2 dribble · 3 shoot · 4 celebrate'), findsOneWidget);
    // Varlık satırlarında "YOK" (hiçbiri onaylı değil)
    expect(find.text('YOK'), findsNWidgets(4));
    await t.pump(const Duration(seconds: 4));
  });

  testWidgets('sunucu hatası açık mesajla gösterilir', (t) async {
    await ac(t, _Repo(const Failure(AppException(message: 'Karakter bulunamadi.'))));
    expect(find.text('Karakter alınamadı'), findsOneWidget);
    expect(find.text('Karakter bulunamadi.'), findsOneWidget);
  });

  testWidgets('fromCharacter: kimlik karakterden, güç Denge Motoru önerisinden', (t) async {
    final d = CharacterCardData.fromJson(sunucuCevabi());
    await t.pumpWidget(MaterialApp(
      home: Center(
        child: PremiumPlayerCard.fromCharacter(d.character, d.proposal!,
            clubName: 'Liman Rüzgârı FK', width: 240, interactive: false),
      ),
    ));
    expect(find.text('83'), findsOneWidget);
    expect(find.text('Kaelen Brisvoy'), findsOneWidget);
    expect(find.text('FWD'), findsOneWidget);
    expect(find.byType(AvatarPortrait), findsWidgets);
  });

  testWidgets('eski kartlar etkilenmedi: rozet ve PORTRE YOK çıkmaz', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Center(
        child: PremiumPlayerCard(
          fullName: 'Eski Kart', position: CardPosition.defender,
          tier: CardTier.silver, power: 70, width: 200, interactive: false),
      ),
    ));
    expect(find.text('PORTRE YOK'), findsNothing);
    expect(find.text('Hızlı Kanat'), findsNothing);
  });
}
