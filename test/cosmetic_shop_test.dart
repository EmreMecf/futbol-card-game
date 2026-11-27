import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/error/app_exception.dart';
import 'package:futbol_card/core/network/api_client.dart';
import 'package:futbol_card/features/monetization/cosmetics/cosmetic_shop.dart';
import 'package:futbol_card/ui_v21/components/v21_cosmetics.dart';
import 'package:futbol_card/ui_v21/screens/monetization/v21_cosmetic_shop.dart';

/// 062: kozmetik mağaza — sunucu fiyatı, tekrar güvenli satın alma,
/// görünmeyen ürün satılmaz.

class _NoApi implements ApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class FakeShopApi extends CosmeticShopApi {
  FakeShopApi() : super(_NoApi());

  bool enabled = true;
  int gems = 50;
  int paidGems = 100;
  final owned = <String>{};
  final keys = <String>[];
  AppException? nextError;

  static const _teklifler = [
    ('offer_frame_neon', 'frame_neon', 'Profil çerçevesi: Neon', 'frame', 120, true),
    ('offer_victory_star_rain', 'victory_star_rain', 'Zafer animasyonu: Yıldız Yağmuru', 'victory', 150, false),
  ];

  @override
  Future<Map<String, dynamic>> shop() async => {
    'enabled': enabled,
    'gems': gems,
    'paid_gems': paidGems,
    'offers': [
      for (final (id, slug, name, slot, price, featured) in _teklifler)
        {
          'id': id,
          'item_slug': slug,
          'name': name,
          'description': 'açıklama',
          'slot': slot,
          'price_gems': price,
          'featured': featured,
          'owned': owned.contains(slug),
          'equipped': false,
        },
    ],
  };

  @override
  Future<Map<String, dynamic>> buy(String offerId, String requestKey) async {
    keys.add(requestKey);
    final e = nextError;
    if (e != null) {
      nextError = null;
      throw e;
    }
    final t = _teklifler.firstWhere((x) => x.$1 == offerId);
    final free = gems < t.$5 ? gems : t.$5;
    gems -= free;
    paidGems -= t.$5 - free;
    owned.add(t.$2);
    return {'item_slug': t.$2, 'gems': gems, 'paid_gems': paidGems};
  }
}

void main() {
  late FakeShopApi api;
  late CosmeticShopController c;

  setUp(() {
    api = FakeShopApi();
    c = CosmeticShopController(api);
  });

  test('sunucu kapalı derse mağaza görünmez', () async {
    api.enabled = false;
    await c.load();
    expect(c.enabled, isFalse);
    expect(c.offers, isEmpty);
  });

  test('liste ve bakiye sunucudan; toplam elmas iki bakiyenin toplamı', () async {
    await c.load();
    expect(c.enabled, isTrue);
    expect(c.offers.map((o) => o.id), ['offer_frame_neon', 'offer_victory_star_rain']);
    expect(c.totalGems, 150);
    expect(c.canAfford(c.offers.first), isTrue);
  });

  test('satın alma: sahip olundu, bakiye güncellendi', () async {
    await c.load();
    expect(await c.buy(c.offers.first), isTrue);
    expect(c.offers.first.owned, isTrue);
    expect(c.freeGems, 0);
    expect(c.paidGems, 30);
    // Sahip olunan tekrar alınmaz
    expect(await c.buy(c.offers.first), isFalse);
    expect(api.keys, hasLength(1));
  });

  test('ağ hatasında aynı istek anahtarıyla tekrar denenir (çift harcama yok)', () async {
    await c.load();
    api.nextError = const AppException(message: 'x', type: AppErrorType.network);
    expect(await c.buy(c.offers.first), isFalse);
    expect(await c.buy(c.offers.first), isTrue);
    expect(api.keys, hasLength(2));
    expect(api.keys[0], api.keys[1]);
  });

  test('kural hatasında anahtar bırakılır ve mesaj gösterilir', () async {
    await c.load();
    api.nextError = const AppException(message: 'x', type: AppErrorType.gameRule, technicalDetail: 'not_enough_gems');
    expect(await c.buy(c.offers.first), isFalse);
    expect(c.error, 'Yeterli elmasın yok.');
    expect(await c.buy(c.offers.first), isTrue);
    expect(api.keys[0], isNot(api.keys[1]));
  });

  test('sunucunun sattığı her kozmetik istemcide çizilebiliyor (görünmeyen ürün satılmaz)', () {
    // 062 mağaza + 063 premium sezon yolu (satılan ürünlerin içeriği)
    final sql = [
      'database/migrations/062_cosmetic_shop.sql',
      'database/migrations/063_power_free_season_pass.sql',
    ].map((p) => File(p).readAsStringSync()).join('\n');
    final kozmetikler = RegExp(r"\('((?:frame|victory)_[a-z0-9_]+)', 'cosmetic'").allMatches(sql).map((m) => m[1]!);
    expect(kozmetikler, isNotEmpty);
    for (final slug in kozmetikler) {
      final cizilir = slug.startsWith('frame_') ? cosmeticFramePalette(slug) != null : cosmeticVictoryDrawable(slug);
      expect(cizilir, isTrue, reason: '$slug istemcide çizilmiyor');
    }
  });

  testWidgets('kozmetik bölümü: önizleme açılır, onayla satın alınır', (tester) async {
    await c.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: SingleChildScrollView(child: V21CosmeticShopSection(controller: c)),
        ),
      ),
    );
    expect(find.byKey(const Key('kozmetik-magaza')), findsOneWidget);
    expect(find.text('Neon'), findsOneWidget);

    // Kart → önizleme
    await tester.tap(find.byKey(const Key('kozmetik-offer_frame_neon')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('kozmetik-onizleme')), findsOneWidget);
    await tester.tap(find.text('120 ELMAS'));
    await tester.pump(const Duration(milliseconds: 400));

    // Açık onay: ücretsiz + ücretli dağılımı yazılır
    expect(find.text('120 elmas: 50 ücretsiz + 70 satın alınmış elmas.'), findsOneWidget);
    await tester.tap(find.text('SATIN AL').last);
    await tester.pump(const Duration(milliseconds: 400));
    expect(api.owned, contains('frame_neon'));
    await tester.tap(find.text('TAMAM'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('GİY'), findsOneWidget);
  });
}
