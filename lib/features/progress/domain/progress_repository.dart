import 'package:shared_models/shared_models.dart';

import '../../../core/utils/result.dart';
import '../../../core/l10n/app_language.dart';

/// Futbolcu seviyesi (Ekonomi V2, FAZ 2). K1: dereceli gücü etkilemez.
abstract class ProgressRepository {
  Future<Result<ProgressOverview>> fetchOverview();
  Future<Result<LevelUpResult>> levelUp(String cardId,
      {required bool useJokers, bool useDiscount = false, required String idempotencyKey});
  Future<Result<ConvertCopiesResult>> convert(String cardId, int count, {required String idempotencyKey});
}

/// Sunucu hata kodu -> Türkçe mesaj
String progressErrorMessage(String? code, String fallback) => switch (code) {
      'economy_disabled' => 'Gelişim sistemi henüz açık değil.'.tr,
      'card_not_owned' => 'Bu futbolcu koleksiyonunda yok.'.tr,
      'max_level' => 'Futbolcu en yüksek seviyede.'.tr,
      'not_enough_copies' => 'Yeterli gelişim kopyası yok.'.tr,
      'not_enough_jokers' => 'Yeterli joker parça yok.'.tr,
      'not_enough_coins' => 'Yeterli altın yok.'.tr,
      'not_convertible' => 'Bu kadar kopya dönüştürülemez (destedeki ve maçtaki kartlar sayılmaz).'.tr,
      'invalid_count' => 'Geçersiz adet.'.tr,
      'not_enough_items' => 'Yeterli item yok.'.tr,
      'item_not_applicable' => 'Bu item bu futbolcuya kullanılamaz.'.tr,
      'idempotency_in_progress' => 'İstek hâlâ işleniyor, birazdan tekrar dene.'.tr,
      _ => fallback,
    };
