// KART GÖRSELİ DEĞİŞMEYEN KİMLİĞE BAĞLI (cards.slug)
//
// Görsel futbolcunun adına değil katalog kimliğine bağlıdır:
//   * Katalogdaki 100 kartın bugünkü görseli değişmez (slug'dan çıkan ad,
//     ilk kayıttaki adla aynı).
//   * Futbolcunun adı değişse de görsel aynı kalır.
//   * Slug gelmeyen kartlarda (eski sunucu, örnek veri) ada düşülür.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:futbol_card/ui_v21/ui_v21.dart';
import 'package:shared_models/shared_models.dart';

void main() {
  /// 010 seed'indeki (slug, ad, mevki) üçlüleri
  List<(String, String, String)> katalog() {
    final dosya = Directory('database/migrations')
        .listSync()
        .whereType<File>()
        .firstWhere((f) => f.path.replaceAll('\\', '/').split('/').last.startsWith('010_'));
    return RegExp(r"\('([a-z0-9\-]+)', '([^']+)', '(GK|DEF|MID|FWD)'")
        .allMatches(dosya.readAsStringSync())
        .map((m) => (m.group(1)!, m.group(2)!, m.group(3)!))
        .toList();
  }

  test('katalogdaki 100 kartın görseli slug ile de aynı kalır', () {
    final kartlar = katalog();
    expect(kartlar, hasLength(100));
    for (final (slug, ad, mevki) in kartlar) {
      expect(
        V21Characters.assetFor(V21Characters.keyFor(name: ad, slug: slug), position: mevki),
        V21Characters.assetFor(ad, position: mevki),
        reason: slug,
      );
    }
  });

  test('ad değişse de görsel değişmez', () {
    const slug = 'bronz-kaleci-emre-yilmaz';
    final once = V21Characters.assetFor(V21Characters.keyFor(name: 'Emre Yilmaz', slug: slug), position: 'GK');
    final sonra = V21Characters.assetFor(V21Characters.keyFor(name: 'Tamamen Yeni Ad', slug: slug), position: 'GK');
    expect(sonra, once);
  });

  test('slug yoksa ada düşülür; kalıba uymayan slug olduğu gibi kullanılır', () {
    expect(V21Characters.keyFor(name: 'Emre Yilmaz'), 'Emre Yilmaz');
    expect(V21Characters.keyFor(name: 'Emre Yilmaz', slug: '  '), 'Emre Yilmaz');
    expect(V21Characters.keyFor(name: 'X', slug: 'gold-FWD-1'), 'gold-FWD-1');
  });

  testWidgets('oyuncu kartı görseli slug\'a göre seçer', (t) async {
    await t.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: V21PlayerCard(
        name: 'Tamamen Yeni Ad',
        artKey: 'bronz-kaleci-emre-yilmaz',
        position: CardPosition.goalkeeper,
        tier: CardTier.bronze,
        power: 45,
      ),
    ));
    final art = t.widget<V21CharacterArt>(find.byType(V21CharacterArt));
    expect(art.asset, V21Characters.assetFor('Emre Yilmaz', position: 'GK'));
  });
}
