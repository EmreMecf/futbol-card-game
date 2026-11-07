import 'package:flutter/painting.dart';
import 'package:shared_models/shared_models.dart';

// =====================================================================
// 2D STİLİZE KARAKTER TANIMI (yeni görsel yön)
// =====================================================================
// Karakter yüzleri DOSYA DEĞİL, PARAMETRE: ten, kafa şekli, saç, kaş,
// göz, ağız, sakal, aksesuar ve forma renkleri. [AvatarPainter] bunları
// kodla (vektör) çizer. Böylece:
//   * Ücretli görsel üretimi veya lisans gerekmez,
//   * Kart, detay ve arena AYNI tanımdan çizilir (stil bütünlüğü),
//   * Her boyutta keskin kalır, uygulama boyutunu büyütmez,
//   * Bir karakterin görünüşü bir JSON satırıyla saklanabilir.
//
// Gerçek insan fotoğrafına benzemez: düz renk, kalın kontur, büyük kafa.

/// Ten tonları (açıktan koyuya)
enum SkinTone {
  porcelain(Color(0xFFF6DCC8), 'porselen'),
  light(Color(0xFFF0C9A8), 'açık'),
  wheat(Color(0xFFE2B48A), 'buğday'),
  tan(Color(0xFFC98E62), 'esmer'),
  brown(Color(0xFF9A6440), 'kahverengi'),
  deep(Color(0xFF6B4129), 'koyu');

  final Color color;
  final String label;
  const SkinTone(this.color, this.label);
}

enum HeadShape { oval, round, square, long }

enum HairStyle {
  buzz('kazınmış'),
  crop('kısa'),
  sidePart('yana taralı'),
  curlyTop('kıvırcık üst'),
  afro('afro'),
  mohawk('ibik'),
  bun('topuz'),
  bald('saçsız'),
  longWavy('uzun dalgalı'),
  cornrows('örgülü');

  final String label;
  const HairStyle(this.label);
}

enum EyeStyle { dot, almond, sleepy }

enum BrowStyle { soft, thick, angled }

enum MouthStyle { smile, grin, serious, smirk }

enum FacialHair { none, stubble, beard, mustache }

/// Yüzde görünen aksesuar (bileklik gibi gövde aksesuarları ayrı)
enum HeadAccessory { none, headband, earring, eyeBlack }

/// Vücut yapısı: arena figüründe gövde ve bacak kalınlığı
enum BodyBuild {
  slim(0.86),
  regular(1.0),
  stocky(1.16);

  final double widthFactor;
  const BodyBuild(this.widthFactor);
}

class AvatarSpec {
  final SkinTone skin;
  final HeadShape head;
  final HairStyle hair;
  final Color hairColor;
  final EyeStyle eyes;
  final Color eyeColor;
  final BrowStyle brows;
  final MouthStyle mouth;
  final FacialHair facialHair;
  final bool freckles;
  final HeadAccessory headAccessory;

  /// Bileklik rengi (null = yok). Sadece arena figüründe görünür.
  final Color? wristband;
  final BodyBuild build;

  /// Forma ana rengi, ikincil rengi (yaka/şerit), şort ve numara
  final Color jersey;
  final Color jerseyTrim;
  final Color shorts;
  final int shirtNumber;

  const AvatarSpec({
    required this.skin,
    required this.head,
    required this.hair,
    required this.hairColor,
    this.eyes = EyeStyle.dot,
    this.eyeColor = const Color(0xFF3B2A20),
    this.brows = BrowStyle.soft,
    this.mouth = MouthStyle.smile,
    this.facialHair = FacialHair.none,
    this.freckles = false,
    this.headAccessory = HeadAccessory.none,
    this.wristband,
    this.build = BodyBuild.regular,
    required this.jersey,
    required this.jerseyTrim,
    this.shorts = const Color(0xFF1B2230),
    required this.shirtNumber,
  });

  AvatarSpec copyWith({
    Color? jersey,
    Color? jerseyTrim,
    Color? shorts,
    int? shirtNumber,
    MouthStyle? mouth,
    BrowStyle? brows,
  }) =>
      AvatarSpec(
        skin: skin,
        head: head,
        hair: hair,
        hairColor: hairColor,
        eyes: eyes,
        eyeColor: eyeColor,
        brows: brows ?? this.brows,
        mouth: mouth ?? this.mouth,
        facialHair: facialHair,
        freckles: freckles,
        headAccessory: headAccessory,
        wristband: wristband,
        build: build,
        jersey: jersey ?? this.jersey,
        jerseyTrim: jerseyTrim ?? this.jerseyTrim,
        shorts: shorts ?? this.shorts,
        shirtNumber: shirtNumber ?? this.shirtNumber,
      );

  // -------------------------------------------------------------------
  // JSON: önerilen `characters.avatar_spec` sütununun biçimi
  // (docs/GORSEL_YON_2D.md, bölüm 9). Renkler "#RRGGBB".
  // -------------------------------------------------------------------
  Map<String, dynamic> toJson() => {
        'skin': skin.name,
        'head': head.name,
        'hair': hair.name,
        'hair_color': _hex(hairColor),
        'eyes': eyes.name,
        'eye_color': _hex(eyeColor),
        'brows': brows.name,
        'mouth': mouth.name,
        'facial_hair': facialHair.name,
        'freckles': freckles,
        'head_accessory': headAccessory.name,
        'wristband': wristband == null ? null : _hex(wristband!),
        'build': build.name,
        'jersey': _hex(jersey),
        'jersey_trim': _hex(jerseyTrim),
        'shorts': _hex(shorts),
        'shirt_number': shirtNumber,
      };

  factory AvatarSpec.fromJson(Map<String, dynamic> j) {
    T e<T extends Enum>(List<T> values, Object? name, T fallback) =>
        values.where((v) => v.name == name).firstOrNull ?? fallback;
    return AvatarSpec(
      skin: e(SkinTone.values, j['skin'], SkinTone.wheat),
      head: e(HeadShape.values, j['head'], HeadShape.oval),
      hair: e(HairStyle.values, j['hair'], HairStyle.crop),
      hairColor: _parse(j['hair_color']) ?? const Color(0xFF2B1D16),
      eyes: e(EyeStyle.values, j['eyes'], EyeStyle.dot),
      eyeColor: _parse(j['eye_color']) ?? const Color(0xFF3B2A20),
      brows: e(BrowStyle.values, j['brows'], BrowStyle.soft),
      mouth: e(MouthStyle.values, j['mouth'], MouthStyle.smile),
      facialHair: e(FacialHair.values, j['facial_hair'], FacialHair.none),
      freckles: j['freckles'] == true,
      headAccessory: e(HeadAccessory.values, j['head_accessory'], HeadAccessory.none),
      wristband: _parse(j['wristband']),
      build: e(BodyBuild.values, j['build'], BodyBuild.regular),
      jersey: _parse(j['jersey']) ?? const Color(0xFF2E6BD8),
      jerseyTrim: _parse(j['jersey_trim']) ?? const Color(0xFFFFFFFF),
      shorts: _parse(j['shorts']) ?? const Color(0xFF1B2230),
      shirtNumber: (j['shirt_number'] as num?)?.toInt() ?? 10,
    );
  }

  /// Veritabanındaki serbest metinli görünüşten (025 `appearance`)
  /// TAHMİNİ bir tanım. Metinde geçen anahtar kelimeler kullanılır;
  /// metinde olmayan özellikler (saç modeli, ağız...) karakterin
  /// slug'ından DETERMİNİSTİK seçilir: aynı karakter her cihazda aynı
  /// görünür. Kalıcı çözüm onaylı `avatar_spec` sütunudur.
  factory AvatarSpec.fromAppearance(
    String slug,
    CharacterAppearance a, {
    Color? jersey,
    Color? jerseyTrim,
  }) {
    final h = _fnv1a(slug);
    int pick(int salt, int n) => ((h >> (salt * 3)) ^ (h >> 17) ^ salt * 2654435761) % n;

    final ten = _ara(a.skinTone, const {
          'porselen': SkinTone.porcelain,
          'çok açık': SkinTone.porcelain,
          'buğday': SkinTone.wheat,
          'açık': SkinTone.light,
          'esmer': SkinTone.tan,
          'kahve': SkinTone.brown,
          'koyu': SkinTone.deep,
        }) ??
        SkinTone.values[pick(1, SkinTone.values.length)];

    final sacRengi = _ara(a.hair, const {
          'bakır': Color(0xFFC0622B),
          'kızıl': Color(0xFFB4441F),
          'sarı': Color(0xFFE8C26A),
          'kumral': Color(0xFF8A5A33),
          'kahverengi': Color(0xFF5A3A22),
          'gri': Color(0xFF9AA1A8),
          'beyaz': Color(0xFFE9E9E9),
          'mavi': Color(0xFF3A6FD8),
          'siyah': Color(0xFF1E1A1A),
        }) ??
        const [Color(0xFF1E1A1A), Color(0xFF3B2618), Color(0xFF6B4423)][pick(2, 3)];

    final sacModeli = _ara(a.hair, const {
          'afro': HairStyle.afro,
          'kıvırcık': HairStyle.curlyTop,
          'topuz': HairStyle.bun,
          'örgü': HairStyle.cornrows,
          'ibik': HairStyle.mohawk,
          'kazın': HairStyle.buzz,
          'uzun': HairStyle.longWavy,
          'dalgalı': HairStyle.longWavy,
          'kel': HairStyle.bald,
          'yana': HairStyle.sidePart,
        }) ??
        const [HairStyle.sidePart, HairStyle.crop, HairStyle.curlyTop, HairStyle.buzz][pick(3, 4)];

    final yuz = a.face.toLowerCase();
    final aks = a.accessory.toLowerCase();
    final bileklikRengi = aks.contains('bileklik')
        ? (_ara(aks, const {
              'turkuaz': Color(0xFF2EC4B6),
              'kırmızı': Color(0xFFE5484D),
              'sarı': Color(0xFFF2C94C),
              'mor': Color(0xFF8B5CF6),
            }) ??
            const Color(0xFFFFFFFF))
        : null;

    return AvatarSpec(
      skin: ten,
      head: HeadShape.values[pick(4, HeadShape.values.length)],
      hair: sacModeli,
      hairColor: sacRengi,
      eyes: EyeStyle.values[pick(5, EyeStyle.values.length)],
      brows: BrowStyle.values[pick(6, BrowStyle.values.length)],
      mouth: const [MouthStyle.smile, MouthStyle.grin, MouthStyle.smirk][pick(7, 3)],
      facialHair: yuz.contains('sakal') ? FacialHair.beard : FacialHair.none,
      freckles: yuz.contains('çil'),
      headAccessory: aks.contains('saç bandı') || aks.contains('bant')
          ? HeadAccessory.headband
          : aks.contains('küpe')
              ? HeadAccessory.earring
              : HeadAccessory.none,
      wristband: bileklikRengi,
      build: _ara(a.build, const {
            'ince': BodyBuild.slim,
            'zayıf': BodyBuild.slim,
            'iri': BodyBuild.stocky,
            'güçlü': BodyBuild.stocky,
            'kaslı': BodyBuild.stocky,
          }) ??
          BodyBuild.regular,
      jersey: jersey ?? const Color(0xFF2E6BD8),
      jerseyTrim: jerseyTrim ?? const Color(0xFFFFFFFF),
      shirtNumber: a.shirtNumber,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AvatarSpec && _mapEq(other.toJson(), toJson());

  @override
  int get hashCode => Object.hashAll(toJson().values);
}

// ---------------------------------------------------------------------
// yardımcılar
// ---------------------------------------------------------------------
T? _ara<T>(String metin, Map<String, T> sozluk) {
  final m = metin.toLowerCase();
  for (final e in sozluk.entries) {
    if (m.contains(e.key)) return e.value;
  }
  return null;
}

int _fnv1a(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h;
}

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

Color? _parse(Object? v) {
  if (v is! String || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(v)) return null;
  return Color(0xFF000000 | int.parse(v.substring(1), radix: 16));
}

bool _mapEq(Map<String, dynamic> a, Map<String, dynamic> b) {
  if (a.length != b.length) return false;
  for (final k in a.keys) {
    if (a[k] != b[k]) return false;
  }
  return true;
}
