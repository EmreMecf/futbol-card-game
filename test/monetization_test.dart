import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/auth/session_manager.dart';
import 'package:futbol_card/core/di/injection.dart';
import 'package:futbol_card/core/error/app_exception.dart';
import 'package:futbol_card/core/network/api_client.dart';
import 'package:futbol_card/features/monetization/monetization_api.dart';
import 'package:futbol_card/features/monetization/monetization_models.dart';
import 'package:futbol_card/features/monetization/rewarded_ad_controller.dart';
import 'package:futbol_card/features/monetization/rewarded_ad_provider.dart';
import 'package:futbol_card/ui_v21/screens/monetization/v21_ad_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'goldens/sahte_veri.dart';

/// 060: ödüllü reklam durum makinesi + günlük ödül hapı

class _NoApi implements ApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Sahte sunucu: oturum açar, olayları kaydeder, doğrulamayı [ssvAfterPolls]
/// yoklamadan sonra "granted" yapar (null: hiç gelmez).
class FakeMonetizationApi extends MonetizationApi {
  FakeMonetizationApi() : super(_NoApi());

  final events = <String>[];
  int sessionsCreated = 0;
  int? ssvAfterPolls = 1;
  String finalStatus = 'granted';
  String? createError;
  bool dailyEnabled = true;
  int remaining = 2;
  int _polls = 0;

  @override
  Future<AdStatus> status() async => AdStatus.fromJson({
    'placements': {
      'daily_reward': {
        'placement': 'daily_reward',
        'eligible': dailyEnabled && remaining > 0,
        'reason': dailyEnabled ? (remaining > 0 ? null : 'placement_limit') : 'monetization_disabled',
        'reward': {'type': 'coins', 'amount': 40},
        'remaining_today': remaining,
        'placement_limit': 2,
      },
    },
    'credits': [],
  });

  @override
  Future<AdSession> createSession(AdPlacement p, {String? targetId}) async {
    if (createError != null) throw AppException(message: 'x', technicalDetail: createError);
    sessionsCreated++;
    return const AdSession(sessionId: 's1', ssvUserId: 'u1', customData: 's1', reward: AdReward(type: 'coins', amount: 40));
  }

  @override
  Future<AdSessionState> event(String id, String event) async {
    events.add(event);
    return const AdSessionState(status: 'reserved');
  }

  @override
  Future<AdSessionState> sessionState(String id) async {
    _polls++;
    if (ssvAfterPolls != null && _polls >= ssvAfterPolls!) {
      if (finalStatus == 'granted') remaining--;
      return AdSessionState(status: finalStatus, coinsAfter: 2490);
    }
    return const AdSessionState(status: 'verifying');
  }
}

class FakeProvider implements RewardedAdProvider {
  bool consent = true;
  bool loads = true;
  AdShowResult result = AdShowResult.earned;
  Completer<void>? holdShow;
  final calls = <String>[];

  @override
  Future<bool> ensureConsent() async => consent;
  @override
  Future<bool> load({required String ssvUserId, required String customData}) async {
    calls.add('load:$ssvUserId:$customData');
    return loads;
  }

  @override
  Future<AdShowResult> show() async {
    calls.add('show');
    await holdShow?.future;
    return result;
  }

  @override
  Future<bool> privacyOptionsRequired() async => false;
  @override
  Future<void> showPrivacyOptions() async {}
  @override
  void dispose() {}
}

void main() {
  late FakeMonetizationApi api;
  late FakeProvider provider;
  late SessionManager session;

  setUpAll(() => dotenv.loadFromString(envString: 'ENABLE_LOGGING=false'));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    api = FakeMonetizationApi();
    provider = FakeProvider();
    session = await goldenSession();
  });

  RewardedAdController ctrl() => RewardedAdController(api, provider,
      session: session, pollEvery: const Duration(milliseconds: 1), pollFor: const Duration(milliseconds: 200));

  test('reklam tamamlanır → doğrulanır → ödül; SSV bilgisi reklama verilir', () async {
    final c = ctrl();
    final states = <AdLifecycleState>[];
    c.addListener(() => states.add(c.state));
    final son = await c.watch(AdPlacement.dailyReward);
    expect(son, AdLifecycleState.rewardGranted);
    expect(provider.calls.first, 'load:u1:s1', reason: 'SSV kullanıcı ve oturum kimliği');
    expect(api.events, ['shown', 'earned']);
    expect(states, containsAllInOrder([
      AdLifecycleState.eligibilityChecking,
      AdLifecycleState.loading,
      AdLifecycleState.showing,
      AdLifecycleState.awaitingVerification,
      AdLifecycleState.rewardGranted,
    ]));
    expect(session.user!.coins, 2490, reason: 'bakiye SUNUCUDAN');
    expect(c.lastReward?.amount, 40);
  });

  test('istemci "kazandım" dese de sunucu onaylamadan ödül yok (doğrulama gecikirse bekler)', () async {
    api.ssvAfterPolls = null;
    final c = ctrl();
    final son = await c.watch(AdPlacement.dailyReward);
    expect(son, AdLifecycleState.awaitingVerification);
    expect(c.verificationPending, isTrue);
    expect(c.lastReward, isNull);
    expect(session.user!.coins, kGoldenUser.coins);
  });

  test('sunucu reddederse ödül yok', () async {
    api.finalStatus = 'rejected';
    final son = await ctrl().watch(AdPlacement.dailyReward);
    expect(son, AdLifecycleState.failed);
    expect(session.user!.coins, kGoldenUser.coins);
  });

  test('reklam yüklenmezse oyun devam eder, hak düşmez (failed olayı), yeniden deneme yok', () async {
    provider.loads = false;
    final c = ctrl();
    final son = await c.watch(AdPlacement.dailyReward);
    expect(son, AdLifecycleState.failed);
    expect(api.events, ['failed']);
    expect(provider.calls.where((x) => x.startsWith('load')), hasLength(1));
    expect(c.message, contains('Hakkın düşmedi'));
  });

  test('yarıda kapatılan reklam ödül vermez, rezervasyon bırakılır', () async {
    provider.result = AdShowResult.closedWithoutReward;
    final son = await ctrl().watch(AdPlacement.dailyReward);
    expect(son, AdLifecycleState.cancelled);
    expect(api.events, ['shown', 'closed']);
  });

  test('rıza yoksa reklam istenmez, oturum açılmaz', () async {
    provider.consent = false;
    final son = await ctrl().watch(AdPlacement.dailyReward);
    expect(son, AdLifecycleState.failed);
    expect(api.sessionsCreated, 0);
    expect(provider.calls, isEmpty);
  });

  test('sunucu reddederse (aktif maç) oturum yok, açıklama gösterilir', () async {
    api.createError = 'ad_not_eligible';
    final son = await ctrl().watch(AdPlacement.dailyReward);
    expect(son, AdLifecycleState.failed);
    expect(provider.calls, isEmpty);
  });

  test('aynı anda ikinci reklam başlatılamaz', () async {
    provider.holdShow = Completer<void>();
    final c = ctrl();
    final ilk = c.watch(AdPlacement.dailyReward);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(c.busy, isTrue);
    await c.watch(AdPlacement.dailyReward);
    expect(api.sessionsCreated, 1);
    provider.holdShow!.complete();
    expect(await ilk, AdLifecycleState.rewardGranted);
  });

  test('uygunluk açıklamaları', () {
    expect(const AdEligibility(placement: 'x', eligible: false, reason: 'in_match').reasonText, 'Maç sürerken reklam yok.');
    expect(const AdEligibility(placement: 'x', eligible: false, reason: 'not_in_rollout').featureOff, isTrue);
    expect(const AdEligibility(placement: 'x', eligible: false, reason: 'daily_limit').featureOff, isFalse);
  });

  group('Günlük ödül hapı', () {
    setUp(() async {
      await getIt.reset();
      getIt.registerFactory<RewardedAdController>(() => ctrl());
    });

    Future<void> pump(WidgetTester t) async {
      await t.pumpWidget(const MaterialApp(home: Scaffold(body: Center(child: V21AdRewardPill()))));
      await t.pump();
      await t.pump();
    }

    testWidgets('özellik kapalıyken hiçbir şey çizilmez (oyun eskisi gibi)', (t) async {
      api.dailyEnabled = false;
      await pump(t);
      expect(find.byKey(const Key('reklam-odul-hapi')), findsNothing);
    });

    testWidgets('açıkken REKLAM etiketi, ödül ve kalan hak görünür', (t) async {
      await pump(t);
      expect(find.byKey(const Key('reklam-odul-hapi')), findsOneWidget);
      expect(find.text('REKLAM'), findsOneWidget);
      expect(find.text('+40'), findsOneWidget);
      expect(find.text('2/2'), findsOneWidget);
    });

    testWidgets('dokununca önce açık onay sorulur; vazgeçince reklam yok', (t) async {
      await pump(t);
      await t.tap(find.byKey(const Key('reklam-odul-hapi')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text('REKLAMI İZLE'), findsOneWidget);
      expect(find.textContaining('isteğe bağlı'), findsOneWidget);
      await t.tap(find.text('VAZGEÇ'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      expect(api.sessionsCreated, 0);
    });
  });
}
