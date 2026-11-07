import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/auth/session_manager.dart';
import 'package:futbol_card/core/di/injection.dart';
import 'package:futbol_card/core/theme/app_theme.dart';
import 'package:futbol_card/features/collection/presentation/view/collection_view.dart';
import 'package:futbol_card/features/collection/presentation/viewmodel/collection_view_model.dart';
import 'package:futbol_card/features/collection/presentation/widgets/card_detail_sheet.dart';
import 'package:futbol_card/features/deck/presentation/view/deck_view.dart';
import 'package:futbol_card/features/deck/presentation/viewmodel/deck_view_model.dart';
import 'package:futbol_card/features/home/presentation/view/home_view.dart';
import 'package:futbol_card/features/home/presentation/viewmodel/home_view_model.dart';
import 'package:futbol_card/features/deck/presentation/widgets/formation_pitch.dart';
import 'package:futbol_card/shared/widgets/ref_card/ref_player_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'golden_araclari.dart';
import 'sahte_veri.dart';

/// REFERANS SADAKAT GOLDEN TESTLERİ — FAZ 1-3 (ana sayfa, kart, koleksiyon)
///
/// Her ekran kullanıcının istediği 6 boyutta çizilir; taşma (overflow)
/// olursa test KALIR. Görüntüler test/goldens/ekranlar/ altında; referans
/// görüntüleri design-reference/ekranlar/ altında
/// (tool/tasarim/referans_cek.py ile üretilir).
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
    getIt
      ..registerFactory<HomeViewModel>(
          () => HomeViewModel(GoldenLeaderboardRepo(), GoldenMatchRepo(), GoldenDeckRepo()))
      ..registerFactory<CollectionViewModel>(() => CollectionViewModel(GoldenCollectionRepo()))
      ..registerFactory<DeckViewModel>(() => DeckViewModel(GoldenDeckRepo()));
    oturum = await goldenSession();
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
    // Veri yüklensin, sayfa giriş hareketi (280 ms) bitsin
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> esle(WidgetTester t, String ad) => expectLater(
        find.byKey(const Key('ekran')),
        matchesGoldenFile('ekranlar/$ad.png'),
      );

  for (final boyut in kGoldenSizes) {
    testWidgets('ana sayfa ${sizeName(boyut)}', (t) async {
      await ac(t, const HomeView(), boyut);
      expect(t.takeException(), isNull, reason: 'taşma veya çizim hatası');
      await esle(t, '01_ana_sayfa_${sizeName(boyut)}');
    }, skip: atla != null);

    testWidgets('kadro ${sizeName(boyut)}', (t) async {
      await ac(t, const DeckView(), boyut);
      expect(t.takeException(), isNull, reason: 'taşma veya çizim hatası');
      // Bütün oyuncu kutuları sahanın İÇİNDE (kullanıcının bildirdiği
      // "sahadan taşan kartlar" hatası)
      final saha = t.getRect(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is RefFieldPainter));
      for (final e in find.byType(SquadSlotTile).evaluate()) {
        final r = t.getRect(find.byWidget(e.widget));
        expect(saha.inflate(8).contains(r.topLeft) && saha.inflate(8).contains(r.bottomRight), isTrue,
            reason: 'kutu sahadan taşıyor: $r / $saha');
      }
      expect(find.byType(SquadSlotTile), findsNWidgets(11));
      await esle(t, '04_kadro_${sizeName(boyut)}');
    }, skip: atla != null);

    testWidgets('koleksiyon ${sizeName(boyut)}', (t) async {
      await ac(t, const CollectionView(), boyut);
      expect(t.takeException(), isNull, reason: 'taşma veya çizim hatası');
      await esle(t, '03_koleksiyon_${sizeName(boyut)}');
    }, skip: atla != null);
  }

  testWidgets('ana sayfa alt kısım 390x844', (t) async {
    await ac(t, const HomeView(), const Size(390, 844));
    await t.drag(find.byType(Scrollable).first, const Offset(0, -600));
    await t.pump(const Duration(milliseconds: 300));
    await esle(t, '01b_ana_sayfa_alt_390x844');
  }, skip: atla != null);

  testWidgets('kadro alt kısım 390x844', (t) async {
    await ac(t, const DeckView(), const Size(390, 844));
    await t.drag(find.byType(Scrollable).first, const Offset(0, -700));
    await t.pump(const Duration(milliseconds: 300));
    await esle(t, '04b_kadro_alt_390x844');
  }, skip: atla != null);

  for (final boyut in [const Size(390, 844), const Size(320, 568)]) {
    testWidgets('kadro kart seçimi ${sizeName(boyut)}', (t) async {
      await ac(t, const DeckView(), boyut);
      // Kaleci yuvasına dokun → o mevkiye uygun kartlar
      await t.tap(find.byType(SquadSlotTile).last);
      for (var i = 0; i < 8; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('KALECİ SEÇ'), findsOneWidget);
      expect(t.takeException(), isNull, reason: 'seçim penceresi taşmamalı');
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('ekranlar/04c_kadro_kart_secimi_${sizeName(boyut)}.png'));
    }, skip: atla != null);
  }

  testWidgets('koleksiyon alt kısım 390x844', (t) async {
    await ac(t, const CollectionView(), const Size(390, 844));
    await t.drag(find.byType(Scrollable).first, const Offset(0, -700));
    await t.pump(const Duration(milliseconds: 300));
    await esle(t, '03b_koleksiyon_alt_390x844');
  }, skip: atla != null);

  testWidgets('koleksiyon Efsane filtresi 390x844', (t) async {
    await ac(t, const CollectionView(), const Size(390, 844));
    await t.tap(find.text('Efsane'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byType(RefPlayerCard), findsNWidgets(2));
    await esle(t, '03d_koleksiyon_filtre_390x844');
  }, skip: atla != null);

  for (final boyut in [const Size(390, 844), const Size(320, 568)]) {
    testWidgets('kart detayı ${sizeName(boyut)}', (t) async {
      await ac(t, const CollectionView(), boyut);
      await t.ensureVisible(find.byType(RefPlayerCard).at(2));
      await t.pump(const Duration(milliseconds: 100));
      await t.tap(find.byType(RefPlayerCard).at(2));
      for (var i = 0; i < 10; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(CardDetailSheet), findsOneWidget);
      expect(t.takeException(), isNull, reason: 'detay penceresi taşmamalı');
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('ekranlar/03c_kart_detay_${sizeName(boyut)}.png'));
    }, skip: atla != null);
  }
}
