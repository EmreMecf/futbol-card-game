// 058 — ARKADAŞINI DOSTLUK MAÇINA ÇAĞIR: denetleyici ve üstten kayan davet kutucuğu
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/error/app_exception.dart';
import 'package:futbol_card/core/theme/app_theme.dart';
import 'package:futbol_card/features/social/friend_challenge.dart';
import 'package:futbol_card/ui_v21/components/v21_friend_challenge_banner.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_models/shared_models.dart';

class _SahteApi implements FriendChallengeApi {
  /// Denetleyiciyle aynı (sahte) saat
  final DateTime Function() saat;
  _SahteApi(this.saat);

  List<FriendChallenge> gelen = [];
  final kabul = <String>[];
  final ret = <String>[];
  final geriCek = <String>[];
  final gonder = <String>[];
  AppException? kabulHatasi;

  FriendChallenge davet(String id, {String ad = 'ahmet', int saniye = 60, String kod = 'oda1'}) =>
      FriendChallenge.fromJson({
        'id': id,
        'code': kod,
        'status': 'pending',
        'from': {'id': 'u-$ad', 'username': ad, 'mmr': 1200},
        'to': {'id': 'ben', 'username': 'ben'},
        'seconds_left': saniye,
      }, now: saat());

  @override
  Future<List<FriendChallenge>> incomingChallenges() async => [...gelen];

  @override
  Future<FriendChallenge> acceptChallenge(String id) async {
    if (kabulHatasi != null) throw kabulHatasi!;
    kabul.add(id);
    gelen.removeWhere((c) => c.id == id);
    return davet(id, kod: 'oda-$id');
  }

  @override
  Future<FriendChallenge> declineChallenge(String id) async {
    ret.add(id);
    gelen.removeWhere((c) => c.id == id);
    return davet(id);
  }

  @override
  Future<FriendChallenge> cancelChallenge(String id) async {
    geriCek.add(id);
    return davet(id);
  }

  @override
  Future<FriendChallenge> sendChallenge(String friendId) async {
    gonder.add(friendId);
    return davet('g-$friendId', kod: 'oda-$friendId');
  }
}

void main() {
  late _SahteApi api;
  late StreamController<RealtimeEvent> olaylar;
  late StreamController<bool> baglanti;
  late FriendChallengeController c;
  var oturum = true;
  var saat = DateTime(2026, 11, 25, 12);

  FriendChallengeController kur() => FriendChallengeController(
        api,
        events: olaylar.stream,
        connection: baglanti.stream,
        isSignedIn: () => oturum,
        now: () => saat,
      );

  setUp(() {
    api = _SahteApi(() => saat);
    olaylar = StreamController<RealtimeEvent>.broadcast();
    baglanti = StreamController<bool>.broadcast();
    oturum = true;
    saat = DateTime(2026, 11, 25, 12);
    c = kur();
  });

  tearDown(() {
    c.dispose();
    olaylar.close();
    baglanti.close();
  });

  group('denetleyici', () {
    test('anlık bildirim gelince davet sorulur ve gösterilir', () async {
      c.start();
      await pumpEventQueue();
      expect(c.current, isNull);
      api.gelen = [api.davet('d1')];
      olaylar.add(const RealtimeEvent(type: RealtimeEventType.friendChallenge, challengeId: 'd1'));
      await pumpEventQueue();
      expect(c.current?.id, 'd1');
      expect(c.current?.fromName, 'ahmet');
    });

    test('bağlantı geri gelince bekleyen davetler toparlanır', () async {
      c.start();
      api.gelen = [api.davet('d2')];
      baglanti.add(true);
      await pumpEventQueue();
      expect(c.current?.id, 'd2');
    });

    test('kabul oda kodunu döner ve kutucuk kapanır', () async {
      api.gelen = [api.davet('d3')];
      c.start();
      await pumpEventQueue();
      final kod = await c.accept();
      expect(kod, 'oda-d3');
      expect(api.kabul, ['d3']);
      expect(c.current, isNull);
    });

    test('kabul reddedilirse (oda dolu vb.) mesaj gösterilir, davet gizlenir', () async {
      api.gelen = [api.davet('d4')];
      api.kabulHatasi = const AppException(message: 'Oda dolu.');
      c.start();
      await pumpEventQueue();
      final mesajlar = <String>[];
      c.messages.listen(mesajlar.add);
      expect(await c.accept(), isNull);
      await pumpEventQueue();
      expect(mesajlar, ['Oda dolu.']);
      expect(c.current, isNull);
    });

    test('ret çağırana iletilir; kaydırıp gizlenen davet yeniden gösterilmez', () async {
      api.gelen = [api.davet('d5'), api.davet('d6', ad: 'mehmet')];
      c.start();
      await pumpEventQueue();
      expect(c.current?.id, 'd5');
      await c.decline();
      await pumpEventQueue();
      expect(api.ret, ['d5']);
      expect(c.current?.id, 'd6');
      c.dismiss();
      await pumpEventQueue();
      expect(c.current, isNull);
      expect(api.ret, ['d5'], reason: 'gizlemek reddetmek değildir');
    });

    test('çağırana sonuç mesajı gider; odadan çıkınca davet geri çekilir', () async {
      c.start();
      final mesajlar = <String>[];
      c.messages.listen(mesajlar.add);
      final g = await c.send('ali-id', 'ali');
      expect(g.code, 'oda-ali-id');
      olaylar.add(RealtimeEvent(type: RealtimeEventType.friendChallengeUpdate, challengeId: g.id, status: 'declined'));
      await pumpEventQueue();
      expect(mesajlar, ['ali davetini reddetti.']);

      final g2 = await c.send('veli-id', 'veli');
      await c.cancelForRoom(g2.code);
      expect(api.geriCek, [g2.id]);
    });

    test('oturum yoksa davet sorulmaz', () async {
      oturum = false;
      api.gelen = [api.davet('d7')];
      c.start();
      await pumpEventQueue();
      expect(c.current, isNull);
    });
  });

  group('davet kutucuğu', () {
    late GoRouter router;

    Future<void> ac(WidgetTester t, {String yol = '/ana-sayfa'}) async {
      router = GoRouter(initialLocation: yol, routes: [
        for (final p in ['/ana-sayfa', '/mac/1', '/sosyal'])
          GoRoute(path: p, builder: (_, _) => Scaffold(body: Text('ekran $p'))),
        GoRoute(path: '/davet/:kod', builder: (_, s) => Scaffold(body: Text('oda ${s.pathParameters['kod']}'))),
      ]);
      await t.pumpWidget(MaterialApp.router(
        theme: AppTheme.dark,
        routerConfig: router,
        builder: (context, child) => Stack(children: [
          child!,
          V21FriendChallengeBanner(controller: c, router: router),
        ]),
      ));
      await t.pump();
      addTearDown(c.clear);
    }

    testWidgets('davet üstten gelir; KABUL ET odaya götürür', (t) async {
      api.gelen = [api.davet('k1', saniye: 45)];
      await ac(t);
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('dostluk-daveti')), findsOneWidget);
      expect(find.text('ahmet'), findsOneWidget);
      expect(find.text('seni dostluk maçına çağırıyor!'), findsOneWidget);
      expect(find.text('45'), findsOneWidget);

      // Geri sayım akar
      saat = saat.add(const Duration(seconds: 2));
      await t.pump(const Duration(seconds: 1));
      expect(find.text('43'), findsOneWidget);

      await t.tap(find.byKey(const Key('davet-kabul')));
      await t.pumpAndSettle();
      expect(api.kabul, ['k1']);
      expect(find.text('oda oda-k1'), findsOneWidget);
      expect(find.byKey(const Key('dostluk-daveti')), findsNothing);
    });

    testWidgets('REDDET kutucuğu kapatır', (t) async {
      api.gelen = [api.davet('k2')];
      await ac(t);
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.byKey(const Key('davet-reddet')));
      await t.pumpAndSettle();
      expect(api.ret, ['k2']);
      expect(find.byKey(const Key('dostluk-daveti')), findsNothing);
    });

    testWidgets('süre dolunca kendiliğinden kapanır', (t) async {
      api.gelen = [api.davet('k3', saniye: 3)];
      await ac(t);
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('dostluk-daveti')), findsOneWidget);
      api.gelen = [];
      saat = saat.add(const Duration(seconds: 4));
      await t.pump(const Duration(seconds: 4));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('dostluk-daveti')), findsNothing);
    });

    testWidgets('maç ekranında gösterilmez, maçtan çıkınca görünür', (t) async {
      api.gelen = [api.davet('k4')];
      await ac(t, yol: '/mac/1');
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('dostluk-daveti')), findsNothing);
      router.go('/sosyal');
      await t.pumpAndSettle();
      expect(find.byKey(const Key('dostluk-daveti')), findsOneWidget);
    });

    testWidgets('küçük telefonda taşma yok', (t) async {
      t.view.physicalSize = const Size(320, 568);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      api.gelen = [api.davet('k5', ad: 'çokuzunkullanıcıadıolanbiroyuncu')];
      await ac(t);
      await t.pump(const Duration(milliseconds: 400));
      expect(t.takeException(), isNull);
      expect(find.byKey(const Key('dostluk-daveti')), findsOneWidget);
    });
  });

  test('gizlenen ekranlar', () {
    expect(V21FriendChallengeBanner.hiddenOn('/mac/abc'), isTrue);
    expect(V21FriendChallengeBanner.hiddenOn('/eslesme'), isTrue);
    expect(V21FriendChallengeBanner.hiddenOn('/davet/kod'), isTrue);
    expect(V21FriendChallengeBanner.hiddenOn('/ana-sayfa'), isFalse);
    expect(V21FriendChallengeBanner.hiddenOn('/magaza'), isFalse);
    // Çağıran odada beklerken yanıt mesajını görür
    expect(V21FriendChallengeBanner.messageHiddenOn('/davet/kod'), isFalse);
    expect(V21FriendChallengeBanner.messageHiddenOn('/mac/abc'), isTrue);
  });
}
