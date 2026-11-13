import 'dart:math';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shared_models/shared_models.dart';
import '../auth/jwt_service.dart';
import '../auth/password_service.dart';
import '../auth/social_token_verifier.dart';
import '../config/env.dart';
import '../db/database.dart';
import '../utils/api_response.dart';
import '../utils/row_mappers.dart';

/// Public OAuth exchange and authenticated account linking.
/// Provider identity is always matched on its signed sub, never on email.
Router socialAuthRoutes(Database db, JwtService jwt,
    {SocialTokenVerifier? verifier}) {
  final router = Router();
  final verify = verifier ?? SocialTokenVerifier();

  router.post('/social', (Request request) async {
    final body = await readJsonBody(request);
    final provider = requireString(body, 'provider');
    final token = requireString(body, 'id_token');
    final rawNonce = body['raw_nonce'] as String?;
    final VerifiedSocialIdentity identity;
    try {
      identity = await verify.verify(
          provider: provider, idToken: token, appleRawNonce: rawNonce);
    } on StateError {
      throw const ApiException('Sosyal giris henuz yapilandirilmadi.', status: 503);
    } catch (_) {
      throw const ApiException('Sosyal giris dogrulanamadi.', status: 401);
    }

    // All account creation and linking occurs in one transaction. No change
    // to existing users, match histories, player cards or reward ledger.
    late String userId;
    late String username;
    final random = Random.secure();
    await db.pool.runTx((tx) async {
      final linked = await tx.execute(Sql.named('''
        select u.id, u.username, u.is_banned
        from user_auth_providers p
        join users u on u.id = p.user_id
        where p.provider = @provider and p.provider_subject = @subject
        for update of u
      '''), parameters: {
        'provider': identity.provider, 'subject': identity.subject,
      });
      if (linked.isNotEmpty) {
        final u = linked.first.toColumnMap();
        if (u['is_banned'] == true) {
          throw const ApiException('Hesap askiya alinmis.', status: 403);
        }
        userId = u['id'].toString();
        username = u['username'] as String;
        return;
      }
      // Never silently claim a preexisting password account based on email.
      final email = identity.email;
      if (email != null) {
        final existing = await tx.execute(Sql.named(
          'select 1 from users where email = @email'
        ), parameters: {'email': email});
        if (existing.isNotEmpty) {
          throw const ApiException(
            'Bu e-posta zaten kayitli. E-postayla giris yapip hesabi baglayin.',
            status: 409,
          );
        }
      }
      final suffix = List<int>.generate(8, (_) => random.nextInt(16))
          .map((v) => v.toRadixString(16)).join();
      username = 'arena_$suffix';
      final newEmail = email ?? 'oauth_$suffix@unverified.invalid';
      final randomPassword = List<int>.generate(32, (_) => random.nextInt(256))
          .join(':');
      final result = await tx.execute(Sql.named('''
        insert into users(email, password_hash, username, protection_slots)
        values (@email, @hash, @username, base_protection_slots())
        returning id
      '''), parameters: {
        'email': newEmail, 'hash': PasswordService.hash(randomPassword),
        'username': username,
      });
      userId = result.first.toColumnMap()['id'].toString();
      await tx.execute(Sql.named('''
        insert into user_auth_providers(provider, provider_subject, user_id)
        values (@provider, @subject, @user_id::uuid)
      '''), parameters: {
        'provider': identity.provider, 'subject': identity.subject,
        'user_id': userId,
      });
      // Starter pack is transactional: no orphan player after a failure.
      await tx.execute(Sql.named('select grant_starter_pack(@uid::uuid)'),
          parameters: {'uid': userId});
    });

    final tokens = await _tokens(db, jwt, userId, username);
    final user = await db.queryOne('''
      select id, email, username, coins, protection_slots, mmr,
             wins, losses, draws, avatar_url, created_at
      from users where id = @id::uuid
    ''', params: {'id': userId});
    if (user == null) throw const ApiException('Hesap bulunamadi.', status: 500);
    return jsonOk(AuthResponse(
        user: RowMappers.user(user), tokens: tokens).toJson());
  });

  return router;
}

Future<AuthTokens> _tokens(Database db, JwtService jwt,
    String userId, String username) async {
  final access = jwt.createAccessToken(userId, username: username);
  final refresh = jwt.createRefreshToken();
  final now = DateTime.now().toUtc();
  final expires = now.add(Duration(days: Env.refreshTokenDays));
  await db.query('''
    insert into refresh_tokens(user_id, token_hash, expires_at)
    values (@id::uuid, @hash, @exp)
  ''', params: {
    'id': userId, 'hash': jwt.hashRefreshToken(refresh), 'exp': expires,
  });
  return AuthTokens(
    accessToken: access, refreshToken: refresh,
    accessExpiresAt: now.add(Duration(minutes: Env.accessTokenMinutes)),
    refreshExpiresAt: expires,
  );
}
