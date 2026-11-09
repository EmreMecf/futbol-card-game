import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/auth/session_manager.dart';
import 'package:futbol_card/core/di/injection.dart';
import 'package:futbol_card/core/theme/app_theme.dart';
import 'package:futbol_card/features/store/presentation/view/store_view.dart';
import 'package:futbol_card/features/store/presentation/viewmodel/store_view_model.dart';
import 'package:futbol_card/features/store/presentation/widgets/pack_reveal_view.dart';
import 'package:futbol_card/features/store/presentation/widgets/pack_seal_scene.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'golden_araclari.dart';
import 'sahte_veri.dart';

/// FAZ 6 — mağaza ve paket açılışı: 6 boyutta golden + taşma denetimi.
void main() {
  final atla = goldenSkipReason;
  late SessionManager oturum;

  setUpAll(() async {
    dotenv.loadFromString(envString: 'ENABLE_LOGGING=false');
    if (atla == null) await loadGoldenFonts();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    oturum = await goldenSession();
    getIt.registerFactory<StoreViewModel>(() => StoreViewModel(GoldenStoreRepo(), oturum));
  });

  Future<void> ac(WidgetTester t, Widget ekran, Size boyut) async {
    t.view.physicalSize = boyut;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ChangeNotifierProvider<SessionManager>.value(
      value: oturum,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: RepaintBoundary(key: const Key('ekran'), child: ekran),
      ),
    ));
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> esle(WidgetTester t, String ad) =>
      expectLater(find.byKey(const Key('ekran')), matchesGoldenFile('ekranlar/$ad.png'));

  // Eski taşma 1366 ve 1440 genişlikte görülüyordu (60-85 px)
  for (final boyut in [...kGoldenSizes, const Size(1440, 900)]) {
    testWidgets('mağaza ${sizeName(boyut)} taşmaz', (t) async {
      await ac(t, const StoreView(), boyut);
      expect(t.takeException(), isNull, reason: 'BOTTOM OVERFLOWED olmamalı');
      expect(find.text('MAĞAZA'), findsOneWidget);
      if (kGoldenSizes.contains(boyut)) await esle(t, '05_magaza_${sizeName(boyut)}');
    }, skip: atla != null);
  }

  testWidgets('mağaza: karoya dokunmak paketi seçer, satın almaz', (t) async {
    await ac(t, const StoreView(), const Size(390, 844));
    // Öne çıkan: Efsane ihtimali en yüksek satılık paket (Premium)
    expect(find.text('PREMİUM PAKET'), findsWidgets);
    // 2.450 altın Premium'a (2.500) yetmez: CTA pasif ve sebebini söyler
    expect(find.text('YETERSİZ ALTIN'), findsOneWidget);
    await t.tap(find.text('STANDART PAKET'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('500 · PAKET AL'), findsOneWidget);
    expect(find.text('SEÇİLİ PAKET'), findsOneWidget);
    expect(find.byType(PackRevealView), findsNothing, reason: 'dokunuş satın alma DEĞİL');
    await t.drag(find.byType(Scrollable).first, const Offset(0, -760));
    await t.pump(const Duration(milliseconds: 300));
    await esle(t, '05b_magaza_alt_390x844');
  }, skip: atla != null);

  testWidgets('mağaza: yetersiz altında CTA pasif', (t) async {
    await oturum.updateUser(kGoldenUser.copyWith(coins: 100));
    await ac(t, const StoreView(), const Size(390, 844));
    expect(find.text('YETERSİZ ALTIN'), findsOneWidget);
    expect(t.takeException(), isNull);
  }, skip: atla != null);

  for (final boyut in [const Size(390, 844), const Size(320, 568)]) {
    testWidgets('paket açılışı adım adım ${sizeName(boyut)}', (t) async {
      await ac(t, PackRevealView(result: kGoldenOpening, onClose: () {}, packTier: CardTier.gold), boyut);
      expect(find.byType(PackSealScene), findsOneWidget);
      await esle(t, '05c_paket_muhur_${sizeName(boyut)}');
      await t.tap(find.byType(PackSealScene));
      await t.pump();
      await t.pump(PackSealScene.openDuration);
      for (var i = 0; i < 12; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('YENİ KART KEŞFEDİLDİ'), findsOneWidget);
      expect(t.takeException(), isNull, reason: 'kart penceresi taşmamalı');
      await esle(t, '05c_paket_acma_${sizeName(boyut)}');
      await t.ensureVisible(find.text('Hepsini göster'));
      await t.pump(const Duration(milliseconds: 100));
      await t.tap(find.text('Hepsini göster'));
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(PackSummaryView), findsOneWidget);
      expect(t.takeException(), isNull, reason: 'özet taşmamalı');
      await esle(t, '05d_paket_ozet_${sizeName(boyut)}');
    }, skip: atla != null);
  }
}
