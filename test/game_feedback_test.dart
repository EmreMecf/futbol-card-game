import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/di/injection.dart';
import 'package:futbol_card/core/feedback/game_feedback.dart';
import 'package:futbol_card/features/settings/presentation/viewmodel/settings_view_model.dart';
import 'package:futbol_card/shared/widgets/premium_card/premium_card.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ayarların GERÇEKTEN uygulandığını doğrular.
///
/// REGRESYON: Ayarlar ekranındaki "Titreşim", "Kart animasyonları" ve
/// "Süre uyarısı" anahtarları kaydediliyor ama hiçbir yerde
/// okunmuyordu. Oyuncu titreşimi kapatıyor, telefon titremeye devam
/// ediyordu.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Telefona giden titreşim komutlarını yakalar.
  ///
  /// HapticFeedback, Flutter'dan işletim sistemine `SystemChannels.platform`
  /// üzerinden "HapticFeedback.vibrate" mesajı gönderir. Bu kanalı
  /// dinleyerek telefona gerçekten komut gidip gitmediğini görebiliyoruz.
  late List<String> titresimler;

  setUp(() async {
    titresimler = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (cagri) async {
      if (cagri.method == 'HapticFeedback.vibrate') {
        titresimler.add(cagri.arguments as String);
      }
      return null;
    });

    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    await getIt.reset();
  });

  Future<SettingsViewModel> ayarlariKur(Map<String, Object> kayitli) async {
    SharedPreferences.setMockInitialValues(kayitli);
    final vm = SettingsViewModel();
    await vm.load();
    getIt.registerSingleton<SettingsViewModel>(vm);
    return vm;
  }

  group('Titreşim', () {
    test('açıkken telefona komut GİDER', () async {
      await ayarlariKur({});

      await GameFeedback.haptic(HapticStrength.heavy);

      expect(titresimler, ['HapticFeedbackType.heavyImpact']);
    });

    test('KAPALIYKEN telefona hiçbir komut gitmez', () async {
      await ayarlariKur({'ayar_titresim': false});

      await GameFeedback.haptic(HapticStrength.heavy);
      await GameFeedback.haptic(HapticStrength.light);
      await GameFeedback.haptic(HapticStrength.selection);

      expect(titresimler, isEmpty);
    });

    test('ayar oyun sırasında değişince hemen uygulanır', () async {
      final vm = await ayarlariKur({});

      await GameFeedback.haptic(HapticStrength.light);
      await vm.setVibration(false);
      await GameFeedback.haptic(HapticStrength.light);

      expect(titresimler, hasLength(1));
    });

    test('none hiç titreşim vermez', () async {
      await ayarlariKur({});
      await GameFeedback.haptic(HapticStrength.none);
      expect(titresimler, isEmpty);
    });

    test('her kademe farklı komut gönderir', () async {
      await ayarlariKur({});

      for (final s in [
        HapticStrength.selection,
        HapticStrength.light,
        HapticStrength.medium,
        HapticStrength.heavy,
      ]) {
        await GameFeedback.haptic(s);
      }

      expect(titresimler.toSet(), hasLength(4));
    });

    test('ayar kaydı yoksa (widget testi) varsayılan açık', () async {
      // getIt boş: GameFeedback çökmemeli, varsayılanla çalışmalı
      expect(GameFeedback.vibrationEnabled, isTrue);
      expect(GameFeedback.cardAnimationsEnabled, isTrue);
      expect(GameFeedback.turnWarningEnabled, isTrue);
    });
  });

  group('Diğer ayarlar okunuyor', () {
    test('süre uyarısı ve kart animasyonları ayardan gelir', () async {
      await ayarlariKur({
        'ayar_sure_uyarisi': false,
        'ayar_kart_animasyonlari': false,
      });

      expect(GameFeedback.turnWarningEnabled, isFalse);
      expect(GameFeedback.cardAnimationsEnabled, isFalse);
    });

    testWidgets('kart animasyonları kapalıyken kart EĞİLMEZ ama dokunma çalışır',
        (tester) async {
      await ayarlariKur({'ayar_kart_animasyonlari': false});
      var dokunuldu = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PremiumPlayerCard(
                fullName: 'Statik Kart',
                position: CardPosition.forward,
                tier: CardTier.legend,
                power: 95,
                width: 200,
                interactive: true,
                onTap: () => dokunuldu = true,
              ),
            ),
          ),
        ),
      );
      // Legend kartta dönen çerçeve var; animasyon kapalıysa
      // pumpAndSettle sonsuza beklemeden bitebilmeli.
      await tester.pumpAndSettle();

      expect(find.byType(CardTilt), findsNothing,
          reason: 'Animasyon kapalıyken 3B eğilme katmanı kurulmamalı');

      await tester.tap(find.byType(PremiumPlayerCard));
      expect(dokunuldu, isTrue, reason: 'Dokunma yine de çalışmalı');
    });
  });
}
