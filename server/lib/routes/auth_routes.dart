import 'dart:convert';
import 'dart:math';

import 'package:shared_models/shared_models.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/auth_middleware.dart';
import '../auth/jwt_service.dart';
import '../auth/password_service.dart';
import '../auth/social_token_verifier.dart';
import '../config/env.dart';
import '../db/database.dart';
import '../utils/api_response.dart';
import '../utils/row_mappers.dart';

/// Kimlik dogrulama uc noktalari.
///
///   POST /api/auth/register  -> Kayit ol (+ baslangic paketi)
///   POST /api/auth/login     -> Giris yap
///   POST /api/auth/social    -> Google / Apple ile giris
///   POST /api/auth/refresh   -> Access token yenile
///   POST /api/auth/logout    -> Cikis yap (refresh token iptal)
///   GET  /api/auth/me        -> Kendi profilini getir  [jeton gerekli]
Router authRoutes(Database db, JwtService jwt, {SocialTokenVerifier? socialVerifier}) {
  final router = Router();
  final social = socialVerifier ?? SocialTokenVerifier.fromEnv();

  // ------------------------------------------------------------------
  // KAYIT
  // ------------------------------------------------------------------
  router.post('/register', (Request request) async {
    final body = await readJsonBody(request);

    final email = requireString(body, 'email', label: 'E-posta').toLowerCase();
    final password = requireString(body, 'password', label: 'Sifre');
    final username = requireString(body, 'username', label: 'Kullanici adi');

    // ---- Dogrulamalar (istemciye guvenme) ----
    if (!email.contains('@') || !email.contains('.')) {
      throw const ApiException('Gecerli bir e-posta adresi girin.');
    }
    if (password.length < 6) {
      throw const ApiException('Sifre en az 6 karakter olmali.');
    }
    if (username.length < 3 || username.length > 20) {
      throw const ApiException('Kullanici adi 3-20 karakter arasinda olmali.');
    }

    // ---- Cakisma kontrolu (kullaniciya net mesaj verebilmek icin) ----
    final mevcut = await db.queryOne(
      'select email, username from users where email = @email or username = @username limit 1',
      params: {'email': email, 'username': username},
    );

    if (mevcut != null) {
      if ((mevcut['email'] as String).toLowerCase() == email) {
        throw const ApiException('Bu e-posta adresi ile zaten bir hesap var.');
      }
      throw const ApiException('Bu kullanici adi alinmis. Baska bir tane deneyin.');
    }

    // ---- Kaydi olustur ----
    final hash = PasswordService.hash(password);

    final kullanici = await db.queryOne(
      '''
      insert into users (email, password_hash, username, protection_slots)
      values (@email, @hash, @username, base_protection_slots())
      returning id, email, username, coins, protection_slots, mmr,
                wins, losses, draws, avatar_url, created_at
      ''',
      params: {'email': email, 'hash': hash, 'username': username},
    );

    final userId = kullanici!['id'].toString();

    // ---- Baslangic paketini ver ----
    // Basarisiz olursa kayit yine de gecerlidir; oyuncu sonra tekrar ister.
    try {
      await db.scalar(
        'select grant_starter_pack(@id::uuid)',
        params: {'id': userId},
      );
    } catch (e) {
      // ignore: avoid_print
      print('[UYARI] Baslangic paketi verilemedi ($userId): $e');
    }

    final tokens = await _issueTokens(db, jwt, userId, kullanici['username'] as String);

    return jsonOk(
      AuthResponse(user: _publicUser(kullanici), tokens: tokens).toJson(),
      status: 201,
    );
  });

  // ------------------------------------------------------------------
  // GIRIS
  // ------------------------------------------------------------------
  router.post('/login', (Request request) async {
    final body = await readJsonBody(request);
    final email = requireString(body, 'email', label: 'E-posta').toLowerCase();
    final password = requireString(body, 'password', label: 'Sifre');

    final kullanici = await db.queryOne(
      '''
      select id, email, username, password_hash, coins, protection_slots, mmr,
             wins, losses, draws, avatar_url, is_banned, ban_reason, created_at
      from users where email = @email
      ''',
      params: {'email': email},
    );

    // GUVENLIK: "kullanici yok" ile "sifre yanlis" ayrimi YAPILMAZ.
    // Aksi halde saldirgan hangi e-postalarin kayitli oldugunu ogrenir.
    //
    // SURE DE AYNI OLMALI: kullanici yokken bcrypt hic calismazsa cevap
    // ~250 ms erken gelir ve e-postanin kayitli olmadigini ele verir.
    // Bu yuzden kullanici yokken de sahte bir ozete karsi dogrulama
    // yapiliyor.
    final ozet = kullanici == null
        ? PasswordService.dummyHash
        : kullanici['password_hash'] as String;
    final dogru = PasswordService.verify(password, ozet);
    if (kullanici == null || !dogru) {
      throw const ApiException('E-posta veya sifre hatali.', status: 401);
    }

    if (kullanici['is_banned'] == true) {
      throw ApiException(
        'Hesabiniz askiya alinmis. Sebep: ${kullanici['ban_reason'] ?? 'Belirtilmemis'}',
        status: 403,
      );
    }

    final userId = kullanici['id'].toString();

    await db.query(
      'update users set last_seen_at = now() where id = @id::uuid',
      params: {'id': userId},
    );

    final tokens = await _issueTokens(db, jwt, userId, kullanici['username'] as String);

    return jsonOk(
      AuthResponse(user: _publicUser(kullanici), tokens: tokens).toJson(),
    );
  });

  // ------------------------------------------------------------------
  // GOOGLE / APPLE ILE GIRIS
  // ------------------------------------------------------------------
  // Sira: bagli kimlik -> yeni hesap. Ayni e-postali hesap varsa KENDILIGINDEN
  // baglanmaz: kayitta e-posta sahipligi dogrulanmadigi icin baskasi o adresle
  // onceden hesap acmis olabilir. Oyuncu once kendi hesabina girer, sonra
  // Ayarlar'dan baglar (/me/social/link). Yeni oyuncu ad gondermediyse hesap
  // acilmaz, `needs_username` doner.
  router.post('/social', (Request request) async {
    final body = await readJsonBody(request);
    final provider = SocialProvider.fromName(requireString(body, 'provider', label: 'Saglayici'));
    if (provider == null) throw const ApiException('Gecersiz giris yontemi.');

    final nonce = body['nonce'];
    final kimlik = await social.verify(
      provider,
      requireString(body, 'id_token', label: 'Kimlik jetonu'),
      rawNonce: nonce is String ? nonce : null,
    );

    var kullanici = await db.queryOne(
      '''
      select u.id, u.email, u.username, u.coins, u.protection_slots, u.mmr,
             u.wins, u.losses, u.draws, u.avatar_url, u.is_banned, u.ban_reason, u.created_at
      from user_identities i
      join users u on u.id = i.user_id
      where i.provider = @provider and i.provider_subject = @subject
      ''',
      params: {'provider': provider.name, 'subject': kimlik.subject},
    );

    final email = kimlik.email;
    if (kullanici == null) {
      // Dogrulanmamis e-posta ile baskasinin hesabina girilemez, adres de kapatilamaz
      if (email == null || !kimlik.emailVerified) {
        throw const ApiException('Bu hesabin e-postasi dogrulanmamis. Baska bir yontemle giris yapin.', status: 403);
      }

      final ayniEposta = await db.queryOne(
        'select 1 as var from users where email = @email',
        params: {'email': email},
      );
      if (ayniEposta != null) {
        throw const ApiException(
          'Bu e-postayla kayıtlı bir hesap var. Önce e-posta ve şifrenle giriş yap, '
          'sonra Ayarlar\'dan bu hesabı bağla.',
          status: 409,
          code: 'social_link_required',
        );
      }
    }

    var yeniHesap = false;
    if (kullanici == null) {
      final hamAd = body['username'];
      final username = hamAd is String ? hamAd.trim() : '';
      if (username.isEmpty) return jsonOk({'needs_username': true});

      if (username.length < 3 || username.length > 20) {
        throw const ApiException('Kullanici adi 3-20 karakter arasinda olmali.');
      }
      final alinmis = await db.queryOne(
        'select 1 as var from users where username = @username limit 1',
        params: {'username': username},
      );
      if (alinmis != null) {
        throw const ApiException('Bu kullanici adi alinmis. Baska bir tane deneyin.');
      }

      // Kullanici ve kimlik tek ifadede yazilir: yarim kayit kalamaz
      kullanici = await db.queryOne(
        '''
        with yeni as (
          insert into users (email, password_hash, username, protection_slots)
          values (@email::text, @hash, @username, base_protection_slots())
          returning id, email, username, coins, protection_slots, mmr,
                    wins, losses, draws, avatar_url, is_banned, ban_reason, created_at
        ), kimlik as (
          insert into user_identities (user_id, provider, provider_subject, email)
          select id, @provider::text, @subject::text, @email::text from yeni
        )
        select * from yeni
        ''',
        params: {
          'email': email,
          'hash': PasswordService.hash(_unusablePassword()),
          'username': username,
          'provider': provider.name,
          'subject': kimlik.subject,
        },
      );
      yeniHesap = true;
      final yeniId = kullanici!['id'].toString();

      try {
        await db.scalar('select grant_starter_pack(@id::uuid)', params: {'id': yeniId});
      } catch (e) {
        // ignore: avoid_print
        print('[UYARI] Baslangic paketi verilemedi ($yeniId): $e');
      }
    }

    final oyuncu = kullanici;
    if (oyuncu['is_banned'] == true) {
      throw ApiException(
        'Hesabiniz askiya alinmis. Sebep: ${oyuncu['ban_reason'] ?? 'Belirtilmemis'}',
        status: 403,
      );
    }

    final userId = oyuncu['id'].toString();
    await db.query('update users set last_seen_at = now() where id = @id::uuid', params: {'id': userId});

    final tokens = await _issueTokens(db, jwt, userId, oyuncu['username'] as String);
    return jsonOk(
      AuthResponse(user: _publicUser(oyuncu), tokens: tokens).toJson(),
      status: yeniHesap ? 201 : 200,
    );
  });

  // ------------------------------------------------------------------
  // JETON YENILEME
  // ------------------------------------------------------------------
  router.post('/refresh', (Request request) async {
    final body = await readJsonBody(request);
    final refreshToken = requireString(body, 'refresh_token', label: 'Yenileme jetonu');

    final hash = jwt.hashRefreshToken(refreshToken);

    final kayit = await db.queryOne(
      '''
      select rt.id, rt.user_id, rt.expires_at, rt.revoked_at, u.username
      from refresh_tokens rt
      join users u on u.id = rt.user_id
      where rt.token_hash = @hash
      ''',
      params: {'hash': hash},
    );

    if (kayit == null || kayit['revoked_at'] != null) {
      throw const ApiException.unauthorized();
    }

    final expiresAt = kayit['expires_at'] as DateTime;
    if (expiresAt.isBefore(DateTime.now().toUtc())) {
      throw const ApiException(
        'Oturum suresi doldu. Lutfen tekrar giris yapin.',
        status: 401,
      );
    }

    // ROTASYON: Eski jetonu iptal edip yenisini veriyoruz.
    // Boylece calinan bir jeton en fazla bir kez kullanilabilir.
    await db.query(
      'update refresh_tokens set revoked_at = now() where id = @id::uuid',
      params: {'id': kayit['id'].toString()},
    );

    final tokens = await _issueTokens(
      db,
      jwt,
      kayit['user_id'].toString(),
      kayit['username'] as String,
    );

    return jsonOk({'tokens': tokens.toJson()});
  });

  // ------------------------------------------------------------------
  // CIKIS
  // ------------------------------------------------------------------
  router.post('/logout', (Request request) async {
    final body = await readJsonBody(request);
    final refreshToken = body['refresh_token'];

    if (refreshToken is String && refreshToken.isNotEmpty) {
      await db.query(
        'update refresh_tokens set revoked_at = now() where token_hash = @hash',
        params: {'hash': jwt.hashRefreshToken(refreshToken)},
      );
    }

    return jsonOk({'status': 'ok'});
  });

  return router;
}

/// Korumali profil uc noktasi (ayri router, requireAuth ile sarilir)
///
///   GET  /api/me              -> Profil + devam eden mac
///   GET  /api/me/social       -> Bagli Google/Apple hesaplari
///   POST /api/me/social/link  -> Giris yapmis oyuncu Google/Apple hesabini baglar
Router meRoutes(Database db, {SocialTokenVerifier? socialVerifier}) {
  final router = Router();
  final social = socialVerifier ?? SocialTokenVerifier.fromEnv();

  router.get('/social', (Request request) async {
    final userId = requireUserId(request);
    final satirlar = await db.query(
      'select provider from user_identities where user_id = @id::uuid order by provider',
      params: {'id': userId},
    );
    return jsonOk({'providers': [for (final r in satirlar) r['provider'].toString()]});
  });

  router.post('/social/link', (Request request) async {
    final userId = requireUserId(request);
    final body = await readJsonBody(request);
    final provider = SocialProvider.fromName(requireString(body, 'provider', label: 'Saglayici'));
    if (provider == null) throw const ApiException('Gecersiz giris yontemi.');
    final nonce = body['nonce'];
    final kimlik = await social.verify(
      provider,
      requireString(body, 'id_token', label: 'Kimlik jetonu'),
      rawNonce: nonce is String ? nonce : null,
    );

    final sahibi = await db.queryOne(
      'select user_id from user_identities where provider = @provider and provider_subject = @subject',
      params: {'provider': provider.name, 'subject': kimlik.subject},
    );
    if (sahibi != null) {
      if (sahibi['user_id'].toString() == userId) return jsonOk({'linked': provider.name});
      throw const ApiException('Bu hesap başka bir oyuncuya bağlı.', status: 409, code: 'social_already_linked');
    }
    final mevcut = await db.queryOne(
      'select 1 as var from user_identities where user_id = @id::uuid and provider = @provider',
      params: {'id': userId, 'provider': provider.name},
    );
    if (mevcut != null) {
      throw const ApiException('Hesabına zaten bu türde bir hesap bağlı.', status: 409, code: 'social_provider_taken');
    }
    await db.query(
      '''
      insert into user_identities (user_id, provider, provider_subject, email)
      values (@id::uuid, @provider, @subject, @email)
      ''',
      params: {'id': userId, 'provider': provider.name, 'subject': kimlik.subject, 'email': kimlik.email},
    );
    return jsonOk({'linked': provider.name}, status: 201);
  });

  router.get('/', (Request request) async {
    final userId = requireUserId(request);

    final kullanici = await db.queryOne(
      '''
      select id, email, username, coins, protection_slots, mmr,
             wins, losses, draws, avatar_url, created_at
      from users where id = @id::uuid
      ''',
      params: {'id': userId},
    );

    if (kullanici == null) throw const ApiException.notFound('Kullanici bulunamadi.');

    // Aktif mac var mi? (uygulama acilirken devam eden maca donebilsin)
    final aktifMac = await db.scalar(
      'select get_active_match_id(@id::uuid)',
      params: {'id': userId},
    );

    return jsonOk(
      MeResponse(
        user: _publicUser(kullanici),
        activeMatchId: aktifMac?.toString(),
      ).toJson(),
    );
  });

  return router;
}

// --------------------------------------------------------------------
// YARDIMCILAR
// --------------------------------------------------------------------

/// Veritabani satirini PAYLASILAN [UserModel]'e cevirir.
///
/// Hassas alanlar (password_hash) modelde HIC YOK; yanlislikla disari
/// sizmasi mumkun degil. Eskiden elle harita kuruyorduk ve bir alani
/// unutmak ya da yanlis adlandirmak mumkundu.
UserModel _publicUser(Map<String, dynamic> row) => RowMappers.user(row);

/// Sosyal hesaplarin sifresi yoktur: kimsenin bilmedigi rastgele bir deger ozetlenir.
String _unusablePassword() {
  final rastgele = Random.secure();
  return base64Url.encode(List<int>.generate(32, (_) => rastgele.nextInt(256)));
}

/// Access + refresh jeton cifti uretir, refresh'i veritabanina yazar.
Future<AuthTokens> _issueTokens(
  Database db,
  JwtService jwt,
  String userId,
  String username,
) async {
  final accessToken = jwt.createAccessToken(userId, username: username);
  final refreshToken = jwt.createRefreshToken();

  final now = DateTime.now().toUtc();
  final accessExpires = now.add(Duration(minutes: Env.accessTokenMinutes));
  final refreshExpires = now.add(Duration(days: Env.refreshTokenDays));

  await db.query(
    '''
    insert into refresh_tokens (user_id, token_hash, expires_at)
    values (@userId::uuid, @hash, @expires)
    ''',
    params: {
      'userId': userId,
      'hash': jwt.hashRefreshToken(refreshToken),
      'expires': refreshExpires,
    },
  );

  // Paylasilan model kullaniliyor: uygulama tarafi ayni sinifin
  // fromJson'u ile okuyacak.
  return AuthTokens(
    accessToken: accessToken,
    refreshToken: refreshToken,
    accessExpiresAt: accessExpires,
    refreshExpiresAt: refreshExpires,
  );
}
