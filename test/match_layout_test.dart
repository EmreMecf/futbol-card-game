// Gerçek yazı tipleriyle maç ekranı yerleşim testi.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/auth/session_manager.dart';
import 'package:futbol_card/core/di/injection.dart';
import 'package:futbol_card/core/network/websocket_service.dart';
import 'package:futbol_card/core/storage/token_storage.dart';
import 'package:futbol_card/core/theme/app_theme.dart';
import 'package:futbol_card/core/utils/result.dart';
import 'package:futbol_card/features/match/domain/repositories/match_repository.dart';
import 'package:futbol_card/features/match/presentation/view/match_view.dart';
import 'package:futbol_card/features/match/presentation/viewmodel/match_view_model.dart';
import 'package:shared_models/shared_models.dart';

Future<void> f(String a, List<String> d) async {
  final y = FontLoader(a);
  for (final x in d) {
    final b = File(x).readAsBytesSync();
    y.addFont(Future.value(ByteData.view(b.buffer)));
  }
  await y.load();
}

HandCard h(
  String id,
  CardPosition p,
  CardTier t,
  int g,
  String ad, {
  int k = 0,
}) => HandCard(
  userCardId: id,
  cardId: 'c$id',
  fullName: ad,
  position: p,
  tier: t,
  power: g,
  chemistry: k,
);

class R implements MatchRepository {
  @override
  Future<Result<MatchState>> fetchState(String m) async {
    final n = DateTime.now();
    return Success(
      MatchState(
        matchId: m,
        status: MatchStatus.active,
        roundNumber: 5,
        isMyTurn: true,
        requiredPosition: CardPosition.forward,
        serverTime: n,
        turnDeadline: n.add(const Duration(seconds: 31)),
        myScore: 2,
        opponentScore: 2,
        myCardsLeft: 7,
        opponentCardsLeft: 6,
        potCount: 2,
        opponent: const OpponentInfo(id: 'o', username: 'StormFC', mmr: 1640),
      ),
    );
  }

  @override
  Future<Result<List<HandCard>>> fetchHand(String m) async => Success([
    h('1', CardPosition.forward, CardTier.gold, 84, 'Matteo Greco', k: 3),
    h(
      '3',
      CardPosition.midfielder,
      CardTier.legend,
      98,
      'Diego Maradona',
      k: 6,
    ),
  ]);
  @override
  Future<Result<MatchHistory>> fetchHistory(String m) async => const Success(
    MatchHistory(
      moves: [
        MatchMove(
          roundNumber: 5,
          userId: 'o',
          isLead: true,
          position: CardPosition.forward,
          tier: CardTier.diamond,
          power: 88,
          chemistry: 2,
          fullName: 'Hiz Ustasi',
        ),
      ],
    ),
  );
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class S implements WebSocketService {
  @override
  Stream<RealtimeEvent> get events => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class D extends TokenStorage {
  Map<String, dynamic>? k;
  @override
  Future<void> saveUser(Map<String, dynamic> u) async => k = u;
  @override
  Future<Map<String, dynamic>?> readUser() async => k;
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

/// REGRESYON: Maç ekranı 390x844 telefonda 16 piksel TAŞIYORDU.
///
/// Masadaki kartlara `masaYuksekligi - 92` ayrılıyordu ama ortadaki
/// sayaç halkası tek başına 100 piksele çıkabiliyor. Normal widget
/// testleri bunu yakalayamadı: test yazı tipi (Ahem) gerçek yazı
/// tiplerinden farklı ölçüldüğü için düzen birkaç piksel değişiyordu.
/// Bu test GERÇEK Barlow Condensed ve Nunito'yu yükleyerek, yaygın
/// telefon boyutlarında maç ekranını çiziyor.
void main() {
  setUpAll(() async {
    dotenv.loadFromString(envString: 'ENABLE_LOGGING=false');
    await f('BarlowCondensed', [
      'assets/fonts/BarlowCondensed-SemiBold.ttf',
      'assets/fonts/BarlowCondensed-Bold.ttf',
      'assets/fonts/BarlowCondensed-ExtraBold.ttf',
      'assets/fonts/BarlowCondensed-Black.ttf',
    ]);
    await f('Nunito', ['assets/fonts/Nunito-Variable.ttf']);
  });

  for (final (ad, boyut) in [
    ('iPhone SE', const Size(375, 667)),
    ('küçük Android', const Size(360, 640)),
    ('yaygın telefon', const Size(390, 844)),
    ('büyük Android', const Size(412, 915)),
  ]) {
    testWidgets(
      'maç ekranı $ad (${boyut.width.toInt()}x${boyut.height.toInt()}) taşmaz',
      (tester) async {
        await getIt.reset();
        final ses = SessionManager(D());
        await ses.updateUser(const UserModel(id: 'u', username: 'Emre'));
        getIt.registerFactoryParam<MatchViewModel, String, void>(
          (id, _) => MatchViewModel(R(), S(), ses, matchId: id),
        );
        tester.view.physicalSize = boyut;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: const MatchView(matchId: 'm'),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
        await getIt.reset();
      },
    );
  }
}
