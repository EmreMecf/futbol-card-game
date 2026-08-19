import 'package:shared_models/shared_models.dart';

import '../../../../core/utils/result.dart';

/// Magaza islemlerinin sozlesmesi.
abstract interface class StoreRepository {
  /// Satin alinabilir paketler
  Future<Result<List<PackType>>> fetchPacks();

  /// Paket ac.
  ///
  /// ANTI-HILE: Cekilis TAMAMEN sunucuda yapilir. Istemci sadece
  /// "su paketi acmak istiyorum" der; hangi kartlarin ciktigina
  /// karisamaz. Rastgeleligi bile veritabani uretir.
  Future<Result<PackOpenResult>> openPack(String slug);
}
