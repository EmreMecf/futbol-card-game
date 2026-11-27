import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:futbol_card_server/monetization/ad_ssv_verifier.dart';
import 'package:pointycastle/export.dart' as pc;
import 'package:test/test.dart';

/// AdMob SSV doğrulaması: test kendi P-256 anahtarını üretir, Google'ın
/// biçiminde (DER imza, base64url, imzalanan içerik = signature öncesi ham
/// sorgu) imzalar.
void main() {
  final egri = pc.ECCurve_secp256r1();
  final rnd = pc.FortunaRandom()
    ..seed(pc.KeyParameter(Uint8List.fromList(List.generate(32, (_) => Random.secure().nextInt(256)))));
  pc.AsymmetricKeyPair<pc.ECPublicKey, pc.ECPrivateKey> uret() {
    final g = pc.ECKeyGenerator()..init(pc.ParametersWithRandom(pc.ECKeyGeneratorParameters(egri), rnd));
    final p = g.generateKeyPair();
    return pc.AsymmetricKeyPair(p.publicKey, p.privateKey);
  }

  /// P-256 SPKI DER: sabit başlık + 65 baytlık nokta
  String spki(pc.ECPublicKey k) {
    const baslik = [
      0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01, //
      0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07, 0x03, 0x42, 0x00,
    ];
    return base64.encode([...baslik, ...k.Q!.getEncoded(false)]);
  }

  List<int> derInt(BigInt v) {
    var b = <int>[];
    var x = v;
    while (x > BigInt.zero) {
      b.insert(0, (x & BigInt.from(0xff)).toInt());
      x = x >> 8;
    }
    if (b.isEmpty) b = [0];
    if (b.first & 0x80 != 0) b.insert(0, 0);
    return [0x02, b.length, ...b];
  }

  String imzala(pc.ECPrivateKey k, String icerik) {
    final s = pc.ECDSASigner(pc.SHA256Digest())
      ..init(true, pc.ParametersWithRandom(pc.PrivateKeyParameter<pc.ECPrivateKey>(k), rnd));
    final sig = s.generateSignature(Uint8List.fromList(utf8.encode(icerik))) as pc.ECSignature;
    final govde = [...derInt(sig.r), ...derInt(sig.s)];
    return base64Url.encode([0x30, govde.length, ...govde]).replaceAll('=', '');
  }

  late pc.AsymmetricKeyPair<pc.ECPublicKey, pc.ECPrivateKey> anahtar;
  late AdSsvVerifier dogrulayici;
  var indirme = 0;

  setUp(() {
    anahtar = uret();
    indirme = 0;
    final json = jsonEncode({
      'keys': [
        {'keyId': 3335741209, 'base64': spki(anahtar.publicKey)},
      ],
    });
    dogrulayici = AdSsvVerifier(AdMobKeyStore(fetch: () async {
      indirme++;
      return json;
    }));
  });

  String sorgu({String tx = 'tx123', String custom = '6f1c2e8a-0000-4000-8000-000000000001', String amount = '1'}) {
    final icerik = 'ad_network=5450213213286189855&ad_unit=1234567890&custom_data=$custom'
        '&reward_amount=$amount&reward_item=odul&timestamp=1507770365237823'
        '&transaction_id=$tx&user_id=oyuncu-1';
    return '$icerik&signature=${imzala(anahtar.privateKey, icerik)}&key_id=3335741209';
  }

  test('geçerli imza kabul edilir, alanlar okunur', () async {
    final r = await dogrulayici.verify(sorgu());
    expect(r.valid, isTrue, reason: r.reason);
    expect(r.transactionId, 'tx123');
    expect(r.userId, 'oyuncu-1');
    expect(r.customData, '6f1c2e8a-0000-4000-8000-000000000001');
    expect(r.rewardAmount, 1);
    expect(r.keyId, 3335741209);
  });

  test('ödül miktarı / kullanıcı değiştirilirse imza tutmaz', () async {
    final q = sorgu();
    expect((await dogrulayici.verify(q.replaceFirst('reward_amount=1', 'reward_amount=9'))).reason, 'bad_signature');
    expect((await dogrulayici.verify(q.replaceFirst('user_id=oyuncu-1', 'user_id=oyuncu-2'))).reason, 'bad_signature');
  });

  test('imzasız, bilinmeyen anahtar, bozuk imza reddedilir', () async {
    expect((await dogrulayici.verify('transaction_id=1&user_id=x')).reason, 'signature_missing');
    expect((await dogrulayici.verify(sorgu().replaceFirst('key_id=3335741209', 'key_id=42'))).reason, 'unknown_key');
    expect((await dogrulayici.verify('${sorgu().split('&signature=').first}&signature=!!&key_id=3335741209')).valid,
        isFalse);
  });

  test('başka anahtarla imzalanmış istek reddedilir', () async {
    final sahte = uret();
    const icerik = 'custom_data=x&transaction_id=tx9&user_id=u';
    final q = '$icerik&signature=${imzala(sahte.privateKey, icerik)}&key_id=3335741209';
    expect((await dogrulayici.verify(q)).reason, 'bad_signature');
  });

  test('anahtarlar önbellekte tutulur (her istekte indirilmez)', () async {
    await dogrulayici.verify(sorgu());
    await dogrulayici.verify(sorgu(tx: 'tx2'));
    await dogrulayici.verify(sorgu(tx: 'tx3'));
    expect(indirme, 1);
  });

  test('Google anahtar dosyası biçimi (pem) okunur', () {
    final pem = '-----BEGIN PUBLIC KEY-----\n${spki(anahtar.publicKey)}\n-----END PUBLIC KEY-----';
    final k = AdMobKeyStore.parseKeys(jsonEncode({
      'keys': [
        {'keyId': 7, 'pem': pem},
      ],
    }));
    expect(k[7]?.Q, anahtar.publicKey.Q);
  });
}
