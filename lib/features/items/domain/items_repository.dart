import 'package:shared_models/shared_models.dart';

import '../../../core/utils/result.dart';
import '../../../core/l10n/app_language.dart';

/// Item envanteri (Ekonomi V2, FAZ 3). Hiçbir item dereceli güç vermez.
abstract class ItemsRepository {
  Future<Result<ItemInventory>> fetchInventory();

  /// [target]: {"chest_id": ...} | {"card_id": ...} | {}
  Future<Result<Map<String, dynamic>>> use(String slug, {Map<String, dynamic> target, required String idempotencyKey});
  Future<Result<void>> equip(String slug, {required String idempotencyKey});
  Future<Result<void>> unequip(String slot, {required String idempotencyKey});
}

/// Sunucu hata kodu -> Türkçe mesaj
String itemErrorMessage(String? code, String fallback) => switch (code) {
      'economy_disabled' => 'Envanter henüz açık değil.'.tr,
      'item_not_found' => 'Item bulunamadı.'.tr,
      'item_not_usable' => 'Bu item doğrudan kullanılmaz.'.tr,
      'item_not_applicable' => 'Bu item burada kullanılamaz.'.tr,
      'not_enough_items' => 'Yeterli item yok.'.tr,
      'daily_limit' => 'Bugünkü kullanım sınırına ulaştın.'.tr,
      'chest_not_found' => 'Sandık bulunamadı.'.tr,
      'card_not_owned' => 'Bu futbolcu koleksiyonunda yok.'.tr,
      'max_level' => 'Futbolcu en yüksek seviyede.'.tr,
      'idempotency_in_progress' => 'İstek hâlâ işleniyor, birazdan tekrar dene.'.tr,
      _ => fallback,
    };
