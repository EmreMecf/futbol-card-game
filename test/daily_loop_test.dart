// 044: günlük panel metinleri, paket gelişim kopyası özeti, model ayrıştırma.
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/features/daily/domain/daily_texts.dart';
import 'package:futbol_card/features/store/domain/pack_texts.dart';
import 'package:shared_models/shared_models.dart';

ChestCard _kart(String ad, String sonuc) => ChestCard(
    cardId: ad, slug: ad, fullName: ad, position: CardPosition.midfielder, tier: CardTier.gold, power: 80, outcome: sonuc);

void main() {
  test('günlük panel: alınmadıysa bugünkü sandık ve seri', () {
    final (s, g) = DailyPanelTexts.texts(const DailyStatus(enabled: true, streak: 2, chestType: 'silver'));
    expect(s, contains('ücretsiz Gümüş sandık'));
    expect(s, contains('Seri: 2 gün'));
    expect(g, contains('2 kat sezon XP'));
  });

  test('günlük panel: alındıysa ve ilk galibiyet yapıldıysa', () {
    final (s, g) = DailyPanelTexts.texts(
        const DailyStatus(enabled: true, claimedToday: true, streak: 1, chestType: 'bronze', firstWinToday: true));
    expect(s, contains('Bronz sandığı alındı'));
    expect(g, contains('alındı'));
  });

  test('DailyStatus ve DailyShopStatus sunucu JSON biçimi', () {
    final d = DailyStatus.fromJson({
      'enabled': true, 'claimed_today': false, 'streak': 3, 'chest_type': 'bronze',
      'first_win_today': true, 'first_win_multiplier': 2, 'next_reset_at': '2026-11-13T21:00:00Z',
    });
    expect(d.firstWinToday, isTrue);
    expect(d.nextResetAt?.toUtc().hour, 21);
    final t = DailyShopStatus.fromJson({
      'enabled': true, 'pack_slug': 'squad', 'name': 'Kadro Paketi', 'card_count': 11,
      'price': 4000, 'discount_pct': 25, 'discounted_price': 3000, 'bought_today': false,
    });
    expect(t.discountedPrice, 3000);
  });

  test('paket yanıtı: progress listesi okunur (eski sunucu göndermezse boş)', () {
    final eski = PackOpenResult.fromJson({'pack_slug': 's', 'pack_name': 'S'});
    expect(eski.progress, isEmpty);
    final yeni = PackOpenResult.fromJson({
      'pack_slug': 's', 'pack_name': 'S',
      'progress': [
        {'card_id': 'c', 'slug': 'c', 'full_name': 'Ali', 'position': 'MID', 'tier': 'gold', 'power': 80, 'outcome': 'copy'},
      ],
    });
    expect(yeni.progress.single.outcome, 'copy');
  });

  test('gelişim kopyası özeti', () {
    expect(progressSummary([_kart('Ali', 'copy'), _kart('Veli', 'copy')]),
        'Zaten sahip olduğun 2 futbolcu fiziksel kart yerine gelişim kopyası oldu: Ali, Veli.');
    expect(progressSummary([_kart('Can', 'joker')]), 'Seviye 10 olan 1 futbolcu joker parçaya dönüştü.');
  });
}
