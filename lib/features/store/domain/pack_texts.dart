import 'package:shared_models/shared_models.dart';

/// Paket özetindeki ilerleme açıklaması
String progressSummary(List<ChestCard> ilerleme) {
  final kopya = ilerleme.where((k) => k.outcome == 'copy').map((k) => k.fullName).toList();
  final joker = ilerleme.where((k) => k.outcome == 'joker').length;
  final parcalar = <String>[];
  if (kopya.isNotEmpty) {
    parcalar.add('Zaten sahip olduğun ${kopya.length} futbolcu fiziksel kart yerine gelişim kopyası oldu: '
        '${kopya.join(', ')}.');
  }
  if (joker > 0) parcalar.add('Seviye 10 olan $joker futbolcu joker parçaya dönüştü.');
  return parcalar.join(' ');
}
