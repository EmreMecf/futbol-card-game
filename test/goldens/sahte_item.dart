import 'package:futbol_card/core/utils/result.dart';
import 'package:futbol_card/features/items/domain/items_repository.dart';
import 'package:shared_models/shared_models.dart';

import 'sahte_veri.dart';

/// EKONOMİ V2 (FAZ 3) — item envanteri sahte verisi (yalnız test).
/// Katalog, sunucudaki 034 tohumuyla aynı adlar ve kurallar.
ItemDefinition _d(String slug, String kind, String category, String name, String desc,
        {int? max, int? sure, String? yuva, Map<String, dynamic> params = const {}, int sira = 0}) =>
    ItemDefinition(
        slug: slug, kind: kind, category: category, name: name, description: desc, maxStack: max,
        durationSeconds: sure, cosmeticSlot: yuva, params: params, sortOrder: sira);

final kGoldenItemCatalog = [
  _d('chest_key', 'consumable', 'chest_key', 'Sandık anahtarı',
      'Yuvadaki bir sandığın kilidini anında açar. Efsane sandık 2 anahtar ister.', max: 10, sira: 10),
  _d('chest_speedup_2h', 'consumable', 'chest_speedup', 'Sandık hızlandırıcı (2 sa)',
      'Kilidi açılan sandığın kalan süresinden 2 saat düşer.', max: 20, sira: 20),
  _d('energy_drink', 'consumable', 'energy_drink', 'Enerji içeceği', '+3 ödül enerjisi. Günde en fazla 2 kez kullanılır.',
      max: 10, params: {'energy': 3, 'daily_limit': 2}, sira: 30),
  _d('mastery_book_gold', 'consumable', 'mastery_book', 'Ustalık kitabı (Altın)',
      'Bir Altın futbolcuya bir seviyelik gelişim kopyası verir; altın yine ödenir.', max: 50, sira: 42),
  _d('joker_bronze', 'stackable', 'joker', 'Joker parça (Bronz)', 'Bronz futbolcularda eksik gelişim kopyasının yerine geçer.',
      max: 9999, sira: 50),
  _d('level_discount_25', 'timed', 'level_discount', 'Gelişim indirimi (%25)',
      'Sonraki seviye atlamanın altınına %25 indirim. Tek kullanım, 7 gün geçerli.', sure: 604800, sira: 60),
  _d('frame_season1', 'cosmetic', 'profile_frame', 'Profil çerçevesi: Sezon 1', 'Profil avatarının çevresinde sezon çerçevesi.',
      yuva: 'frame', sira: 80),
  _d('kit_season1', 'cosmetic', 'kit', 'Forma: Sezon 1', '2D karakterlerin forması (yüz kimliği değişmez).', yuva: 'kit', sira: 81),
];

final kGoldenItemInventory = ItemInventory(
  catalog: kGoldenItemCatalog,
  items: [
    const OwnedItem(slug: 'chest_key', quantity: 3),
    const OwnedItem(slug: 'chest_speedup_2h', quantity: 1),
    const OwnedItem(slug: 'energy_drink', quantity: 2),
    const OwnedItem(slug: 'mastery_book_gold', quantity: 1),
    const OwnedItem(slug: 'joker_bronze', quantity: 4),
    OwnedItem(slug: 'level_discount_25', quantity: 1, expiresAt: kGoldenServerTime.add(const Duration(days: 5))),
    const OwnedItem(slug: 'frame_season1', quantity: 1),
    const OwnedItem(slug: 'kit_season1', quantity: 1),
  ],
  equipped: const {'kit': 'kit_season1'},
  energyDrinksToday: 1,
  enabled: true,
  serverTime: kGoldenServerTime,
);

class GoldenItemsRepo implements ItemsRepository {
  final kullanilan = <String>[];
  final anahtarlar = <String>[];

  @override
  Future<Result<ItemInventory>> fetchInventory() async => Success(kGoldenItemInventory);

  @override
  Future<Result<Map<String, dynamic>>> use(String slug,
      {Map<String, dynamic> target = const {}, required String idempotencyKey}) async {
    kullanilan.add(slug);
    anahtarlar.add(idempotencyKey);
    return Success(slug == 'energy_drink' ? {'energy': 8} : {'chest_ready': true});
  }

  @override
  Future<Result<void>> equip(String slug, {required String idempotencyKey}) async => const Success(null);
  @override
  Future<Result<void>> unequip(String slot, {required String idempotencyKey}) async => const Success(null);
}
