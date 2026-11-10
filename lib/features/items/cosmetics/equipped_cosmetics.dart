import 'package:flutter/foundation.dart';

import '../../../core/di/injection.dart';
import '../domain/items_repository.dart';

/// EKONOMİ V2 (FAZ 6) — oyuncunun GİYDİĞİ kozmetikler (yuva -> slug).
///
/// Sunucudaki `user_equipped` tablosunun istemci kopyası. Envanterde
/// giy/çıkar yapılınca ve ana sayfa açılınca güncellenir. Servis kayıtlı
/// değilse (testler) ya da ekonomi kapalıysa hiçbir kozmetik çizilmez.
///
/// Kozmetikler yalnız görseldir; maçta güç vermez (K1).
class EquippedCosmetics extends ChangeNotifier {
  final ItemsRepository _repository;
  EquippedCosmetics(this._repository);

  Map<String, String> _giyilen = const {};
  Map<String, String> get equipped => _giyilen;

  /// Kayıtlı servis (yoksa null)
  static EquippedCosmetics? get current =>
      getIt.isRegistered<EquippedCosmetics>() ? getIt<EquippedCosmetics>() : null;

  String? get frame => _giyilen['frame'];
  String? get kit => _giyilen['kit'];
  String? get cardSkin => _giyilen['card_skin'];
  String? get arena => _giyilen['arena'];
  String? get victory => _giyilen['victory'];
  String? get character => _giyilen['character'];
  String? get badge => _giyilen['badge'];

  Future<void> refresh() async {
    final e = (await _repository.fetchInventory()).dataOrNull;
    if (e == null) return;
    apply(e.enabled ? e.equipped : const {});
  }

  void apply(Map<String, String> giyilen) {
    if (mapEquals(giyilen, _giyilen)) return;
    _giyilen = Map.unmodifiable(giyilen);
    notifyListeners();
  }

  /// Oturum kapanınca
  void clear() => apply(const {});
}
