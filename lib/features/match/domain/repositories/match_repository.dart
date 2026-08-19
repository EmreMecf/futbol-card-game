import 'package:shared_models/shared_models.dart';

import '../../../../core/utils/result.dart';

/// Mac islemlerinin sozlesmesi.
abstract interface class MatchRepository {
  /// Macin genel durumu (sira kimde, skor, kalan sure...)
  Future<Result<MatchState>> fetchState(String matchId);

  /// SADECE kendi kartlarim. Rakibin eli hicbir uctan gelmez.
  Future<Result<List<HandCard>>> fetchHand(String matchId);

  /// Oynanan kartlarin gecmisi (iki taraf da gorebilir)
  Future<Result<MatchHistory>> fetchHistory(String matchId);

  /// Kart oyna. [userCardId] null verilirse PAS gecilir;
  /// sunucu "gercekten o pozisyonda kartin yok mu" diye dogrular.
  Future<Result<PlayCardResult>> playCard({
    required String matchId,
    String? userCardId,
  });

  /// Rakip AFK ise maci hukmen talep et
  Future<Result<Map<String, dynamic>>> claimTimeout(String matchId);

  /// Teslim ol (ceza uygulanir)
  Future<Result<Map<String, dynamic>>> surrender(String matchId);

  /// Bitmis macin ozeti: kaybedilen/kazanilan kartlar
  Future<Result<MatchResultSummary>> fetchResult(String matchId);
}
