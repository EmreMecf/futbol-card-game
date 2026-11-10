import 'package:shared_models/shared_models.dart';

import '../../../core/utils/result.dart';

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
      'economy_disabled' => 'Envanter henüz açık değil.',
      'item_not_found' => 'Item bulunamadı.',
      'item_not_usable' => 'Bu item doğrudan kullanılmaz.',
      'item_not_applicable' => 'Bu item burada kullanılamaz.',
      'not_enough_items' => 'Yeterli item yok.',
      'daily_limit' => 'Bugünkü kullanım sınırına ulaştın.',
      'chest_not_found' => 'Sandık bulunamadı.',
      'card_not_owned' => 'Bu futbolcu koleksiyonunda yok.',
      'max_level' => 'Futbolcu en yüksek seviyede.',
      'idempotency_in_progress' => 'İstek hâlâ işleniyor, birazdan tekrar dene.',
      _ => fallback,
    };
