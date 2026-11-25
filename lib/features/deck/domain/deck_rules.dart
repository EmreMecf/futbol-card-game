import 'package:shared_models/shared_models.dart';
import '../../../core/l10n/app_language.dart';

/// Kadro kuralı: bir futbolcu kadroda yalnız bir kez olabilir. Aynı futbolcunun
/// iki kopyası farklı `userCardId` taşısa da `cardId` değerleri aynıdır.
///
/// Kural ihlal ediliyorsa oyuncuya gösterilecek mesajı, yoksa null döner.
String? duplicatePlayerMessage(Iterable<InventoryCard> cards) {
  final seen = <String>{};
  final names = <String>[];
  for (final c in cards) {
    if (!seen.add(c.cardId) && !names.contains(c.fullName)) names.add(c.fullName);
  }
  if (names.isEmpty) return null;
  return 'Bir futbolcu kadroda yalnız bir kez olabilir: {p}.'.trArgs({'p': names.join(', ')});
}
