import 'dart:convert';
import 'dart:io';

import 'package:shared_models/shared_models.dart';

import 'catalog_slot.dart';

/// Yapay zekâdan istenen alanlar. OYUN DEĞERİ YOK.
///
/// Güç, seviye ve özellikler bu şemada bilinçli olarak yok: model onları
/// üretmeye zorlanmaz; üretse bile doğrulayıcı reddeder.
const kIdentityFields = <String>[
  'given_name',
  'family_name',
  'secondary_position',
  'playstyle',
  'personality',
  'bio_short',
  'bio_long',
  'appearance',
  'visual_prompt',
  'animation_profile',
];

Map<String, dynamic> identitySchema(CardPosition position) => {
      'type': 'object',
      'additionalProperties': false,
      'required': kIdentityFields,
      'properties': {
        'given_name': {'type': 'string', 'description': 'Özgün ad, 2-20 harf'},
        'family_name': {'type': 'string', 'description': 'Özgün soyad, 2-24 harf'},
        'secondary_position': {
          'type': ['string', 'null'],
          'enum': [
            for (final p in CardPosition.values)
              if (p != position) p.code,
            null,
          ],
        },
        'playstyle': {
          'type': 'string',
          'enum': [for (final s in Playstyle.forPosition(position)) s.code],
        },
        'personality': {
          'type': 'array',
          'items': {'type': 'string'},
          'description': '2-5 kısa kişilik özelliği (Türkçe)',
        },
        'bio_short': {'type': 'string', 'description': '20-160 karakter'},
        'bio_long': {'type': 'string', 'description': '80-1200 karakter'},
        'appearance': {
          'type': 'object',
          'additionalProperties': false,
          'required': ['skin_tone', 'hair', 'face', 'build', 'accessory', 'shirt_number'],
          'properties': {
            'skin_tone': {'type': 'string'},
            'hair': {'type': 'string'},
            'face': {'type': 'string'},
            'build': {'type': 'string'},
            'accessory': {'type': 'string'},
            'shirt_number': {'type': 'integer'},
          },
        },
        'visual_prompt': {
          'type': 'string',
          'description': 'Stilize 3B karakter görsel üretim tanımı (İngilizce), 40-1500 karakter',
        },
        'animation_profile': {
          'type': 'string',
          'enum': ['sakin', 'dengeli', 'gosterisci', 'lider'],
        },
      },
    };

/// Sistem istemi: kurallar burada, değişken bilgiler kullanıcı mesajında
/// (önbelleğe uygun sabit önek).
const kSystemPrompt = '''
Futbol Card Arena adlı mobil kart oyunu için TAMAMEN ÖZGÜN, kurgusal futbolcu karakterleri tasarlıyorsun.

Kesin kurallar:
- Gerçek bir futbolcuya, ünlüye ya da yaşayan/ölmüş tanınmış bir kişiye benzeyen ad, görünüş veya hikâye ÜRETME.
- Gerçek kulüp, lig, turnuva, federasyon veya spor markası adı KULLANMA. Sadece verilen kurgu bölge ve kulübü kullan.
- Güç, reyting, seviye ya da sayısal özellik değeri ÜRETME; bunları oyunun denge motoru belirler.
- Ad ve soyad kurgu bölgenin kültürüne uygun, telaffuzu kolay, akılda kalıcı olsun.
- Görünüş tanımı ayırt edilebilir bir yüz, saç ve vücut yapısı içersin; stil: kaliteli mobil oyun estetiğinde stilize 3B karakter.
- Hikâye ve kişilik Türkçe, görsel üretim tanımı İngilizce olsun.
''';

/// Claude'a giden ağ katmanı (test için değiştirilebilir)
abstract class ClaudeTransport {
  Future<Map<String, dynamic>> send(Map<String, dynamic> body, Map<String, String> headers);
}

/// Gerçek API: https://api.anthropic.com/v1/messages (dart:io, ek bağımlılık yok)
class HttpClaudeTransport implements ClaudeTransport {
  final String apiKey;
  final Uri endpoint;

  HttpClaudeTransport(this.apiKey, {Uri? endpoint})
      : endpoint = endpoint ?? Uri.parse('https://api.anthropic.com/v1/messages');

  /// Anahtar YALNIZCA ortam değişkeninden okunur; diske yazılmaz.
  static HttpClaudeTransport? fromEnvironment() {
    final k = Platform.environment['ANTHROPIC_API_KEY'];
    return (k == null || k.isEmpty) ? null : HttpClaudeTransport(k);
  }

  @override
  Future<Map<String, dynamic>> send(
      Map<String, dynamic> body, Map<String, String> headers) async {
    final client = HttpClient();
    try {
      final req = await client.postUrl(endpoint);
      req.headers
        ..set('content-type', 'application/json')
        ..set('x-api-key', apiKey);
      headers.forEach(req.headers.set);
      req.add(utf8.encode(jsonEncode(body)));
      final res = await req.close();
      final metin = await res.transform(utf8.decoder).join();
      final json = jsonDecode(metin) as Map<String, dynamic>;
      if (res.statusCode >= 400) {
        // Anahtar hata metnine ASLA eklenmez
        throw ClaudeApiException(res.statusCode,
            (json['error'] as Map?)?['message']?.toString() ?? 'bilinmeyen hata');
      }
      return json;
    } finally {
      client.close();
    }
  }
}

class ClaudeApiException implements Exception {
  final int status;
  final String message;
  ClaudeApiException(this.status, this.message);
  @override
  String toString() => 'Claude API hatası ($status): $message';
}

/// Model güvenlik nedeniyle reddettiyse (stop_reason: refusal)
class GenerationRefused implements Exception {
  final String? category;
  GenerationRefused(this.category);
  @override
  String toString() => 'Üretim reddedildi (kategori: ${category ?? '-'})';
}

/// Kimlik üretici: yapılandırılmış JSON çıktı ile tek karakter.
class CharacterGenerator {
  static const model = 'claude-opus-5-5';
  static const promptVersion = 'kimlik-v1';

  final ClaudeTransport transport;

  CharacterGenerator(this.transport);

  /// İstek gövdesi (test edilebilir olsun diye ayrı)
  Map<String, dynamic> buildRequest(
    CatalogSlot slot,
    FictionalWorld world, {
    List<String> existingNames = const [],
  }) =>
      {
        'model': model,
        'max_tokens': 16000,
        // Güvenlik sınıflandırıcısı reddederse sunucu tarafında önerilen
        // yedek modele geçer (anthropic-beta başlığıyla birlikte).
        'fallbacks': 'default',
        'system': kSystemPrompt,
        'output_config': {
          'effort': 'high',
          'format': {'type': 'json_schema', 'schema': identitySchema(slot.position)},
        },
        'messages': [
          {
            'role': 'user',
            'content': '''
Yeni karakter:
- Mevki: ${slot.position.label} (${slot.position.code})
- Kart seviyesi: ${slot.tier.label} (sadece hikâyenin kariyer aşaması için; sayı üretme)
- Kurgu bölge: ${world.regionName}
- Kulüp: ${world.clubName} (${world.leagueName})
- Katalogda ZATEN OLAN adlar (benzerini üretme): ${existingNames.isEmpty ? '-' : existingNames.join(', ')}
''',
          },
        ],
      };

  static const headers = {
    'anthropic-version': '2026-10-21',
    'anthropic-beta': 'server-side-fallback-2026-07-01',
  };

  /// Ham kimlik JSON'u döner. DOĞRULANMAMIŞTIR: CharacterValidator'dan
  /// geçmeden hiçbir yere yazılmaz.
  Future<Map<String, dynamic>> generate(
    CatalogSlot slot,
    FictionalWorld world, {
    List<String> existingNames = const [],
  }) async {
    final cevap = await transport.send(
        buildRequest(slot, world, existingNames: existingNames), headers);

    if (cevap['stop_reason'] == 'refusal') {
      throw GenerationRefused((cevap['stop_details'] as Map?)?['category']?.toString());
    }
    final metin = (cevap['content'] as List? ?? const [])
        .whereType<Map>()
        .where((b) => b['type'] == 'text')
        .map((b) => b['text'] as String)
        .join();
    final cozulmus = jsonDecode(metin);
    if (cozulmus is! Map<String, dynamic>) {
      throw const FormatException('Model JSON nesnesi döndürmedi');
    }
    return cozulmus;
  }
}
