import 'package:test/test.dart';
import 'package:futbol_card_server/auth/social_token_verifier.dart';

void main() {
  test('unknown provider rejected before network or database access', () async {
    final verifier = SocialTokenVerifier(environment: {
      'GOOGLE_WEB_CLIENT_ID': 'test.apps.googleusercontent.com',
      'APPLE_BUNDLE_ID': 'com.test.app',
    });
    await expectLater(
      verifier.verify(provider: 'other', idToken: 'a.b.c'),
      throwsFormatException,
    );
  });

  test('social login is fail-closed without OAuth client configuration', () async {
    final verifier = SocialTokenVerifier(environment: const {});
    await expectLater(
      verifier.verify(provider: 'google', idToken: 'a.b.c'),
      throwsStateError,
    );
  });

  test('unsigned google identity cannot pass verification', () async {
    final verifier = SocialTokenVerifier(environment: {
      'GOOGLE_WEB_CLIENT_ID': 'test.apps.googleusercontent.com',
    });
    await expectLater(
      verifier.verify(provider: 'google', idToken: 'eyJhbGciOiJub25lIn0.e30.sig'),
      throwsFormatException,
    );
  });

  test('apple must be configured and never falls back to Google audience', () async {
    final verifier = SocialTokenVerifier(environment: {
      'GOOGLE_WEB_CLIENT_ID': 'test.apps.googleusercontent.com',
    });
    await expectLater(
      verifier.verify(provider: 'apple', idToken: 'a.b.c', appleRawNonce: 'test'),
      throwsStateError,
    );
  });
}
