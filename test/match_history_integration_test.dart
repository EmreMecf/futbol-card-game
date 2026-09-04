import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/auth/session_manager.dart';
import 'package:futbol_card/core/network/api_client.dart';
import 'package:futbol_card/core/storage/token_storage.dart';
import 'package:shared_models/shared_models.dart';
import 'package:futbol_card/features/match/data/datasources/match_remote_datasource.dart';
import 'package:futbol_card/features/match/data/repositories/match_repository_impl.dart';

/// CANLI BACKEND'E KARŞI: maç geçmişi zinciri.
///
/// Profil ekranında geçmiş listesi boş görünüyordu. Sunucu doğru
/// veriyi döndürüyor (tarayıcı ağ günlüğünde görüldü) ama liste
/// ekranda boştu. Bu test hatanın hangi katmanda olduğunu gösteriyor:
/// ham yanıt mı gelmiyor, ayrıştırma mı başarısız?
///
/// Sunucu kapalıysa testler ATLANIR.
void main() {
  late ApiClient api;

  setUpAll(() {
    dotenv.loadFromString(envString: '''
API_BASE_URL=http://localhost:8080
REQUEST_TIMEOUT_SECONDS=10
ENABLE_LOGGING=false
''');
  });

  setUp(() {
    final session = SessionManager(TokenStorage(_BellektekiDepo()));
    api = ApiClient(session);
  });

  Future<bool> sunucuAyaktaMi() async {
    try {
      await api.get('/health');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Test hesabıyla giriş yapıp jetonu oturuma koyar.
  Future<bool> girisYap(SessionManager oturum) async {
    try {
      final cevap = await api.post('/auth/login', govde: {
        'email': 'tasarim@test.local',
        'password': 'Test12345!',
      });
      final jetonlar = cevap['tokens'] as Map<String, dynamic>?;
      if (jetonlar == null) return false;
      await oturum.save(
        tokens: AuthTokens(
          accessToken: jetonlar['access_token'] as String,
          refreshToken: jetonlar['refresh_token'] as String,
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  test('ham yanıt matches anahtarını taşıyor', () async {
    if (!await sunucuAyaktaMi()) {
      markTestSkipped('Sunucu kapalı');
      return;
    }

    final oturum = SessionManager(TokenStorage(_BellektekiDepo()));
    final yerelApi = ApiClient(oturum);
    if (!await girisYap(oturum)) {
      markTestSkipped('Test hesabı yok');
      return;
    }

    final ham = await yerelApi.get('/match/history', sorgu: {
      'limit': '20',
      'offset': '0',
    });

    expect(ham.containsKey('matches'), isTrue,
        reason: 'Sunucu matches anahtarı döndürmeli. Gelen: ${ham.keys}');
    expect(ham['matches'], isA<List>());
  });

  test('repository ham yanıtı modele çeviriyor', () async {
    if (!await sunucuAyaktaMi()) {
      markTestSkipped('Sunucu kapalı');
      return;
    }

    final oturum = SessionManager(TokenStorage(_BellektekiDepo()));
    final yerelApi = ApiClient(oturum);
    final yerelRepo = MatchRepositoryImpl(MatchRemoteDataSource(yerelApi));

    if (!await girisYap(oturum)) {
      markTestSkipped('Test hesabı yok');
      return;
    }

    final sonuc = await yerelRepo.fetchMatchHistoryList(limit: 20);

    // Hata varsa mesajı göster: sessizce boş liste dönmesi
    // ekranda "hiç maçın yok" yazdırıyordu.
    expect(sonuc.errorOrNull?.message, isNull,
        reason: 'Ayrıştırma hata verdi');

    final liste = sonuc.dataOrNull;
    expect(liste, isNotNull);

    if (liste!.isEmpty) {
      markTestSkipped('Test hesabının bitmiş maçı yok');
      return;
    }

    final ilk = liste.first;
    expect(ilk.opponentUsername, isNotEmpty);
    expect(ilk.matchId, isNotEmpty);
    expect(ilk.finishedAt, isNotNull);
  });
}

/// Bellekte tutan sahte güvenli depo (platform kanalı yok)
class _BellektekiDepo implements FlutterSecureStorage {
  final Map<String, String> _veri = {};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _veri[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _veri.remove(key);
    } else {
      _veri[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _veri.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Bu test icin gerekmiyor');
}
