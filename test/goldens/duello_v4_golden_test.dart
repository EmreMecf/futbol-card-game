import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/auth/session_manager.dart';
import 'package:futbol_card/core/di/injection.dart';
import 'package:futbol_card/core/theme/app_theme.dart';
import 'package:futbol_card/features/match/presentation/view/match_view.dart';
import 'package:futbol_card/features/match/presentation/viewmodel/match_view_model.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'golden_araclari.dart';
import 'sahte_veri.dart';

/// 039 — eş zamanlı düello (kural sürümü 4): mevki seçimi, gizli seçim,
/// rakip bekleniyor. Eski sürüm maç ekranı `arena_golden_test.dart`'ta
/// değişmeden doğrulanıyor.
void main() {
  final atla = goldenSkipReason;
  late SessionManager oturum;
  late GoldenArenaV4Repo depo;

  setUpAll(() async {
    dotenv.loadFromString(envString: 'ENABLE_LOGGING=false');
    if (atla == null) await loadGoldenFonts();
  });

  Future<void> ac(WidgetTester t, GoldenArenaV4Repo r, Size boyut) async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    oturum = await goldenSession();
    depo = r;
    getIt.registerFactoryParam<MatchViewModel, String, void>(
      (id, _) => MatchViewModel(depo, GoldenSocket(), oturum, matchId: id),
    );
    t.view.physicalSize = boyut;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ChangeNotifierProvider<SessionManager>.value(
      value: oturum,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const RepaintBoundary(key: Key('ekran'), child: MatchView(matchId: 'm')),
      ),
    ));
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> esle(WidgetTester t, String ad) =>
      expectLater(find.byKey(const Key('ekran')), matchesGoldenFile('ekranlar/$ad.png'));

  for (final boyut in [const Size(390, 844), const Size(320, 568), const Size(1366, 768)]) {
    testWidgets('39 mevki seçimi ${sizeName(boyut)}', (t) async {
      await ac(t, GoldenArenaV4Repo(phase: 'position'), boyut);
      expect(t.takeException(), isNull, reason: 'taşma veya çizim hatası');
      expect(find.text('MEVKİ SEÇ'), findsOneWidget);
      expect(find.text('MEVKİYİ SEÇ!'), findsOneWidget);
      await esle(t, '39_v4_mevki_secimi_${sizeName(boyut)}');
      await t.pumpWidget(const SizedBox());
    }, skip: atla != null);
  }

  testWidgets('mevki dokununca sunucuya gider; kart eli gizli', (t) async {
    await ac(t, GoldenArenaV4Repo(phase: 'position'), const Size(390, 844));
    expect(find.text('ELİNDEKİ KARTLAR'), findsNothing, reason: 'mevki aşamasında el yerine mevki seçici');
    await t.tap(find.text('MID'));
    await t.pump(const Duration(milliseconds: 200));
    expect(depo.secilenMevkiler.map((p) => p.code), ['MID']);
    await t.pumpWidget(const SizedBox());
  }, skip: atla != null);

  testWidgets('39b rakip mevki seçiyor 390x844', (t) async {
    await ac(t, GoldenArenaV4Repo(phase: 'position', amILead: false), const Size(390, 844));
    expect(find.text('RAKİP MEVKİ SEÇİYOR'), findsWidgets);
    await t.tap(find.text('MID'));
    await t.pump(const Duration(milliseconds: 200));
    expect(depo.secilenMevkiler, isEmpty, reason: 'inisiyatif rakipte');
    await esle(t, '39b_v4_rakip_mevki_390x844');
    await t.pumpWidget(const SizedBox());
  }, skip: atla != null);

  testWidgets('40 gizli seçim: duvar 2 enerji 390x844', (t) async {
    await ac(t, GoldenArenaV4Repo(phase: 'pick', amILead: false), const Size(390, 844));
    expect(find.text('KARTINI SEÇ!'), findsOneWidget);
    expect(find.text('ELİNDEKİ KARTLAR'), findsOneWidget);
    expect(find.text('⚡ 2 enerji'), findsNWidgets(2), reason: 'kontra 2, duvar sürüm 4\'te 2');
    expect(t.takeException(), isNull);
    await esle(t, '40_v4_gizli_secim_390x844');
    await t.pumpWidget(const SizedBox());
  }, skip: atla != null);

  testWidgets('40b kart oynandı, rakip bekleniyor 390x844', (t) async {
    await ac(t, GoldenArenaV4Repo(phase: 'pick', iHavePlayed: true), const Size(390, 844));
    expect(find.text('RAKİP SEÇİYOR...'), findsOneWidget);
    expect(find.textContaining('Kartını oynadın'), findsOneWidget);
    await esle(t, '40b_v4_rakip_bekleniyor_390x844');
    await t.pumpWidget(const SizedBox());
  }, skip: atla != null);
}
