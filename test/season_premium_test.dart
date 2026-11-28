import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/di/injection.dart';
import 'package:futbol_card/core/network/api_client.dart';
import 'package:futbol_card/features/monetization/purchase/purchase_controller.dart';
import 'package:futbol_card/features/monetization/purchase/store_client.dart';
import 'package:futbol_card/features/season/presentation/viewmodel/season_view_model.dart';
import 'package:futbol_card/ui_v21/screens/monetization/v21_purchase_widgets.dart';
import 'package:shared_models/shared_models.dart';

/// 063: güçsüz premium sezon yolu — ödül etiketi, teklifin görünürlüğü,
/// elmas bölümünde premium yolun paket gibi görünmemesi.

class _NoApi implements ApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Api extends PurchaseApi {
  _Api(this.products) : super(_NoApi());
  final List<Map<String, dynamic>> products;
  @override
  Future<Map<String, dynamic>> catalog() async => {'enabled': true, 'products': products};
}

class _Store implements StoreClient {
  final _c = StreamController<List<StorePurchase>>.broadcast();
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<Map<String, StorePrice>> prices(Set<String> ids) async => {
    for (final i in ids) i: const StorePrice('₺149,99', 149.99, 'TRY'),
  };
  @override
  Future<bool> buy(String id, {required bool consumable, required String accountId}) async => true;
  @override
  Stream<List<StorePurchase>> get updates => _c.stream;
  @override
  Future<void> complete(StorePurchase p, {bool consume = false}) async {}
  @override
  Future<List<StorePurchase>> unfinished(Set<String> consumableStoreIds) async => const [];
  @override
  Future<void> restore() async {}
}

const _premium = {
  'id': 'season_pass_premium',
  'category': 'SEASON_PASS',
  'store_product_id': 'season_pass_premium',
  'product_type': 'consumable',
  'name': 'Premium Sezon Yolu',
  'contents': {'season_premium': true},
};
const _elmas = {
  'id': 'gems_starter_100',
  'category': 'GEM_PACK',
  'store_product_id': 'gems_starter_100',
  'product_type': 'consumable',
  'name': '100 Elmas',
  'contents': {'paid_gems': 100},
};

Future<void> _kur(WidgetTester tester, List<Map<String, dynamic>> urunler, Widget w) async {
  await getIt.reset();
  getIt.registerFactory<PurchaseController>(() => PurchaseController(_Api(urunler), _Store()));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: w)),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  tearDown(() => getIt.reset());

  test('premium yolun ücretli elmas ödülü etiketlenir', () {
    final r = SeasonReward.fromJson({'type': 'paid_gems', 'amount': 5});
    expect(r.isPaidGems, isTrue);
    expect(rewardLabel(r), '5 elmas');
  });

  testWidgets('sunucu satıyorsa premium yol teklifi görünür', (tester) async {
    await _kur(tester, [_premium], const V21SeasonPremiumOffer());
    expect(find.byKey(const Key('premium-sezon-yolu')), findsOneWidget);
    expect(find.text('₺149,99'), findsOneWidget);
  });

  testWidgets('satılmıyorsa (güçlü yollu sezon / bayrak kapalı) teklif yok', (tester) async {
    await _kur(tester, [_elmas], const V21SeasonPremiumOffer());
    expect(find.byKey(const Key('premium-sezon-yolu')), findsNothing);
  });

  testWidgets('premium yol elmas bölümünde paket gibi görünmez', (tester) async {
    await _kur(tester, [_premium, _elmas], const V21GemPacksSection());
    expect(find.byKey(const Key('satin-al-gems_starter_100')), findsOneWidget);
    expect(find.byKey(const Key('satin-al-season_pass_premium')), findsNothing);
  });
}
