import 'package:shared_models/shared_models.dart';
import '../../../core/l10n/app_language.dart';

/// Paket özetindeki ilerleme açıklaması
String progressSummary(List<ChestCard> ilerleme) {
  final kopya = ilerleme.where((k) => k.outcome == 'copy').map((k) => k.fullName).toList();
  final joker = ilerleme.where((k) => k.outcome == 'joker').length;
  final parcalar = <String>[];
  if (kopya.isNotEmpty) {
    parcalar.add('Zaten sahip olduğun {length} futbolcu fiziksel kart yerine gelişim kopyası oldu: {p}.'.trArgs({'length': kopya.length, 'p': kopya.join(', ')}));
  }
  if (joker > 0) parcalar.add('Seviye 10 olan {joker} futbolcu joker parçaya dönüştü.'.trArgs({'joker': joker}));
  return parcalar.join(' ');
}
