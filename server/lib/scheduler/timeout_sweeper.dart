import 'dart:async';

import '../config/env.dart';
import '../db/database.dart';

/// Suresi dolmus maclari otomatik kapatan zamanlayici.
///
/// NEDEN GEREKLI?
/// Normalde bekleyen oyuncunun uygulamasi "rakibin suresi doldu" der ve
/// maci talep eder. Ama IKI oyuncunun da baglantisi koparsa bunu kimse
/// yapmaz; mac sonsuza kadar "aktif" kalir ve 22 kart kilitli kalirdi.
/// Bu zamanlayici o durumu engeller.
///
/// (Supabase'de bu isi pg_cron yapiyordu. Kendi sunucumuzda ayri bir
/// veritabani eklentisine gerek yok.)
class TimeoutSweeper {
  final Database _db;
  Timer? _macTimer;
  Timer? _tokenTimer;

  TimeoutSweeper(this._db);

  void start() {
    // ---- Suresi dolmus maclar ----
    _macTimer = Timer.periodic(
      Duration(seconds: Env.sweepIntervalSeconds),
      (_) => _sweepMatches(),
    );

    // ---- Eski refresh token'lar (saatte bir) ----
    _tokenTimer = Timer.periodic(
      const Duration(hours: 1),
      (_) => _cleanupTokens(),
    );

    // ignore: avoid_print
    print('[ZAMANLAYICI] Her ${Env.sweepIntervalSeconds} saniyede bir mac taramasi yapilacak.');
  }

  Future<void> _sweepMatches() async {
    try {
      final sayi = await _db.scalar('select sweep_timed_out_matches()');
      if (sayi is int && sayi > 0) {
        // ignore: avoid_print
        print('[ZAMANLAYICI] $sayi mac sure asimindan hukmen sonuclandirildi.');
      }
    } catch (e) {
      // ignore: avoid_print
      print('[ZAMANLAYICI] Mac taramasi basarisiz: $e');
    }
  }

  Future<void> _cleanupTokens() async {
    try {
      await _db.scalar('select cleanup_expired_tokens()');
    } catch (e) {
      // ignore: avoid_print
      print('[ZAMANLAYICI] Jeton temizligi basarisiz: $e');
    }
  }

  void stop() {
    _macTimer?.cancel();
    _tokenTimer?.cancel();
  }
}
