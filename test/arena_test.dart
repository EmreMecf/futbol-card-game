import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/auth/session_manager.dart';
import 'package:futbol_card/core/network/websocket_service.dart';
import 'package:futbol_card/core/storage/token_storage.dart';
import 'package:futbol_card/core/theme/app_theme.dart';
import 'package:futbol_card/core/utils/result.dart';
import 'package:futbol_card/features/match/domain/clash_event.dart';
import 'package:futbol_card/features/match/domain/repositories/match_repository.dart';
import 'package:futbol_card/features/match/presentation/arena/arena_backdrop.dart';
import 'package:futbol_card/features/match/presentation/arena/clash_scene.dart';
import 'package:futbol_card/features/match/presentation/viewmodel/match_view_model.dart';
import 'package:shared_models/shared_models.dart';

/// FAZ 4 — Arena: çatışma olayı, düello senaryoları, sahne.
///
/// EN ÖNEMLİ BEKLENTİ (MD bölüm 6): Sonucu animasyon belirlemez.
/// Bu testler, sahnenin SUNUCUNUN söylediği kazananı oynattığını ve
/// istemcinin hiçbir güç karşılaştırması yapmadığını kilitliyor.
void main() {
  // ViewModel log yazarken .env'deki log ayarını okuyor
  setUpAll(() => dotenv.loadFromString(envString: 'ENABLE_LOGGING=false'));

  const benimId = 'u-1';
  const rakipId = 'u-2';

  MatchMove hamle({
    required bool benim,
    required int tur,
    int guc = 80,
    int kimya = 0,
    CardTier seviye = CardTier.gold,
    CardPosition mevki = CardPosition.forward,
    bool acan = false,
    bool pas = false,
  }) =>
      MatchMove(
        roundNumber: tur,
        userId: benim ? benimId : rakipId,
        isMine: benim,
        isLead: acan,
        isPass: pas,
        position: pas ? null : mevki,
        tier: pas ? null : seviye,
        power: pas ? null : guc,
        chemistry: kimya,
        fullName: benim ? 'Benim' : 'Rakip',
      );

  MatchRound tur(int no, {String? kazanan, bool berabere = false, int kart = 2}) =>
      MatchRound(
        roundNumber: no,
        winnerId: kazanan,
        isDraw: berabere,
        cardsWon: [for (var i = 0; i < kart; i++) 'k$no-$i'],
      );

  // ==================================================================
  // ÇATIŞMA OLAYI
  // ==================================================================
  group('ClashEvent.fromServer', () {
    test('kazananı SUNUCUDAN okur, gücü karşılaştırmaz', () {
      // Benim kartım DAHA GÜÇLÜ ama sunucu rakibi kazanan yazmış
      // (ör. ileride bir kural değişikliği). Sahne sunucuya uymalı.
      final c = ClashEvent.fromServer(
        round: tur(1, kazanan: rakipId),
        moves: [
          hamle(benim: true, tur: 1, guc: 95, acan: true),
          hamle(benim: false, tur: 1, guc: 60),
        ],
        myUserId: benimId,
      );
      expect(c.outcome, ClashOutcome.loss);
    });

    test('kazanan benim', () {
      final c = ClashEvent.fromServer(
        round: tur(1, kazanan: benimId),
        moves: [hamle(benim: true, tur: 1), hamle(benim: false, tur: 1)],
        myUserId: benimId,
      );
      expect(c.outcome, ClashOutcome.win);
      expect(c.headline, 'ELİ KAZANDIN!');
      expect(c.detail, contains('2 kart'));
    });

    test('beraberlik', () {
      final c = ClashEvent.fromServer(
        round: tur(1, berabere: true, kart: 0),
        moves: [hamle(benim: true, tur: 1), hamle(benim: false, tur: 1)],
        myUserId: benimId,
      );
      expect(c.outcome, ClashOutcome.draw);
      expect(c.detail, contains('masada'));
    });

    test('mevki turu AÇAN kartın mevkisi', () {
      final c = ClashEvent.fromServer(
        round: tur(1, kazanan: benimId),
        moves: [
          hamle(benim: true, tur: 1, mevki: CardPosition.goalkeeper),
          hamle(benim: false, tur: 1, mevki: CardPosition.goalkeeper, acan: true),
        ],
        myUserId: benimId,
      );
      expect(c.position, CardPosition.goalkeeper);
    });

    test('rakip pas geçtiyse açıklanır', () {
      final c = ClashEvent.fromServer(
        round: tur(1, kazanan: benimId),
        moves: [
          hamle(benim: true, tur: 1, acan: true),
          hamle(benim: false, tur: 1, pas: true),
        ],
        myUserId: benimId,
      );
      expect(c.opponentPassed, isTrue);
      expect(c.detail, contains('kartı yoktu'));
    });

    test('Legend kuralı: düşük güçlü Legend kazandıysa etiketlenir', () {
      final c = ClashEvent.fromServer(
        round: tur(1, kazanan: benimId),
        moves: [
          hamle(benim: true, tur: 1, guc: 93, seviye: CardTier.legend),
          hamle(benim: false, tur: 1, guc: 90, kimya: 6, seviye: CardTier.diamond),
        ],
        myUserId: benimId,
      );
      expect(c.wonByLegendRule, isTrue);
      expect(c.detail, contains('Legend kuralı'));
    });

    test('güçlü Legend normal kazandıysa Legend kuralı YAZILMAZ', () {
      final c = ClashEvent.fromServer(
        round: tur(1, kazanan: benimId),
        moves: [
          hamle(benim: true, tur: 1, guc: 97, seviye: CardTier.legend),
          hamle(benim: false, tur: 1, guc: 80),
        ],
        myUserId: benimId,
      );
      expect(c.wonByLegendRule, isFalse);
    });

    test('eksik hamle verisi çökertmez (pas sayılır)', () {
      final c = ClashEvent.fromServer(
        round: tur(1, kazanan: benimId),
        moves: [hamle(benim: true, tur: 1)],
        myUserId: benimId,
      );
      expect(c.opponentPassed, isTrue);
    });
  });

  group('findNewClashes', () {
    test('sadece gösterilmemiş turlar, sırayla', () {
      final gecmis = MatchHistory(
        rounds: [tur(3, kazanan: benimId), tur(1, kazanan: rakipId), tur(2, berabere: true)],
        moves: [
          for (final t in [1, 2, 3]) ...[
            hamle(benim: true, tur: t),
            hamle(benim: false, tur: t),
          ],
        ],
      );
      final yeni = findNewClashes(
        history: gecmis,
        alreadyShown: {1},
        myUserId: benimId,
      );
      expect(yeni.map((c) => c.roundNumber), [2, 3]);
      expect(yeni.first.outcome, ClashOutcome.draw);
    });
  });

  // ==================================================================
  // DÜELLO SENARYOLARI — kazanan sunucudan, sahne ona uyar
  // ==================================================================
  group('DuelPainter.senaryo', () {
    ClashEvent olay(ClashOutcome sonuc, CardPosition mevki,
            {bool rakipPas = false}) =>
        ClashEvent(
          roundNumber: 1,
          outcome: sonuc,
          position: mevki,
          myMove: hamle(benim: true, tur: 1, mevki: mevki),
          opponentMove: hamle(benim: false, tur: 1, mevki: mevki, pas: rakipPas),
        );

    test('FORVET: kazanırsam top RAKİBİN kalesinde (uzak, v≈0) biter', () {
      final son = DuelPainter.senaryo(olay(ClashOutcome.win, CardPosition.forward), 1);
      expect(son.top.dy, lessThan(0.05));
    });

    test('FORVET: kaybedersem top BENİM kalemde (yakın, v≈1) biter', () {
      final son = DuelPainter.senaryo(olay(ClashOutcome.loss, CardPosition.forward), 1);
      expect(son.top.dy, greaterThan(0.95));
    });

    test('KALECİ: kazanırsam top BENİM kalecimde durur (kurtarış)', () {
      final son = DuelPainter.senaryo(
          olay(ClashOutcome.win, CardPosition.goalkeeper), 1);
      expect(son.ben, isNotNull);
      expect((son.top - son.ben!).distance, lessThan(0.02));
      expect(son.top.dy, greaterThan(0.85), reason: 'Kendi kale ağzımda');
    });

    test('DEFANS: top kazananın tarafına seker', () {
      final kazan = DuelPainter.senaryo(olay(ClashOutcome.win, CardPosition.defender), 1);
      final kaybet = DuelPainter.senaryo(olay(ClashOutcome.loss, CardPosition.defender), 1);
      expect(kazan.top.dy, greaterThan(0.5), reason: 'Benim tarafım yakın');
      expect(kaybet.top.dy, lessThan(0.5));
    });

    test('ORTA SAHA: kazananın pas arkadaşları çizilir', () {
      final k = DuelPainter.senaryo(olay(ClashOutcome.win, CardPosition.midfielder), 0.5);
      expect(k.arkadaslar, hasLength(2));
    });

    test('BERABERLİK: top ortada kalır', () {
      final son = DuelPainter.senaryo(olay(ClashOutcome.draw, CardPosition.forward), 1);
      expect((son.top - const Offset(0.5, 0.5)).distance, lessThan(0.01));
    });

    test('rakip pas geçtiyse sahada rakip oyuncusu YOK', () {
      final k = DuelPainter.senaryo(
        olay(ClashOutcome.win, CardPosition.defender, rakipPas: true),
        0.5,
      );
      expect(k.rakip, isNull);
      expect(k.ben, isNotNull);
    });

    test('her mevki ve sonuçta her kare saha içinde (taşma yok)', () {
      for (final m in CardPosition.values) {
        for (final s in ClashOutcome.values) {
          for (var i = 0; i <= 20; i++) {
            final k = DuelPainter.senaryo(olay(s, m), i / 20);
            for (final o in [k.top, ?k.ben, ?k.rakip, ...k.arkadaslar]) {
              expect(o.dx, inInclusiveRange(-0.05, 1.05), reason: '$m $s $i');
              expect(o.dy, inInclusiveRange(-0.05, 1.05), reason: '$m $s $i');
            }
          }
        }
      }
    });
  });

  // ==================================================================
  // VIEWMODEL KUYRUĞU
  // ==================================================================
  group('MatchViewModel çatışma kuyruğu', () {
    late _SahteRepo repo;
    late MatchViewModel vm;

    setUp(() async {
      repo = _SahteRepo();
      final oturum = SessionManager(_Depo());
      await oturum.updateUser(const UserModel(id: benimId, username: 'Ben'));
      vm = MatchViewModel(repo, _SahteSoket(), oturum, matchId: 'm');
    });

    MatchHistory gecmisi(List<MatchRound> turlar) => MatchHistory(
          rounds: turlar,
          moves: [
            for (final t in turlar) ...[
              hamle(benim: true, tur: t.roundNumber),
              hamle(benim: false, tur: t.roundNumber),
            ],
          ],
        );

    test('İLK YÜKLEMEDE eski turlar oynatılmaz (maça geri dönüş)', () async {
      repo.gecmis = gecmisi([tur(1, kazanan: benimId), tur(2, kazanan: rakipId)]);
      await vm.initialize();
      expect(vm.currentClash, isNull);
      vm.dispose();
    });

    test('yeni tur gelince sahne kuyruğa girer', () async {
      repo.gecmis = gecmisi([tur(1, kazanan: benimId)]);
      await vm.initialize();

      repo.gecmis = gecmisi([tur(1, kazanan: benimId), tur(2, kazanan: rakipId)]);
      await vm.refresh();

      expect(vm.currentClash?.roundNumber, 2);
      expect(vm.currentClash?.outcome, ClashOutcome.loss);
      vm.dispose();
    });

    test('iki tur birden gelirse ikisi de SIRAYLA oynar', () async {
      repo.gecmis = gecmisi([]);
      await vm.initialize();

      repo.gecmis = gecmisi([tur(1, kazanan: benimId), tur(2, berabere: true)]);
      await vm.refresh();

      expect(vm.currentClash?.roundNumber, 1);
      vm.finishCurrentClash();
      expect(vm.currentClash?.roundNumber, 2);
      vm.finishCurrentClash();
      expect(vm.currentClash, isNull);
      vm.dispose();
    });

    test('aynı tur iki tazelemede İKİ KEZ oynatılmaz', () async {
      repo.gecmis = gecmisi([]);
      await vm.initialize();
      repo.gecmis = gecmisi([tur(1, kazanan: benimId)]);
      await vm.refresh();
      await vm.refresh();

      vm.finishCurrentClash();
      expect(vm.currentClash, isNull);
      vm.dispose();
    });
  });

  // ==================================================================
  // SAHNE
  // ==================================================================
  group('ClashScene', () {
    final olay = ClashEvent(
      roundNumber: 4,
      outcome: ClashOutcome.win,
      position: CardPosition.forward,
      cardsCollected: 2,
      myMove: hamle(benim: true, tur: 4, guc: 84, kimya: 3),
      opponentMove: hamle(benim: false, tur: 4, guc: 82),
    );

    Future<void> ac(WidgetTester tester, VoidCallback bitti) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Stack(children: [
            const Positioned.fill(child: ArenaBackdrop()),
            Positioned.fill(child: ClashScene(event: olay, onFinished: bitti)),
          ]),
        ),
      ));
    }

    testWidgets('kartlar ve gerçek güç (güç + kimya) görünür', (tester) async {
      await ac(tester, () {});
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      expect(find.text('SEN'), findsOneWidget);
      expect(find.text('RAKİP'), findsOneWidget);
      expect(find.textContaining('84 +3 kimya'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('sonuna kadar oynar, bandı gösterir, bitince haber verir',
        (tester) async {
      var bitti = 0;
      await ac(tester, () => bitti++);

      // Bant başlamadan önce
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.text('ELİ KAZANDIN!'), findsNothing);

      await tester.pump(const Duration(milliseconds: 1300));
      expect(find.text('ELİ KAZANDIN!'), findsOneWidget);
      expect(find.text('TUR 4 · FORVET'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(bitti, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dokunmak sonuca ATLAR, ikinci dokunuş kapatır',
        (tester) async {
      var bitti = 0;
      await ac(tester, () => bitti++);
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.byType(ClashScene));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('ELİ KAZANDIN!'), findsOneWidget);
      expect(bitti, 0);

      await tester.tap(find.byType(ClashScene));
      await tester.pump();
      expect(bitti, 1);
      await tester.pumpAndSettle();
      expect(bitti, 1, reason: 'İki kez haber verilmemeli');
    });

    testWidgets('her mevki ve sonuçta taşmadan çizilir', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      for (final m in CardPosition.values) {
        for (final s in ClashOutcome.values) {
          await tester.pumpWidget(MaterialApp(
            theme: AppTheme.dark,
            home: ClashScene(
              key: ValueKey('$m$s'),
              event: ClashEvent(
                roundNumber: 1,
                outcome: s,
                position: m,
                myMove: hamle(benim: true, tur: 1, mevki: m),
                opponentMove: hamle(benim: false, tur: 1, mevki: m),
              ),
              onFinished: () {},
            ),
          ));
          for (var i = 0; i < 6; i++) {
            await tester.pump(const Duration(milliseconds: 450));
          }
          expect(tester.takeException(), isNull, reason: '$m $s');
        }
      }
    });
  });
}

// ====================================================================
// SAHTE KAYNAKLAR
// ====================================================================
class _SahteRepo implements MatchRepository {
  MatchHistory gecmis = const MatchHistory();

  @override
  Future<Result<MatchState>> fetchState(String matchId) async => Success(
        MatchState(
          matchId: matchId,
          status: MatchStatus.active,
          roundNumber: gecmis.rounds.length + 1,
          serverTime: DateTime.now(),
        ),
      );

  @override
  Future<Result<List<HandCard>>> fetchHand(String matchId) async =>
      const Success([]);

  @override
  Future<Result<MatchHistory>> fetchHistory(String matchId) async =>
      Success(gecmis);

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _SahteSoket implements WebSocketService {

  // Her zaman bagli: kopma senaryolari match_view_model_test'te.
  @override
  Stream<bool> get connectionState => const Stream<bool>.empty();
  @override
  bool get isConnected => true;
  @override
  Stream<RealtimeEvent> get events => const Stream<RealtimeEvent>.empty();

  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Depo extends TokenStorage {
  Map<String, dynamic>? _k;

  @override
  Future<void> saveUser(Map<String, dynamic> user) async => _k = user;

  @override
  Future<Map<String, dynamic>?> readUser() async => _k;

  @override
  dynamic noSuchMethod(Invocation i) => null;
}
