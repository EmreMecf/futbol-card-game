import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/constants/app_colors.dart';
import 'package:futbol_card/core/di/injection.dart';
import 'package:futbol_card/core/theme/app_theme.dart';
import 'package:futbol_card/core/theme/app_tokens.dart';
import 'package:futbol_card/features/settings/presentation/view/design_system_view.dart';
import 'package:futbol_card/features/settings/presentation/viewmodel/settings_view_model.dart';
import 'package:futbol_card/shared/widgets/game/game_ui.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// FAZ 2 — Tasarım sistemi: palet, token ve oyun bileşenleri.
///
/// (Kırılma noktaları, tipografi ve maç bileşenlerinin testleri
/// `design_system_test.dart` içinde.)
///
/// İki tür test var:
///   1. OKUNABİLİRLİK: Renk çiftlerinin WCAG kontrast oranı kodda
///      hesaplanıyor. Biri paleti değiştirip yazıyı okunmaz yaparsa
///      (ör. yeşil butona beyaz yazı) test kırılır.
///   2. DAVRANIŞ: Butonlar, paneller, rozetler, çubuklar.
void main() {
  // ==================================================================
  // OKUNABİLİRLİK
  // ==================================================================
  /// WCAG 2.1 bağıl parlaklık
  double parlaklik(Color c) {
    double kanal(double v) =>
        v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * kanal(c.r) + 0.7152 * kanal(c.g) + 0.0722 * kanal(c.b);
  }

  double kontrast(Color a, Color b) {
    final la = parlaklik(a), lb = parlaklik(b);
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  group('Okunabilirlik (WCAG, normal metin >= 4.5)', () {
    final ciftler = <String, (Color, Color)>{
      'ana metin / zemin': (AppColors.textPrimary, AppColors.background),
      'ana metin / yüzey': (AppColors.textPrimary, AppColors.surface),
      'ikincil metin / yüzey': (AppColors.textSecondary, AppColors.surface),
      'yeşil buton yazısı': (AppColors.onPrimary, AppColors.primary),
      'altın CTA yazısı': (const Color(0xFF261705), AppColors.victoryGold),
      'ikincil buton yazısı': (const Color(0xFFD1FAE5), const Color(0xFF065F46)),
      'tehlike / yüzey': (AppColors.danger, AppColors.surface),
      'emerald / yüzey': (AppColors.emerald, AppColors.surface),
    };

    ciftler.forEach((ad, cift) {
      test(ad, () {
        expect(kontrast(cift.$1, cift.$2), greaterThanOrEqualTo(4.5),
            reason: '$ad okunamaz');
      });
    });

    test('REGRESYON: yeşil üstüne BEYAZ yazı okunmaz, kullanılmamalı', () {
      // Eski tema buydu. Bu test, onPrimary'nin neden beyaz olmadığını
      // belgeliyor.
      expect(kontrast(Colors.white, AppColors.primary), lessThan(3));
      expect(AppColors.onPrimary, isNot(Colors.white));
    });

    test('tema buton yazısı onPrimary kullanıyor', () {
      final tema = AppTheme.dark;
      final stil = tema.elevatedButtonTheme.style!;
      final yazi = stil.foregroundColor!.resolve({});
      expect(yazi, AppColors.onPrimary);
      expect(tema.colorScheme.onPrimary, AppColors.onPrimary);
    });
  });

  group('MD paleti birebir', () {
    test('dokuz ana renk MD bölüm 3 ile aynı', () {
      expect(AppColors.obsidian, const Color(0xFF0A0C10));
      expect(AppColors.deepNavy, const Color(0xFF111827));
      expect(AppColors.midnightBlue, const Color(0xFF0F172A));
      expect(AppColors.emerald, const Color(0xFF10B981));
      expect(AppColors.cyan, const Color(0xFF22D3EE));
      expect(AppColors.championGold, const Color(0xFFD4AF37));
      expect(AppColors.victoryGold, const Color(0xFFFBBF24));
      expect(AppColors.dangerRed, const Color(0xFFEF4444));
      expect(AppColors.epicPurple, const Color(0xFF8B5CF6));
    });

    test('animasyon süreleri MD bölüm 9 aralıklarında', () {
      bool arada(Duration d, int min, int max) =>
          d.inMilliseconds >= min && d.inMilliseconds <= max;

      expect(arada(AppDurations.button, 120, 200), isTrue);
      expect(arada(AppDurations.cardSelect, 200, 350), isTrue);
      expect(arada(AppDurations.cardPlay, 300, 500), isTrue);
      expect(arada(AppDurations.panel, 250, 400), isTrue);
      expect(arada(AppDurations.clash, 1500, 3000), isTrue);
      expect(arada(AppDurations.packOpen, 3000, 6000), isTrue);
    });
  });

  // ==================================================================
  // DAVRANIŞ
  // ==================================================================
  Widget sarmala(Widget c) => MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Center(
            child: Padding(padding: const EdgeInsets.all(16), child: c),
          ),
        ),
      );

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
    await getIt.reset();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    await getIt.reset();
  });

  group('GameButton', () {
    testWidgets('dokununca çalışır ve hafif titreşim verir', (tester) async {
      var sayac = 0;
      await tester.pumpWidget(
        sarmala(GameButton(label: 'Maça başla', onPressed: () => sayac++)),
      );

      await tester.tap(find.byType(GameButton));
      await tester.pumpAndSettle();

      expect(sayac, 1);
      expect(titresimler, ['HapticFeedbackType.selectionClick']);
      expect(find.text('MAÇA BAŞLA'), findsOneWidget,
          reason: 'Etiket büyük harfe çevrilmeli (Türkçe İ dahil)');
    });

    testWidgets('pasifken dokunma işe yaramaz, titreşim yok', (tester) async {
      await tester.pumpWidget(
        sarmala(const GameButton(
          label: 'Paket al',
          onPressed: null,
          disabledReason: 'Yeterli coin yok',
        )),
      );

      await tester.tap(find.byType(GameButton), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(titresimler, isEmpty);
      expect(find.byType(Tooltip), findsOneWidget,
          reason: 'Neden pasif olduğu açıklanmalı');
    });

    testWidgets('yüklenirken kilitli ve gösterge var', (tester) async {
      var sayac = 0;
      await tester.pumpWidget(
        sarmala(GameButton(
          label: 'Kaydet',
          isLoading: true,
          onPressed: () => sayac++,
        )),
      );

      await tester.tap(find.byType(GameButton), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));

      expect(sayac, 0, reason: 'Çift gönderimi engellemeli');
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('KAYDET'), findsNothing);
    });

    testWidgets('basılıyken yüzey aşağı kayar (3B basma)', (tester) async {
      await tester.pumpWidget(
        sarmala(GameButton(label: 'Bas', onPressed: () {})),
      );

      double yuzeyTepe() =>
          tester.widget<AnimatedPositioned>(find.byType(AnimatedPositioned)).top!;

      expect(yuzeyTepe(), 0);

      final parmak =
          await tester.startGesture(tester.getCenter(find.byType(GameButton)));
      await tester.pump();
      expect(yuzeyTepe(), greaterThan(0), reason: 'Basınca çökmeli');

      await parmak.up();
      await tester.pumpAndSettle();
      expect(yuzeyTepe(), 0, reason: 'Bırakınca geri kalkmalı');
    });

    testWidgets('her tür en az 48 piksel (parmak hedefi)', (tester) async {
      for (final b in [
        GameButton(label: 'a', onPressed: () {}),
        GameButton.secondary(label: 'b', onPressed: () {}),
        GameButton.neutral(label: 'c', onPressed: () {}),
      ]) {
        await tester.pumpWidget(sarmala(b));
        expect(
          tester.getSize(find.byType(GameButton)).height,
          greaterThanOrEqualTo(AppSpacing.minTouchTarget),
        );
      }
    });

    testWidgets('ekran okuyucu "buton" olarak tanır', (tester) async {
      final semantik = tester.ensureSemantics();
      await tester.pumpWidget(
        sarmala(GameButton(label: 'Maça başla', onPressed: () {})),
      );

      expect(
        tester.getSemantics(find.byType(GameButton)),
        matchesSemantics(
          label: 'Maça başla',
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
        ),
      );
      semantik.dispose();
    });

    testWidgets('uzun etiket taşmaz', (tester) async {
      await tester.pumpWidget(
        sarmala(SizedBox(
          width: 160,
          child: GameButton(
            label: 'Çok uzun bir buton etiketi örneği burada',
            icon: Icons.bolt,
            onPressed: () {},
          ),
        )),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('GlassPanel', () {
    testWidgets('varsayılan: blur YOK (performans)', (tester) async {
      await tester.pumpWidget(sarmala(const GlassPanel(child: Text('x'))));
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('blur istenirse BackdropFilter kurulur', (tester) async {
      await tester.pumpWidget(
        sarmala(const GlassPanel(blur: true, child: Text('x'))),
      );
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('animasyonlar kapalıysa blur da kapanır', (tester) async {
      SharedPreferences.setMockInitialValues({'ayar_kart_animasyonlari': false});
      final ayar = SettingsViewModel();
      await ayar.load();
      getIt.registerSingleton<SettingsViewModel>(ayar);

      await tester.pumpWidget(
        sarmala(const GlassPanel(blur: true, child: Text('x'))),
      );
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('dokunulabilir panel çalışır', (tester) async {
      var dokunuldu = false;
      await tester.pumpWidget(
        sarmala(GlassPanel(
          onTap: () => dokunuldu = true,
          child: const Text('panel'),
        )),
      );
      await tester.tap(find.text('panel'));
      expect(dokunuldu, isTrue);
    });
  });

  group('TierBadge', () {
    test('ekranda Türkçe karakterli adlar', () {
      expect(CardTier.silver.displayName, 'Gümüş');
      expect(CardTier.gold.displayName, 'Altın');
      // Oyun genelindeki adlarla tutarlı (walkout "LEGEND" yazar)
      expect(CardTier.legend.displayName, 'Legend');
    });

    testWidgets('Legend rozeti yıldızlı (simge, karakter değil)', (tester) async {
      await tester.pumpWidget(sarmala(const TierBadge(CardTier.legend)));
      expect(find.text('LEGEND'), findsOneWidget);
      // REGRESYON: "✦" karakteri Barlow Condensed'de yok, kutu çiziliyordu
      expect(find.textContaining('✦'), findsNothing);
      expect(find.byIcon(Icons.auto_awesome), findsNWidgets(2));
    });

    testWidgets('kısa içerikli cam panel yine TAM genişlik', (tester) async {
      // REGRESYON: Stack varsayılan (loose) kısıtla panel yazı kadar
      // daralıyordu.
      await tester.pumpWidget(sarmala(const SizedBox(
        width: 300,
        child: GlassPanel(child: Text('kısa')),
      )));
      expect(tester.getSize(find.byType(GlassPanel)).width, 300);
    });

    testWidgets('her seviye hatasız çizilir', (tester) async {
      for (final t in CardTier.values) {
        await tester.pumpWidget(sarmala(TierBadge(t, compact: true)));
        expect(tester.takeException(), isNull, reason: t.code);
      }
    });
  });

  group('GameProgressBar', () {
    double doluluk(WidgetTester tester) => tester
        .widget<FractionallySizedBox>(find.byType(FractionallySizedBox))
        .widthFactor!;

    testWidgets('değere AKARAK dolar', (tester) async {
      await tester.pumpWidget(sarmala(const GameProgressBar(value: 0.2)));
      await tester.pumpAndSettle();
      expect(doluluk(tester), closeTo(0.2, 0.001));

      await tester.pumpWidget(sarmala(const GameProgressBar(value: 0.8)));
      await tester.pump(const Duration(milliseconds: 150));
      final ara = doluluk(tester);
      expect(ara, greaterThan(0.2));
      expect(ara, lessThan(0.8), reason: 'Zıplamamalı, akmalı');

      await tester.pumpAndSettle();
      expect(doluluk(tester), closeTo(0.8, 0.001));
    });

    testWidgets('sınır dışı değerler kırpılır, NaN çökertmez', (tester) async {
      for (final v in [1.7, -0.4, double.nan]) {
        await tester.pumpWidget(sarmala(GameProgressBar(value: v)));
        await tester.pumpAndSettle();
        final d = doluluk(tester);
        expect(d, inInclusiveRange(0, 1), reason: '$v');
      }
    });
  });

  group('Tasarım sistemi vitrini', () {
    testWidgets('telefon boyutunda taşmadan çizilir', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.dark, home: const DesignSystemView()),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('MAÇA BAŞLA'), findsWidgets);

      // Sonuna kadar kaydır: alt bölümler de taşmamalı
      await tester.drag(find.byType(ListView), const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
