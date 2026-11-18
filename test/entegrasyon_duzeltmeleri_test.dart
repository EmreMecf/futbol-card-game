// V2.1 entegrasyon düzeltmeleri: teslim uyarısı, davet bağlantısı, hata metni, günlük şerit.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/error/app_exception.dart';
import 'package:futbol_card/features/friends/friend_room_api.dart';
import 'package:futbol_card/features/friends/friend_room_view.dart';
import 'package:futbol_card/features/match/presentation/widgets/surrender_text.dart';
import 'package:futbol_card/ui_v21/screens/home/v21_daily_strip.dart';
import 'package:shared_models/shared_models.dart';

MatchState _durum(String mod, bool? transfer) =>
    MatchState.fromJson({'match_id': 'm', 'status': 'active', 'round_number': 1, 'mode': mod, 'card_transfer': transfer});

void main() {
  group('teslim uyarısı', () {
    test('kart kaybı yoksa kart kaybından söz etmez', () {
      expect(surrenderWarning(_durum('ranked', false)), contains('Kart kaybı yok'));
      expect(surrenderWarning(_durum('ranked', false)), isNot(contains('rakibe geçer')));
      expect(surrenderWarning(_durum('friendly', null)), contains('Bu modda'));
    });
    test('kart transferli kuralda eski uyarı kalır', () {
      expect(surrenderWarning(_durum('ranked', true)), contains('rakibe geçer'));
      expect(surrenderWarning(_durum('ranked', null)), contains('rakibe geçer'));
    });
  });

  test('davet bağlantısı tıklanabilir HTTPS adresidir', () {
    final kod = 'a' * 30;
    expect(FriendRoomApi.inviteUrlFor('https://api.ornek.com', kod), 'https://api.ornek.com/invite/$kod');
  });

  test('sunucu kural mesajı aynen gösterilir, bilinmeyen hata genel kalır', () {
    expect(friendRoomErrorText(const AppException(message: 'Oda dolu.')), 'Oda dolu.');
    expect(friendRoomErrorText(StateError('x')), contains('Bağlantını kontrol'));
  });

  group('V2.1 günlük şerit', () {
    test('metinler', () {
      final (a, b) = v21DailyLines(const DailyStatus(enabled: true, streak: 2, chestType: 'silver'));
      expect(a, 'Gümüş sandık hazır · Seri 2');
      expect(b, contains('2 kat XP'));
      final (c, d) = v21DailyLines(const DailyStatus(enabled: true, claimedToday: true, chestType: 'bronze', firstWinToday: true));
      expect(c, 'Sandık alındı');
      expect(d, contains('alındı'));
    });

    testWidgets('alınmamışsa AL düğmesi var, 320 genişlikte taşmaz', (t) async {
      await t.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: V21DailyStrip(scale: 0.82, debugStatus: DailyStatus(enabled: true, streak: 12, chestType: 'silver')),
          ),
        ),
      ));
      expect(find.text('AL'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('anahtar kapalıysa yer kaplamaz', (t) async {
      await t.pumpWidget(const MaterialApp(
        home: Scaffold(body: V21DailyStrip(scale: 1, debugStatus: DailyStatus())),
      ));
      expect(find.byType(Row), findsNothing);
    });
  });
}
