import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:pointycastle/export.dart' as pc;

/// AdMob ödüllü reklam SUNUCU TARAFI DOĞRULAMA (SSV).
///
/// Google, reklam tamamlanınca bizim ucumuza imzalı bir GET isteği atar:
///   ...?ad_network=..&ad_unit=..&custom_data=..&reward_amount=..&reward_item=..
///      &timestamp=..&transaction_id=..&user_id=..&signature=..&key_id=..
/// İmza ECDSA P-256 / SHA-256, DER kodlu, base64url. İmzalanan içerik
/// sorgu dizgisinin "signature" parametresinden ÖNCEKİ kısmıdır (ham, URL
/// kodlaması bozulmadan). Açık anahtarlar
/// https://www.gstatic.com/admob/reward/verifier-keys.json adresinde;
/// en fazla 24 saat önbellekte tutulur, bilinmeyen key_id gelirse bir kez
/// yeniden indirilir.
///
/// İstemcinin "ödül kazandım" bildirimi ödül vermez; yalnız bu doğrulamadan
/// geçen geri çağrı veritabanında ödüle dönüşür.
class AdSsvVerifier {
  final AdMobKeyStore keys;
  AdSsvVerifier(this.keys);

  /// [rawQuery]: isteğin HAM sorgu dizgisi (`request.url.query`).
  Future<SsvResult> verify(String rawQuery) async {
    final i = rawQuery.indexOf('&signature=');
    if (i <= 0) return const SsvResult.invalid('signature_missing');
    final icerik = rawQuery.substring(0, i);
    final params = Uri.splitQueryString(rawQuery);
    final imza = params['signature'];
    final keyId = int.tryParse(params['key_id'] ?? '');
    if (imza == null || imza.isEmpty || keyId == null) return const SsvResult.invalid('signature_missing');

    var anahtar = await keys.keyFor(keyId);
    anahtar ??= await keys.keyFor(keyId, forceRefresh: true);
    if (anahtar == null) return SsvResult.invalid('unknown_key', keyId: keyId);

    final pc.ECSignature? sig;
    try {
      sig = _derSignature(base64Url.decode(base64Url.normalize(imza)));
    } catch (_) {
      return SsvResult.invalid('bad_signature_format', keyId: keyId);
    }
    if (sig == null) return SsvResult.invalid('bad_signature_format', keyId: keyId);

    final dogrulayici = pc.ECDSASigner(pc.SHA256Digest())..init(false, pc.PublicKeyParameter<pc.ECPublicKey>(anahtar));
    final gecerli = dogrulayici.verifySignature(Uint8List.fromList(utf8.encode(icerik)), sig);
    if (!gecerli) return SsvResult.invalid('bad_signature', keyId: keyId);

    return SsvResult(
      valid: true,
      keyId: keyId,
      transactionId: params['transaction_id'],
      userId: params['user_id'],
      customData: params['custom_data'],
      rewardAmount: int.tryParse(params['reward_amount'] ?? ''),
      adUnit: params['ad_unit'],
    );
  }

  /// DER: SEQUENCE { INTEGER r, INTEGER s }
  static pc.ECSignature? _derSignature(List<int> b) {
    var i = 0;
    int uzunluk() {
      var n = b[i++];
      if (n & 0x80 != 0) {
        final adet = n & 0x7f;
        n = 0;
        for (var k = 0; k < adet; k++) {
          n = (n << 8) | b[i++];
        }
      }
      return n;
    }

    BigInt tamsayi() {
      if (b[i++] != 0x02) throw const FormatException('INTEGER bekleniyor');
      final n = uzunluk();
      final v = b.sublist(i, i + n);
      i += n;
      return v.fold<BigInt>(BigInt.zero, (a, x) => (a << 8) | BigInt.from(x));
    }

    if (b.isEmpty || b[i++] != 0x30) return null;
    uzunluk();
    final r = tamsayi();
    final s = tamsayi();
    return pc.ECSignature(r, s);
  }
}

class SsvResult {
  final bool valid;
  final String? reason;
  final int? keyId;
  final String? transactionId;
  final String? userId;
  final String? customData;
  final int? rewardAmount;
  final String? adUnit;

  const SsvResult({
    required this.valid,
    this.reason,
    this.keyId,
    this.transactionId,
    this.userId,
    this.customData,
    this.rewardAmount,
    this.adUnit,
  });

  const SsvResult.invalid(this.reason, {this.keyId})
    : valid = false,
      transactionId = null,
      userId = null,
      customData = null,
      rewardAmount = null,
      adUnit = null;
}

/// Google'ın SSV açık anahtarları (en fazla 24 saat önbellek).
class AdMobKeyStore {
  static const defaultUrl = 'https://www.gstatic.com/admob/reward/verifier-keys.json';

  /// Anahtar JSON'unu getirir (testte sahte kaynak verilir)
  final Future<String> Function() fetch;
  final Duration maxAge;
  final DateTime Function() now;

  AdMobKeyStore({Future<String> Function()? fetch, this.maxAge = const Duration(hours: 24), DateTime Function()? now})
    : fetch = fetch ?? (() => httpGet(defaultUrl)),
      now = now ?? DateTime.now;

  Map<int, pc.ECPublicKey> _anahtarlar = const {};
  DateTime? _alindi;
  DateTime? _sonZorla;

  Future<pc.ECPublicKey?> keyFor(int keyId, {bool forceRefresh = false}) async {
    final eski = _alindi == null || now().difference(_alindi!) > maxAge;
    // Bilinmeyen anahtarla zorla yenileme dakikada en fazla bir kez
    final zorla = forceRefresh && (_sonZorla == null || now().difference(_sonZorla!) > const Duration(minutes: 1));
    if (eski || zorla) {
      if (zorla) _sonZorla = now();
      try {
        _anahtarlar = parseKeys(await fetch());
        _alindi = now();
      } catch (_) {
        // İndirilemedi: eldeki anahtarlarla devam (yoksa doğrulama başarısız)
      }
    }
    return _anahtarlar[keyId];
  }

  /// {"keys":[{"keyId":3335741209,"pem":"...","base64":"MFkw..."}]}
  static Map<int, pc.ECPublicKey> parseKeys(String json) {
    final m = jsonDecode(json) as Map<String, dynamic>;
    final sonuc = <int, pc.ECPublicKey>{};
    for (final k in (m['keys'] as List? ?? const [])) {
      final id = (k['keyId'] as num?)?.toInt();
      final b64 = (k['base64'] as String?) ?? _pemGovde(k['pem'] as String?);
      if (id == null || b64 == null) continue;
      final anahtar = publicKeyFromSpki(base64.decode(b64));
      if (anahtar != null) sonuc[id] = anahtar;
    }
    return sonuc;
  }

  static String? _pemGovde(String? pem) =>
      pem?.replaceAll(RegExp(r'-----[A-Z ]+-----'), '').replaceAll(RegExp(r'\s'), '');

  /// P-256 SubjectPublicKeyInfo (DER) → açık anahtar. Nokta, BIT STRING'in
  /// sonundaki 65 bayttır (0x04 || X || Y).
  static pc.ECPublicKey? publicKeyFromSpki(List<int> der) {
    if (der.length < 65) return null;
    final nokta = Uint8List.fromList(der.sublist(der.length - 65));
    if (nokta[0] != 0x04) return null;
    final egri = pc.ECCurve_secp256r1();
    final q = egri.curve.decodePoint(nokta);
    if (q == null) return null;
    return pc.ECPublicKey(q, egri);
  }

  static Future<String> httpGet(String url) async {
    final c = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final r = await (await c.getUrl(Uri.parse(url))).close();
      if (r.statusCode != 200) throw HttpException('SSV anahtarlari alinamadi: ${r.statusCode}');
      return await r.transform(utf8.decoder).join();
    } finally {
      c.close();
    }
  }
}
