import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/auth/session_manager.dart';
import 'package:futbol_card/core/di/injection.dart';
import 'package:futbol_card/core/theme/app_theme.dart';
import 'package:futbol_card/features/collection/presentation/widgets/card_detail_sheet.dart';
import 'package:futbol_card/features/progress/domain/progress_repository.dart';
import 'package:futbol_card/features/progress/presentation/view/progress_view.dart';
import 'package:futbol_card/features/progress/presentation/viewmodel/progress_view_model.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'golden_araclari.dart';
import 'sahte_veri.dart';

/// EKONOMİ V2 FAZ 2 — gelişim ekranı (6 boyut) ve kart detayında gelişim
/// paneli. K1: seviye dereceli gücü etkilemez (panel bunu yazar).
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
    final depo = GoldenProgressRepo();
    getIt
      ..registerSingleton<ProgressRepository>(depo)
      ..registerFactory<ProgressViewModel>(() => ProgressViewModel(depo, session: oturum));
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
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> esle(WidgetTester t, String ad) =>
      expectLater(find.byKey(const Key('ekran')), matchesGoldenFile('ekranlar/$ad.png'));

  for (final boyut in kGoldenSizes) {
    testWidgets('25_gelisim ${sizeName(boyut)} taşmaz', (t) async {
      await ac(t, const ProgressView(), boyut);
      expect(t.takeException(), isNull, reason: 'taşma veya çizim hatası');
      await esle(t, '25_gelisim_${sizeName(boyut)}');
      await t.pumpWidget(const SizedBox());
    }, skip: atla != null);
  }

  testWidgets('gelişim: hazır olanlar önce; doğru düğmeler', (t) async {
    await ac(t, const ProgressView(), const Size(390, 844));
    expect(find.text('SEVİYE ATLA'), findsOneWidget, reason: 'kopyayla hazır');
    expect(find.text('JOKERLE (1)'), findsOneWidget, reason: 'jokerle hazır');
    await t.tap(find.text('Atlayabilir (2)'));
    await t.pump(const Duration(milliseconds: 200));
    expect(find.text('Kuzey Yıldızı'), findsNothing, reason: 'filtre: atlayamayan gizli');
    await t.pumpWidget(const SizedBox());
  }, skip: atla != null);

  for (final boyut in [const Size(390, 844), const Size(320, 568)]) {
    testWidgets('26_kart_detay_gelisim ${sizeName(boyut)}', (t) async {
      final kart = kGoldenCards[7].copyWith(level: 1);
      await ac(t, Scaffold(body: CardDetailSheet(card: kart)), boyut);
      expect(t.takeException(), isNull);
      await t.scrollUntilVisible(find.text('GELİŞİM'), 300);
      await t.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('dereceli maçta kartın gücünü değiştirmez'), findsOneWidget, reason: 'K1 açıkça yazılır');
      expect(find.text('2 fazla kopya gelişime çevrilebilir'), findsOneWidget);
      await esle(t, '26_kart_detay_gelisim_${sizeName(boyut)}');
      await t.pumpWidget(const SizedBox());
    }, skip: atla != null);
  }
}
