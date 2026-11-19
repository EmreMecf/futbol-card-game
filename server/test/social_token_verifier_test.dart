import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:futbol_card_server/auth/social_token_verifier.dart';
import 'package:futbol_card_server/utils/api_response.dart';
import 'package:pointycastle/export.dart' as pc;
import 'package:test/test.dart';

/// Google/Apple kimlik jetonu doğrulaması: her test jetonu gerçek RSA anahtarıyla imzalanır.
void main() {
  final simdi = DateTime.utc(2026, 11, 18, 12);
  final anahtar = _anahtarUret();
  final yabanci = _anahtarUret();
  var istekSayisi = 0;

  SocialTokenVerifier dogrulayici({Set<String>? google}) => SocialTokenVerifier(
    googleClientIds: google ?? {'google-istemci'},
    appleClientIds: {'com.futbolcard.futbolCard'},
    now: () => simdi,
    fetchKeys: (_) async {
      istekSayisi++;
      return {
        'keys': [_jwk(anahtar.publicKey as pc.RSAPublicKey, 'k1')],
      };
    },
  );

  Map<String, dynamic> googleIcerik([Map<String, dynamic> ek = const {}]) => {
    'iss': 'https://accounts.google.com',
    'aud': 'google-istemci',
    'sub': 'g-123',
    'email': 'Oyuncu@Test.com',
    'email_verified': true,
    'exp': simdi.add(const Duration(minutes: 30)).millisecondsSinceEpoch ~/ 1000,
    ...ek,
  };

  Matcher reddedilir(int status) =>
      throwsA(isA<ApiException>().having((e) => e.status, 'status', status));

  test('geçerli Google jetonu kimliği döndürür', () async {
    final k = await dogrulayici().verify(SocialProvider.google, _jwt(anahtar, googleIcerik()));
    expect(k.subject, 'g-123');
    expect(k.email, 'oyuncu@test.com');
    expect(k.emailVerified, isTrue);
  });

  test('başka anahtarla imzalanan jeton reddedilir', () {
    expect(dogrulayici().verify(SocialProvider.google, _jwt(yabanci, googleIcerik())), reddedilir(401));
  });

  test('içeriği değiştirilen jeton reddedilir', () {
    final p = _jwt(anahtar, googleIcerik()).split('.');
    p[1] = _b64(utf8.encode(jsonEncode(googleIcerik({'sub': 'kurban'}))));
    expect(dogrulayici().verify(SocialProvider.google, p.join('.')), reddedilir(401));
  });

  test('alg none reddedilir', () {
    final p = _jwt(anahtar, googleIcerik()).split('.');
    p[0] = _b64(utf8.encode(jsonEncode({'alg': 'none', 'kid': 'k1'})));
    expect(dogrulayici().verify(SocialProvider.google, p.join('.')), reddedilir(401));
  });

  test('başka uygulamaya verilmiş jeton reddedilir', () {
    final j = _jwt(anahtar, googleIcerik({'aud': 'baska-uygulama'}));
    expect(dogrulayici().verify(SocialProvider.google, j), reddedilir(401));
  });

  test('yanlış yayıncı reddedilir', () {
    final j = _jwt(anahtar, googleIcerik({'iss': 'https://sahte.example'}));
    expect(dogrulayici().verify(SocialProvider.google, j), reddedilir(401));
  });

  test('süresi dolmuş jeton reddedilir', () {
    final exp = simdi.subtract(const Duration(minutes: 5)).millisecondsSinceEpoch ~/ 1000;
    expect(dogrulayici().verify(SocialProvider.google, _jwt(anahtar, googleIcerik({'exp': exp}))), reddedilir(401));
  });

  test('bozuk jeton reddedilir', () {
    expect(dogrulayici().verify(SocialProvider.google, 'bozuk.jeton'), reddedilir(401));
    expect(dogrulayici().verify(SocialProvider.google, 'a.b.c'), reddedilir(401));
  });

  test('ayar yoksa giriş kapalıdır', () {
    expect(
      dogrulayici(google: {}).verify(SocialProvider.google, _jwt(anahtar, googleIcerik())),
      reddedilir(503),
    );
  });

  group('Apple', () {
    const ham = 'ham-nonce-degeri';
    Map<String, dynamic> icerik() => {
      'iss': 'https://appleid.apple.com',
      'aud': 'com.futbolcard.futbolCard',
      'sub': 'a-1',
      'email': 'gizli@privaterelay.appleid.com',
      'email_verified': 'true',
      'nonce': sha256.convert(utf8.encode(ham)).toString(),
      'exp': simdi.add(const Duration(minutes: 5)).millisecondsSinceEpoch ~/ 1000,
    };

    test('doğru nonce kabul edilir, metin email_verified okunur', () async {
      final k = await dogrulayici().verify(SocialProvider.apple, _jwt(anahtar, icerik()), rawNonce: ham);
      expect(k.subject, 'a-1');
      expect(k.emailVerified, isTrue);
    });

    test('nonce eksik ya da yanlışsa reddedilir', () {
      final j = _jwt(anahtar, icerik());
      expect(dogrulayici().verify(SocialProvider.apple, j), reddedilir(401));
      expect(dogrulayici().verify(SocialProvider.apple, j, rawNonce: 'baska'), reddedilir(401));
    });
  });

  test('anahtarlar önbellekten okunur', () async {
    final d = dogrulayici();
    istekSayisi = 0;
    await d.verify(SocialProvider.google, _jwt(anahtar, googleIcerik()));
    await d.verify(SocialProvider.google, _jwt(anahtar, googleIcerik()));
    expect(istekSayisi, 1);
  });
}

pc.AsymmetricKeyPair<pc.PublicKey, pc.PrivateKey> _anahtarUret() {
  final rastgele = Random.secure();
  final tohum = Uint8List.fromList(List.generate(32, (_) => rastgele.nextInt(256)));
  final uretec = pc.RSAKeyGenerator()
    ..init(
      pc.ParametersWithRandom(
        pc.RSAKeyGeneratorParameters(BigInt.from(65537), 2048, 64),
        pc.FortunaRandom()..seed(pc.KeyParameter(tohum)),
      ),
    );
  return uretec.generateKeyPair();
}

String _b64(List<int> b) => base64Url.encode(b).replaceAll('=', '');

Uint8List _bayt(BigInt n) {
  final hex = n.toRadixString(16);
  final cift = hex.length.isOdd ? '0$hex' : hex;
  return Uint8List.fromList([
    for (var i = 0; i < cift.length; i += 2) int.parse(cift.substring(i, i + 2), radix: 16),
  ]);
}

Map<String, dynamic> _jwk(pc.RSAPublicKey k, String kid) => {
  'kty': 'RSA',
  'kid': kid,
  'n': _b64(_bayt(k.modulus!)),
  'e': _b64(_bayt(k.exponent!)),
};

String _jwt(pc.AsymmetricKeyPair<pc.PublicKey, pc.PrivateKey> cift, Map<String, dynamic> icerik) {
  final govde =
      '${_b64(utf8.encode(jsonEncode({'alg': 'RS256', 'kid': 'k1'})))}.${_b64(utf8.encode(jsonEncode(icerik)))}';
  final imzaci = pc.RSASigner(pc.SHA256Digest(), '0609608648016503040201')
    ..init(true, pc.PrivateKeyParameter<pc.RSAPrivateKey>(cift.privateKey as pc.RSAPrivateKey));
  final imza = imzaci.generateSignature(Uint8List.fromList(utf8.encode(govde)));
  return '$govde.${_b64(imza.bytes)}';
}
