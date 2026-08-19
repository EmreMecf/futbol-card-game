import 'dart:math';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/auth/session_manager.dart';
import 'package:futbol_card/core/error/app_exception.dart';
import 'package:futbol_card/core/network/api_client.dart';
import 'package:futbol_card/core/storage/token_storage.dart';
import 'package:futbol_card/core/utils/result.dart';
import 'package:shared_models/shared_models.dart';
import 'package:futbol_card/features/auth/data/datasources/auth_remote_datasource.dart';

/// CANLI BACKEND'E KARSI ENTEGRASYON TESTI
///
/// Bu test uygulamanin GERCEK ag katmanini (ApiClient, SessionManager,
/// AuthRemoteDataSource) calisan sunucuya karsi dogrular.
///
/// CALISTIRMADAN ONCE:
///   1. .\scripts\veritabani-baslat.ps1
///   2. .\scripts\sunucu-baslat.ps1
///
/// Sonra:
///   flutter test test/api_integration_test.dart
///
/// Sunucu kapaliysa testler ATLANIR (basarisiz olmaz).
void main() {
  late SessionManager session;
  late ApiClient api;
  late AuthRemoteDataSource datasource;
  late String kullaniciAdi;

  setUpAll(() {
    // .env yerine test ayarlarini yukle (emulator adresi degil, localhost)
    dotenv.loadFromString(envString: '''
API_BASE_URL=http://localhost:8080
REQUEST_TIMEOUT_SECONDS=10
ENABLE_LOGGING=false
''');
  });

  setUp(() {
    session = SessionManager(_BellektekiDepo());
    api = ApiClient(session);
    datasource = AuthRemoteDataSource(api);

    final rastgele = Random().nextInt(999999).toString().padLeft(6, '0');
    kullaniciAdi = 'test_$rastgele';
  });

  /// Sunucu ayakta mi? Degilse testleri atla.
  Future<bool> sunucuAyaktaMi() async {
    try {
      await api.get('/health');
      return true;
    } catch (_) {
      return false;
    }
  }

  test('sunucu saglik kontrolu', () async {
    if (!await sunucuAyaktaMi()) {
      markTestSkipped('Backend calismiyor, test atlandi.');
      return;
    }

    final cevap = await api.get('/health');
    expect(cevap['status'], 'ok');
    expect(cevap['database'], 'connected');
  });

  test('kayit ol -> jetonlar oturuma yazilir', () async {
    if (!await sunucuAyaktaMi()) {
      markTestSkipped('Backend calismiyor.');
      return;
    }

    expect(session.isSignedIn, isFalse);

    final cevap = await datasource.signUp(
      email: '$kullaniciAdi@test.com',
      password: 'sifre123',
      username: kullaniciAdi,
    );

    // Sunucunun gonderdigi JSON'u PAYLASILAN modelle okuyoruz.
    // Alan adlari uyusmasaydi burada hata alirdik.
    final auth = AuthResponse.fromJson(cevap);

    await session.save(tokens: auth.tokens, user: auth.user);

    expect(session.isSignedIn, isTrue);
    expect(session.username, kullaniciAdi);
    // Yeni oyuncunun koruma hakki 3 ile baslar
    expect(session.protectionSlots, 3);
  });

  test('baslangic paketi 15 kart, Diamond/Legend YOK, kadro gecerli', () async {
    if (!await sunucuAyaktaMi()) {
      markTestSkipped('Backend calismiyor.');
      return;
    }

    await _kayitOl(datasource, session, kullaniciAdi);

    final envanter = await api.get('/game/inventory');
    final kartlar = (envanter['cards'] as List)
        .map((k) => InventoryCard.fromJson(k as Map<String, dynamic>))
        .toList();

    // KURAL: Baslangic paketi tam 15 kart verir
    expect(kartlar.length, 15);

    // KURAL: Baslangic paketinden Diamond ve Legend KESINLIKLE cikmaz
    final yasakli = kartlar.where(
      (k) => k.tier == CardTier.diamond || k.tier == CardTier.legend,
    );
    expect(yasakli, isEmpty,
        reason: 'Baslangic paketinden Diamond/Legend cikmamali');

    // KURAL: Zorunlu formasyonu kurmaya yetecek pozisyon dagilimi
    for (final pozisyon in CardPosition.values) {
      final adet = kartlar.where((k) => k.position == pozisyon).length;
      expect(adet, greaterThanOrEqualTo(pozisyon.requiredCount),
          reason: '${pozisyon.label} sayisi kadro kurmaya yetmiyor');
    }

    final desteler = await api.get('/game/decks');
    final deste = (desteler['decks'] as List).first as Map<String, dynamic>;
    expect(deste['card_count'], 11);
    expect(deste['is_active'], isTrue);

    final dogrulama = await api.get('/game/decks/${deste['id']}/validate');
    expect(dogrulama['is_valid'], isTrue,
        reason: 'Baslangic kadrosu 4-4-2 kuralina uymali');
  });

  test('jetonsuz istek 401 doner ve Turkce mesaj verir', () async {
    if (!await sunucuAyaktaMi()) {
      markTestSkipped('Backend calismiyor.');
      return;
    }

    // Oturum yok -> yetkisiz
    final sonuc = await Result.guard(() => api.get('/game/inventory'));

    expect(sonuc.isFailure, isTrue);
    final hata = sonuc.errorOrNull!;
    expect(hata.type, AppErrorType.unauthorized);
    expect(hata.message, isNotEmpty);
    // Mesaj Turkce olmali (backend'den geliyor)
    expect(hata.message, contains('giris'));
  });

  test('suresi dolmus access token OTOMATIK yenilenir', () async {
    if (!await sunucuAyaktaMi()) {
      markTestSkipped('Backend calismiyor.');
      return;
    }

    await _kayitOl(datasource, session, kullaniciAdi);
    final gecerliRefresh = session.refreshToken;

    // Access token'i kasitli olarak bozuyoruz; refresh token saglam kaliyor.
    // ApiClient 401 alinca sessizce yenileyip istegi tekrar gondermeli.
    await session.updateTokens(AuthTokens(
      accessToken: 'bozuk.jeton.degeri',
      refreshToken: gecerliRefresh!,
    ));

    final cevap = await api.get('/me');

    expect(cevap['user'], isNotNull);
    expect((cevap['user'] as Map)['username'], kullaniciAdi);
    expect(session.accessToken, isNot('bozuk.jeton.degeri'),
        reason: 'Jeton yenilenmis olmali');
  });

  test('oyun kurali hatasi Turkce mesajla gelir', () async {
    if (!await sunucuAyaktaMi()) {
      markTestSkipped('Backend calismiyor.');
      return;
    }

    await _kayitOl(datasource, session, kullaniciAdi);

    // Ayni kullanici baslangic paketini ikinci kez isteyemez
    final sonuc = await Result.guard(() => api.post('/game/starter-pack'));

    expect(sonuc.isFailure, isTrue);
    final hata = sonuc.errorOrNull!;
    expect(hata.type, AppErrorType.gameRule);
    expect(hata.message, contains('zaten'));
  });

  test('mac arama kuyruga alir', () async {
    if (!await sunucuAyaktaMi()) {
      markTestSkipped('Backend calismiyor.');
      return;
    }

    await _kayitOl(datasource, session, kullaniciAdi);

    final desteler = await api.get('/game/decks');
    final desteId = ((desteler['decks'] as List).first as Map)['id'];

    final sonuc = await api.post('/match/find', govde: {'deck_id': desteId});

    // Kuyrukta bekleyen baska oyuncu varsa 'matched' de olabilir
    expect(sonuc['status'], anyOf('queued', 'matched'));

    // Temizlik: kuyruktan cik
    await api.post('/match/cancel');
  });
}

// --------------------------------------------------------------------
// YARDIMCILAR
// --------------------------------------------------------------------

Future<void> _kayitOl(
  AuthRemoteDataSource datasource,
  SessionManager session,
  String kullaniciAdi,
) async {
  final cevap = await datasource.signUp(
    email: '$kullaniciAdi@test.com',
    password: 'sifre123',
    username: kullaniciAdi,
  );

  final auth = AuthResponse.fromJson(cevap);
  await session.save(tokens: auth.tokens, user: auth.user);
}

/// Testlerde gercek guvenli depo yerine bellekte tutan sahte surum.
///
/// flutter_secure_storage bir eklenti (plugin) oldugu icin test
/// ortaminda calismaz; isletim sisteminin Keychain/KeyStore'una
/// erisemez. Bu sinif onun yerini alir.
class _BellektekiDepo extends TokenStorage {
  final Map<String, String> _veri = {};

  @override
  Future<String?> readAccessToken() async => _veri['access'];

  @override
  Future<String?> readRefreshToken() async => _veri['refresh'];

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _veri['access'] = accessToken;
    _veri['refresh'] = refreshToken;
  }

  @override
  Future<void> saveUser(Map<String, dynamic> user) async {}

  @override
  Future<Map<String, dynamic>?> readUser() async => null;

  @override
  Future<void> clear() async => _veri.clear();
}
