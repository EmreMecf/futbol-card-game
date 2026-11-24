import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/auth/session_manager.dart';
import 'package:futbol_card/core/di/injection.dart';
import 'package:futbol_card/core/network/websocket_service.dart';
import 'package:futbol_card/core/theme/app_theme.dart';
import 'package:futbol_card/core/utils/result.dart';
import 'package:futbol_card/features/match/domain/repositories/match_repository.dart';
import 'package:futbol_card/features/match/presentation/viewmodel/match_view_model.dart';
import 'package:futbol_card/features/matchmaking/presentation/viewmodel/matchmaking_view_model.dart';
import 'package:futbol_card/ui_v21/screens/arena/v21_arena_screen.dart';
import 'package:futbol_card/ui_v21/screens/arena/v21_matchmaking_screen.dart';
import 'package:futbol_card/ui_v21/ui_v21.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../goldens/sahte_veri.dart';
import 'v21_compare.dart';
import 'v21_test_support.dart';

/// FAZ 8 — Maça Hazırlan, rakip arama (hf3–hf6) ve canlı arena (hf7–hf11).
/// Gerçek MatchmakingViewModel / MatchViewModel + sahte depolar.

/// Kart ve taktiği TEK istekte gönderildi mi? Her playCard çağrısı kaydedilir.
class _PlayRepo extends GoldenArenaRepo {
  final plays = <(String?, MatchTactic)>[];
  @override
  Future<Result<PlayCardResult>> playCard({
    required String matchId,
    String? userCardId,
    MatchTactic tactic = MatchTactic.none,
  }) async {
    plays.add((userCardId, tactic));
    return const Success(PlayCardResult());
  }
}

/// Uses the same server match model as ranked games but in no-reward friend mode.
class _FriendlyRepo extends GoldenArenaRepo {
  @override
  Future<Result<MatchState>> fetchState(String m) async {
    final base = (await super.fetchState(m)).dataOrNull!;
    return Success(base.copyWith(mode: 'friendly'));
  }
}

class _V4Repo extends GoldenArenaV4Repo {
  _V4Repo({required super.phase, super.amILead, super.iHavePlayed});
}

class _QueueRepo extends GoldenMatchmakingRepo {
  final bool valid;
  int finds = 0;
  int cancels = 0;
  _QueueRepo({this.valid = true});

  @override
  Future<Result<DeckValidation>> validateDeck(String deckId) async => Success(
    valid ? const DeckValidation(isValid: true) : const DeckValidation(isValid: false, message: 'Kadroda 10 kart var'),
  );

  @override
  Future<Result<MatchFindResult>> findMatch({required String deckId, List<String>? protectedCardIds}) async {
    finds++;
    return const Success(MatchFindResult(status: MatchmakingStatus.queued));
  }

  @override
  Future<Result<MatchFindResult>> cancelMatchmaking() async {
    cancels++;
    return const Success(MatchFindResult(status: MatchmakingStatus.queued));
  }
}

class _OfflineSocket extends GoldenSocket {
  @override
  bool get isConnected => false;
}

void main() {
  final skipGolden = v21GoldenSkipReason;
  late SessionManager session;
  late MatchRepository matchRepo;
  late _QueueRepo queue;
  late WebSocketService socket;

  setUpAll(() async {
    dotenv.loadFromString(envString: 'ENABLE_LOGGING=false');
    await loadV21Fonts();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    session = await goldenSession();
    matchRepo = _PlayRepo();
    queue = _QueueRepo();
    socket = GoldenSocket();
    getIt
      ..registerFactory<WebSocketService>(() => socket)
      ..registerFactoryParam<MatchViewModel, String, void>(
        (id, _) => MatchViewModel(matchRepo, socket, session, matchId: id),
      )
      ..registerFactory<MatchmakingViewModel>(
        () => MatchmakingViewModel(queue, socket, session, trainingEnabled: () async => true),
      );
  });

  Future<void> pump(WidgetTester t, Widget screen, Size size, {int frames = 10}) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ChangeNotifierProvider<SessionManager>.value(
        value: session,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          home: RepaintBoundary(key: const Key('screen'), child: screen),
        ),
      ),
    );
    await t.runAsync(() async {
      for (final a in V21Assets.all) {
        await precacheImage(AssetImage(a), t.binding.rootElement!);
      }
    });
    for (var i = 0; i < frames; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> unmount(WidgetTester t) => t.pumpWidget(const SizedBox.shrink());

  Future<void> tapText(WidgetTester t, String text) async {
    final f = find.text(text);
    await t.ensureVisible(f);
    await t.pump();
    await t.tap(f);
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
  }

  // ------------------------------------------------------------------
  group('Arama aşaması (hf3–hf6)', () {
    test('süre ve bağlantıya göre aşama', () {
      expect(searchPhaseFor(const Duration(seconds: 8), online: true), V21SearchPhase.searching);
      expect(searchPhaseFor(const Duration(seconds: 25), online: true), V21SearchPhase.widened);
      expect(searchPhaseFor(const Duration(seconds: 61), online: true), V21SearchPhase.notFound);
      expect(searchPhaseFor(const Duration(seconds: 8), online: false), V21SearchPhase.offline);
    });
  });

  group('Maça Hazırlan', () {
    testWidgets('kadro hazır, seçenekler, kart kaybı ve koruma', (t) async {
      await pump(t, const V21MatchmakingScreen(), const Size(390, 844));
      expect(t.takeException(), isNull);
      expect(find.text('MAÇA HAZIRLAN'), findsOneWidget);
      expect(find.text('Takımın hazır mı?'), findsOneWidget);
      expect(find.text('Kadro hazır'), findsOneWidget);
      expect(find.text('RAKİP BUL'), findsOneWidget);
      expect(find.text('BOTLA ANTRENMAN'), findsOneWidget);
      expect(find.text('KADROYU DÜZENLE'), findsOneWidget);
      expect(find.textContaining('KARTLARINI KORU'), findsOneWidget, reason: 'kart kaybı varsayılan açık');
      await unmount(t);
    });

    testWidgets('RAKİP BUL → RAKİP ARANIYOR; menü gizli; iptal hazırlığa döner', (t) async {
      await pump(t, const V21MatchmakingScreen(), const Size(390, 844));
      expect(find.byType(V21BottomNavigation), findsOneWidget);
      await tapText(t, 'RAKİP BUL');
      expect(queue.finds, 1);
      expect(find.text('RAKİP ARANIYOR'), findsOneWidget);
      expect(find.text('Benzer güçte rakip aranıyor'), findsOneWidget);
      expect(find.byType(V21BottomNavigation), findsNothing, reason: 'aramada çıkış yalnız iptal');
      await tapText(t, 'ARAMAYI İPTAL ET');
      expect(queue.cancels, 1);
      expect(find.text('MAÇA HAZIRLAN'), findsOneWidget);
      await unmount(t);
    });

    testWidgets('kadro geçersiz: RAKİP BUL arama yapmaz, KADRO GEÇERSİZ uyarısı', (t) async {
      queue = _QueueRepo(valid: false);
      await pump(t, const V21MatchmakingScreen(), const Size(390, 844));
      expect(find.text('Kadroda 10 kart var'), findsOneWidget);
      await tapText(t, 'RAKİP BUL');
      expect(find.text('KADRO GEÇERSİZ'), findsOneWidget);
      expect(queue.finds, 0);
      await tapText(t, 'KAPAT');
      await unmount(t);
    });

    testWidgets('bağlantı kopuk: BAĞLANTI KONTROL EDİLİYOR', (t) async {
      socket = _OfflineSocket();
      await pump(t, const V21MatchmakingScreen(), const Size(390, 844));
      await tapText(t, 'RAKİP BUL');
      // Kısa kopmada uyarı yok, birkaç saniye sürerse gösterilir
      expect(find.text('BAĞLANTI KONTROL EDİLİYOR'), findsNothing);
      await t.pump(const Duration(seconds: 7));
      expect(find.text('BAĞLANTI KONTROL EDİLİYOR'), findsOneWidget);
      expect(find.textContaining('otomatik sürüyor'), findsOneWidget);
      await tapText(t, 'ARAMAYI İPTAL ET');
      await unmount(t);
    });
  });

  // ------------------------------------------------------------------
  group('Arena', () {
    testWidgets('skor, sayaç, adımlar, el; rakibin açtığı kart görünür', (t) async {
      await pump(t, const V21ArenaScreen(matchId: 'm'), const Size(390, 844));
      expect(t.takeException(), isNull);
      expect(find.bySemanticsLabel(RegExp(r'^Skor: sen 2, StormFC 2\. TUR 5/11')), findsOneWidget);
      expect(find.text('FORVET KARTINI SEÇ'), findsOneWidget);
      expect(find.text('2 kart uygun'), findsOneWidget);
      expect(find.text('Hız Ustası'), findsOneWidget, reason: 'sıralı kuralda rakibin açtığı kart açık');
      final ok = t.widget<V21GameButton>(find.widgetWithText(V21GameButton, 'OYNA!'));
      expect(ok.status, V21ButtonStatus.disabled, reason: 'kart seçilmeden oynanmaz');
      await unmount(t);
    });

    testWidgets('V3: kart + taktik TEK playCard çağrısıyla gider', (t) async {
      final repo = matchRepo as _PlayRepo;
      await pump(t, const V21ArenaScreen(matchId: 'm'), const Size(390, 844));
      await t.tap(find.text('Kuzey Yıldızı'));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('SEÇİLİ KART'), findsOneWidget);
      await t.tap(find.bySemanticsLabel(RegExp(r'^Yüksek Pres, 3 enerji')));
      await t.pump(const Duration(milliseconds: 300));
      expect(repo.plays, isEmpty, reason: 'taktik seçmek istek göndermez');
      await t.tap(find.text('OYNA!'));
      await t.pump(const Duration(milliseconds: 300));
      expect(repo.plays, [('2', MatchTactic.highPress)]);
      await unmount(t);
    });

    testWidgets('mevki aşaması (lider): seç → DEVAM ET → choosePosition', (t) async {
      final repo = _V4Repo(phase: 'position');
      matchRepo = repo;
      await pump(t, const V21ArenaScreen(matchId: 'm'), const Size(390, 844));
      expect(find.text('Bu tur oynayacağın mevkiyi seç'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Adım 1 / 3: mevki')), findsOneWidget);
      final devam = t.widget<V21GameButton>(find.widgetWithText(V21GameButton, 'DEVAM ET'));
      expect(devam.status, V21ButtonStatus.disabled);
      await t.tap(find.bySemanticsLabel(RegExp(r'^FORVET, elinde 2 kart')));
      await t.pump(const Duration(milliseconds: 200));
      await t.tap(find.text('DEVAM ET'));
      await t.pump(const Duration(milliseconds: 300));
      expect(repo.secilenMevkiler, [CardPosition.forward]);
      await unmount(t);
    });

    testWidgets('mevki aşaması (rakip lider): bekleme', (t) async {
      matchRepo = _V4Repo(phase: 'position', amILead: false);
      await pump(t, const V21ArenaScreen(matchId: 'm'), const Size(390, 844));
      expect(find.text('RAKİP MEVKİ SEÇİYOR'), findsOneWidget);
      expect(find.text('Rakip bu turun mevkisini seçiyor'), findsOneWidget);
      await unmount(t);
    });

    testWidgets('hamle kilitli (hf10): RAKİP BEKLENİYOR, adımlar tamam', (t) async {
      matchRepo = _V4Repo(phase: 'pick', iHavePlayed: true);
      await pump(t, const V21ArenaScreen(matchId: 'm'), const Size(390, 844));
      expect(find.text('RAKİP BEKLENİYOR'), findsOneWidget);
      expect(find.textContaining('Hamlen kilitlendi'), findsOneWidget);
      expect(find.text('SEÇİMİN KİLİTLENDİ'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(3));
      await unmount(t);
    });

    testWidgets('bağlantı kopuk (hf11): oyunu kapatmayan şerit, kısa kopmada görünmez', (t) async {
      socket = _OfflineSocket();
      await pump(t, const V21ArenaScreen(matchId: 'm'), const Size(390, 844));
      expect(find.text('BAĞLANTI YENİDEN KURULUYOR'), findsNothing);
      await t.pump(const Duration(seconds: 5));
      expect(find.text('BAĞLANTI YENİDEN KURULUYOR'), findsOneWidget);
      expect(find.text('TEKRAR DENE'), findsOneWidget);
      // Şerit oyunu kapatmaz: OYNA! hâlâ görünür ve dokunulabilir
      expect(find.text('OYNA!').hitTestable(), findsWidgets);
      await unmount(t);
    });

    testWidgets('arkadaş maçı ödülsüz gösterilir ve teslim olma uyarısı kart kaybı söylemez', (t) async {
      matchRepo = _FriendlyRepo();
      await pump(t, const V21ArenaScreen(matchId: 'm'), const Size(390, 844));
      expect(find.text('ARKADAŞ MAÇI · ÖDÜL YOK'), findsOneWidget);
      await tapText(t, 'Teslim ol');
      expect(find.textContaining('Bu modda puan, ödül ve kart kaybı yok.'), findsOneWidget);
      expect(find.textContaining('kalıcı olarak rakibe geçer'), findsNothing);
      await tapText(t, 'DEVAM ET');
      await unmount(t);
    });

    testWidgets('teslim ol onayı: DEVAM ET maçta kalır', (t) async {
      await pump(t, const V21ArenaScreen(matchId: 'm'), const Size(390, 844));
      await tapText(t, 'Teslim ol');
      expect(find.text('TESLİM OL?'), findsOneWidget);
      expect(find.textContaining('kalıcı olarak rakibe geçer'), findsOneWidget);
      await tapText(t, 'DEVAM ET');
      expect(find.text('TESLİM OL?'), findsNothing);
      await unmount(t);
    });
  });

  // ------------------------------------------------------------------
  group('Golden + duyarlılık', () {
    final screens = <String, (Widget Function(), void Function())>{
      'matchmaking': (() => const V21MatchmakingScreen(), () {}),
      'arena': (() => const V21ArenaScreen(matchId: 'm'), () {}),
      'arena_position': (() => const V21ArenaScreen(matchId: 'm'), () => matchRepo = _V4Repo(phase: 'position')),
      'arena_locked': (
        () => const V21ArenaScreen(matchId: 'm'),
        () => matchRepo = _V4Repo(phase: 'pick', iHavePlayed: true),
      ),
      'arena_reconnect': (() => const V21ArenaScreen(matchId: 'm'), () => socket = _OfflineSocket()),
    };
    for (final e in screens.entries) {
      for (final size in kV21AllSizes) {
        testWidgets('${e.key} ${v21SizeName(size)}', (t) async {
          e.value.$2();
          await pump(t, e.value.$1(), size);
          if (e.key == 'arena_reconnect') {
            await t.pump(const Duration(seconds: 5));
            // Kart resimleri gerçek zamanda çözülür
            await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
            await t.pump(const Duration(milliseconds: 100));
          }
          expect(t.takeException(), isNull, reason: 'taşma olmamalı');
          if (skipGolden == null && v21GoldenFor(size)) {
            await expectLater(
              find.byKey(const Key('screen')),
              matchesGoldenFile('goldens/v21_${e.key}_${v21SizeName(size)}.png'),
            );
          }
          await unmount(t);
        });
      }
    }

    for (final size in kV21AllSizes) {
      testWidgets('matchmaking_search ${v21SizeName(size)}', (t) async {
        await pump(t, const V21MatchmakingScreen(), size);
        await tapText(t, 'RAKİP BUL');
        expect(t.takeException(), isNull, reason: 'taşma olmamalı');
        if (skipGolden == null && v21GoldenFor(size)) {
          await expectLater(
            find.byKey(const Key('screen')),
            matchesGoldenFile('goldens/v21_matchmaking_search_${v21SizeName(size)}.png'),
          );
        }
        await tapText(t, 'ARAMAYI İPTAL ET');
        await unmount(t);
      });
    }
  });

  group('390×844 referans karşılaştırması', () {
    testWidgets('Canlı Arena', (t) async {
      // Referansla aynı durum: eş zamanlı seçim, forvet, kart seçili
      matchRepo = _V4Repo(phase: 'pick');
      await pump(t, const V21ArenaScreen(matchId: 'm'), const Size(390, 844));
      await t.tap(find.text('Kuzey Yıldızı'));
      for (var i = 0; i < 8; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      final boundary = t.renderObject<RenderRepaintBoundary>(find.byKey(const Key('screen')));
      final r = await t.runAsync(
        () => compareWithReference(
          boundary,
          screen: 'arena',
          title: 'Canlı Arena',
          regions: const {
            'skor (0-80)': (0, 80),
            'sayaç + adımlar (80-215)': (80, 215),
            'VS kartları (215-470)': (215, 470),
            'el (470-660)': (470, 660),
            'taktik + enerji (660-750)': (660, 750),
            'OYNA! (750-844)': (750, 844),
          },
        ),
      );
      expect(r!['overall']!, lessThan(70));
      await unmount(t);
    }, skip: skipGolden != null);
  });
}
