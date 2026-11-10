import 'package:shared_models/shared_models.dart';

import '../../../core/utils/result.dart';

/// Futbolcu seviyesi (Ekonomi V2, FAZ 2). K1: dereceli gücü etkilemez.
abstract class ProgressRepository {
  Future<Result<ProgressOverview>> fetchOverview();
  Future<Result<LevelUpResult>> levelUp(String cardId, {required bool useJokers, required String idempotencyKey});
  Future<Result<ConvertCopiesResult>> convert(String cardId, int count, {required String idempotencyKey});
}

/// Sunucu hata kodu -> Türkçe mesaj
String progressErrorMessage(String? code, String fallback) => switch (code) {
      'economy_disabled' => 'Gelişim sistemi henüz açık değil.',
      'card_not_owned' => 'Bu futbolcu koleksiyonunda yok.',
      'max_level' => 'Futbolcu en yüksek seviyede.',
      'not_enough_copies' => 'Yeterli gelişim kopyası yok.',
      'not_enough_jokers' => 'Yeterli joker parça yok.',
      'not_enough_coins' => 'Yeterli altın yok.',
      'not_convertible' => 'Bu kadar kopya dönüştürülemez (destedeki ve maçtaki kartlar sayılmaz).',
      'invalid_count' => 'Geçersiz adet.',
      'idempotency_in_progress' => 'İstek hâlâ işleniyor, birazdan tekrar dene.',
      _ => fallback,
    };
