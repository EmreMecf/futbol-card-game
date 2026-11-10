import 'package:flutter_test/flutter_test.dart';
import 'package:shared_models/shared_models.dart';

/// Ekonomi V2 FAZ 0: sunucu <-> uygulama JSON sözleşmesi.
void main() {
  test('EconomyConfig: sunucu biçimini okur, tanımsız anahtar kapalı', () {
    final c = EconomyConfig.fromJson({
      'flags': {'economy_v2_enabled': false, 'deneme': true},
      'versions': {'feature_flags': 1},
      'server_time': '2026-11-10T09:00:00.000Z',
    });
    expect(c.isV2Enabled, isFalse);
    expect(c.flag('deneme'), isTrue);
    expect(c.flag('olmayan'), isFalse, reason: 'güvenli varsayılan: kapalı');
    expect(c.versions['feature_flags'], 1);
    expect(c.serverTime.isUtc, isTrue);
  });

  test('EconomyConfig: alanlar eksikse çökmeden kapalı', () {
    final c = EconomyConfig.fromJson({'server_time': '2026-11-10T09:00:00.000Z'});
    expect(c.isV2Enabled, isFalse);
    expect(c.versions, isEmpty);
  });

  test('LedgerEntry: defter satırı (snake_case) okunur ve geri yazılır', () {
    final json = {
      'id': 42,
      'entry_type': 'chest_open',
      'coins_delta': 120,
      'coins_after': 1220,
      'items': {'joker_gold': 1},
      'source_type': 'chest',
      'source_id': 'abc',
      'created_at': '2026-11-10T09:00:00.000Z',
    };
    final e = LedgerEntry.fromJson(json);
    expect(e.coinsDelta, 120);
    expect(e.items['joker_gold'], 1);
    expect(LedgerEntry.fromJson(e.toJson()), e);
  });
}
