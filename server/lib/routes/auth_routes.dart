import 'package:shared_models/shared_models.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/auth_middleware.dart';
import '../auth/jwt_service.dart';
import '../auth/password_service.dart';
import '../config/env.dart';
import '../db/database.dart';
import '../utils/api_response.dart';
import '../utils/row_mappers.dart';

/// Kimlik dogrulama uc noktalari.
///
///   POST /api/auth/register  -> Kayit ol (+ baslangic paketi)
///   POST /api/auth/login     -> Giris yap
///   POST /api/auth/refresh   -> Access token yenile
///   POST /api/auth/logout    -> Cikis yap (refresh token iptal)
///   GET  /api/auth/me        -> Kendi profilini getir  [jeton gerekli]
Router authRoutes(Database db, JwtService jwt) {
  final router = Router();

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
    if (kullanici == null ||
        !PasswordService.verify(password, kullanici['password_hash'] as String)) {
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
Router meRoutes(Database db) {
  final router = Router();

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
