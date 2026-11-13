import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/auth/session_manager.dart';
import 'package:futbol_card/core/di/injection.dart';
import 'package:futbol_card/core/theme/app_theme.dart';
import 'package:futbol_card/features/chests/domain/chest_repository.dart';
import 'package:futbol_card/features/chests/presentation/view/chests_view.dart';
import 'package:futbol_card/features/chests/presentation/viewmodel/chests_view_model.dart';
import 'package:futbol_card/features/items/domain/items_repository.dart';
import 'package:futbol_card/features/items/presentation/view/inventory_view.dart';
import 'package:futbol_card/features/items/presentation/viewmodel/items_view_model.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'golden_araclari.dart';
import 'sahte_item.dart';
import 'sahte_veri.dart';

/// EKONOMİ V2 FAZ 3 — envanter ekranı (6 boyut) ve sandık ekranında
/// anahtar / hızlandırıcı seçenekleri.
void main() {
  final atla = goldenSkipReason;
  late SessionManager oturum;
  late GoldenItemsRepo itemler;

  setUpAll(() async {
    dotenv.loadFromString(envString: 'ENABLE_LOGGING=false');
    if (atla == null) await loadGoldenFonts();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    oturum = await goldenSession();
    itemler = GoldenItemsRepo();
    final sandik = GoldenChestRepo();
    getIt
      ..registerSingleton<ItemsRepository>(itemler)
      ..registerSingleton<ChestRepository>(sandik)
      ..registerFactory<ItemsViewModel>(() => ItemsViewModel(itemler))
      ..registerFactory<ChestsViewModel>(
          () => ChestsViewModel(sandik, session: oturum, items: itemler, clock: () => kGoldenServerTime));
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
        // Sınır Navigator'ı da kapsar: alttan açılan pencere görüntüye girsin
        builder: (context, cocuk) => RepaintBoundary(key: const Key('ekran'), child: cocuk),
        home: ekran,
      ),
    ));
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> esle(WidgetTester t, String ad) =>
      expectLater(find.byKey(const Key('ekran')), matchesGoldenFile('ekranlar/$ad.png'));

  for (final boyut in kGoldenSizes) {
    testWidgets('27_envanter ${sizeName(boyut)} taşmaz', (t) async {
      await ac(t, const InventoryView(), boyut);
      expect(t.takeException(), isNull, reason: 'taşma veya çizim hatası');
      await esle(t, '27_envanter_${sizeName(boyut)}');
      await t.pumpWidget(const SizedBox());
    }, skip: atla != null);
  }

  testWidgets('envanter: gruplar, adetler, giyili, enerji içeceği kullanılır', (t) async {
    await ac(t, const InventoryView(), const Size(390, 844));
    expect(find.text('TÜKETİLEBİLİR'), findsOneWidget);
    expect(find.text('×3'), findsOneWidget, reason: '3 anahtar');
    expect(find.text('Bugün 1/2 kullanıldı'), findsOneWidget);
    await t.tap(find.text('KULLAN'));
    await t.pump(const Duration(milliseconds: 200));
    expect(itemler.kullanilan, ['energy_drink']);
    expect(find.text('Sandık hakkın 8 oldu.'), findsOneWidget);
    await t.scrollUntilVisible(find.text('GİYİLİ'), 300);
    expect(find.text('GİYİLİ'), findsOneWidget, reason: 'forma giyili');
    expect(find.text('GİY'), findsOneWidget, reason: 'çerçeve giyilebilir');
    await t.pumpWidget(const SizedBox());
  }, skip: atla != null);

  testWidgets('28 sandık seçenekleri: anahtar ve hızlandırıcı 390x844', (t) async {
    await ac(t, const ChestsView(), const Size(390, 844));
    // Sayacı çalışan Gümüş sandık (1. yuva): hızlandır + anahtarla aç
    await t.tap(find.text('GÜMÜŞ'));
    // İlk kare animasyonu başlatır, ikincisi bitirir
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('ANAHTARLA AÇ (1 / 3 anahtar)'), findsOneWidget);
    expect(find.text('2 SAAT HIZLANDIR (1 adet)'), findsOneWidget);
    expect(find.textContaining('KİLİDİ AÇ'), findsNothing, reason: 'sayaç zaten çalışıyor');
    expect(t.takeException(), isNull);
    await esle(t, '28_sandik_secenekleri_390x844');
    await t.tap(find.text('ANAHTARLA AÇ (1 / 3 anahtar)'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(itemler.kullanilan, ['chest_key']);
    await t.pumpWidget(const SizedBox());
  }, skip: atla != null);
}
