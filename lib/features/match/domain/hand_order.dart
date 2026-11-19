import 'package:shared_models/shared_models.dart';

/// Eldeki oynanmamış kartlar; istenen mevkinin kartları başta
/// (kendi içinde güce göre, güçlü önce). Diğerleri eski sırasıyla.
List<HandCard> handOrder(List<HandCard> el, CardPosition? zorunlu) {
  final kalan = el.where((k) => !k.isPlayed).toList();
  if (zorunlu == null) return kalan;
  final uygun = kalan.where((k) => k.position == zorunlu).toList()
    ..sort((a, b) => b.effectivePower.compareTo(a.effectivePower));
  return [...uygun, ...kalan.where((k) => k.position != zorunlu)];
}
