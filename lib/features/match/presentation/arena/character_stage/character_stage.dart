import 'package:shared_models/shared_models.dart';

import '../../../domain/clash_event.dart';

// =====================================================================
// KARAKTER SAHNESİ ÇEKİRDEĞİ (Aşama A1 prototipi)
// =====================================================================
// İki iş:
//   1. KOREOGRAFİ: sunucunun tur sonucundan ([ClashEvent]) her karakter
//      için hangi animasyon kliplerinin hangi sırayla oynayacağı.
//      Animasyon SONUCU BELİRLEMEZ; sunucunun sonucunu görselleştirir.
//   2. ÇİZİCİ SEÇİMİ: karakterin onaylı varlıklarına ve uygulamada kurulu
//      çalıştırıcılara bakıp 3B / sprite / 2.5B yedek arasından seçer.
//      Seçilemeyen her katmanın GEREKÇESİ döner; hiçbir şey "hazır" gibi
//      gösterilmez.
//
// Klip adları veritabanındaki animation_clip_requirements ile aynıdır
// (025_character_catalog.sql); test bunu denetler.

/// Bir karakterin bu turda oynayacağı klip dizisi
class ClipSequence {
  final List<String> clips;
  const ClipSequence(this.clips);

  /// "1 run · 2 dribble · 3 shoot" — numaralı adımlar. Ok işareti (→)
  /// oyunun yazı tiplerinde yok; ekranda kutu olarak çiziliyordu.
  @override
  String toString() =>
      [for (var i = 0; i < clips.length; i++) '${i + 1} ${clips[i]}'].join(' · ');
}

/// Turun iki tarafı için koreografi
class Choreography {
  final CardPosition position;
  final ClipSequence mine;
  final ClipSequence opponent;
  const Choreography(this.position, this.mine, this.opponent);
}

/// Mevki + sonuç → klip dizisi. Saf fonksiyon (test edilebilir).
ClipSequence clipsFor(CardPosition position, ClashOutcome outcomeForMe,
    {bool iPassed = false, bool opponentPassed = false}) {
  if (iPassed) return const ClipSequence(['idle', 'lose']);
  if (opponentPassed) return const ClipSequence(['walk', 'win']);

  return switch ((position, outcomeForMe)) {
    (CardPosition.forward, ClashOutcome.win) =>
      const ClipSequence(['run', 'dribble', 'shoot', 'celebrate']),
    (CardPosition.forward, ClashOutcome.loss) =>
      const ClipSequence(['run', 'tackle', 'lose']),
    (CardPosition.forward, ClashOutcome.draw) =>
      const ClipSequence(['run', 'dribble', 'idle']),
    (CardPosition.defender, ClashOutcome.win) =>
      const ClipSequence(['jockey', 'tackle', 'steal', 'win']),
    (CardPosition.defender, ClashOutcome.loss) =>
      const ClipSequence(['jockey', 'tackle', 'lose']),
    (CardPosition.defender, ClashOutcome.draw) =>
      const ClipSequence(['jockey', 'idle']),
    (CardPosition.midfielder, ClashOutcome.win) =>
      const ClipSequence(['control', 'dribble', 'pass', 'win']),
    (CardPosition.midfielder, ClashOutcome.loss) =>
      const ClipSequence(['control', 'intercept', 'lose']),
    (CardPosition.midfielder, ClashOutcome.draw) =>
      const ClipSequence(['control', 'pass', 'idle']),
    (CardPosition.goalkeeper, ClashOutcome.win) =>
      const ClipSequence(['idle', 'dive', 'save', 'win']),
    (CardPosition.goalkeeper, ClashOutcome.loss) =>
      const ClipSequence(['idle', 'dive', 'lose']),
    (CardPosition.goalkeeper, ClashOutcome.draw) =>
      const ClipSequence(['idle', 'catch', 'idle']),
  };
}

ClashOutcome _ters(ClashOutcome o) => switch (o) {
      ClashOutcome.win => ClashOutcome.loss,
      ClashOutcome.loss => ClashOutcome.win,
      ClashOutcome.draw => ClashOutcome.draw,
    };

/// Sunucunun tur kaydından koreografi.
Choreography choreographFor(ClashEvent e) {
  final mevki = e.position ?? CardPosition.midfielder;
  return Choreography(
    mevki,
    clipsFor(mevki, e.outcome,
        iPassed: e.iPassed, opponentPassed: e.opponentPassed),
    clipsFor(mevki, _ters(e.outcome),
        iPassed: e.opponentPassed, opponentPassed: e.iPassed),
  );
}

// ---------------------------------------------------------------------
// ÇİZİCİLER
// ---------------------------------------------------------------------
enum RendererKind {
  vector2d('2D vektör karakter (kodla çizilir, dosya gerekmez)'),
  gltf3d('Gerçek zamanlı 3B (glTF iskelet animasyonu)'),
  sprite('Sprite sayfası (3B modelden önceden işlenmiş)'),
  fallback25d('2.5B yedek arena (ArenaBackdrop / ClashScene)');

  final String label;
  const RendererKind(this.label);
}

/// Bir çizici. [unavailableReason] null ise bu karakteri çizebilir.
abstract class CharacterRenderer {
  RendererKind get kind;
  String? unavailableReason(CharacterPresentation p);
}

/// Gerçek zamanlı 3B. Varlıklar tam olsa bile uygulamada bir 3B
/// çalıştırıcı (ör. flutter_scene) kurulu değilse KULLANILAMAZ.
class GltfRenderer implements CharacterRenderer {
  /// Uygulamaya 3B çalıştırıcı eklendi mi? Bugün: HAYIR (bağımlılık
  /// eklemek kullanıcı onayı bekliyor).
  final bool runtimeInstalled;
  const GltfRenderer({this.runtimeInstalled = false});

  @override
  RendererKind get kind => RendererKind.gltf3d;

  @override
  String? unavailableReason(CharacterPresentation p) {
    if (p.mode != PresentationMode.threeD) {
      final eksik = [
        ...p.missingAssets.where((a) => a != 'portrait'),
        if (p.missingClips.isNotEmpty) '${p.missingClips.length} animasyon klibi',
      ];
      return 'Onaylı 3B varlık eksik: ${eksik.join(', ')}';
    }
    if (!runtimeInstalled) {
      return '3B çalıştırıcı uygulamaya henüz eklenmedi (bağımlılık onayı bekliyor)';
    }
    return null;
  }
}

/// Sprite sayfası. Oynatıcı bileşeni henüz yazılmadı; sadece sayfa
/// düzeni hesabı ([SpriteSheetLayout]) hazır.
class SpriteRenderer implements CharacterRenderer {
  final bool playerImplemented;
  const SpriteRenderer({this.playerImplemented = false});

  @override
  RendererKind get kind => RendererKind.sprite;

  @override
  String? unavailableReason(CharacterPresentation p) {
    if (p.spriteUri == null) return 'Onaylı sprite sayfası yok';
    if (!playerImplemented) return 'Sprite oynatıcı bileşeni henüz yazılmadı';
    return null;
  }
}

/// 2D vektör karakter (yeni görsel yön, docs/GORSEL_YON_2D.md).
///
/// Yüz ve figür [AvatarSpec]'ten kodla çizilir; onaylı dosya varlığı
/// GEREKMEZ. Bu yüzden karakter kaydı olan her özgün karakter için
/// kullanılabilir. 3B ve sprite katmanları kaldırılmadı ama artık
/// varsayılan zincirde değil ([kRenderers2d]).
class Vector2dRenderer implements CharacterRenderer {
  const Vector2dRenderer();
  @override
  RendererKind get kind => RendererKind.vector2d;
  @override
  String? unavailableReason(CharacterPresentation p) => null;
}

/// Yeni görsel yönün çizici zinciri: 2D vektör, yoksa 2.5B yedek.
const List<CharacterRenderer> kRenderers2d = [Vector2dRenderer(), Fallback25dRenderer()];

/// 2.5B yedek: her zaman kullanılabilir.
class Fallback25dRenderer implements CharacterRenderer {
  const Fallback25dRenderer();
  @override
  RendererKind get kind => RendererKind.fallback25d;
  @override
  String? unavailableReason(CharacterPresentation p) => null;
}

class RendererDecision {
  final RendererKind chosen;

  /// Atlanan katmanlar ve gerekçeleri (arayüzde gösterilir)
  final Map<RendererKind, String> skipped;

  const RendererDecision(this.chosen, this.skipped);
}

/// En iyi kullanılabilir çiziciyi seçer: 3B → sprite → 2.5B.
RendererDecision selectRenderer(
  CharacterPresentation p, {
  List<CharacterRenderer> renderers = const [
    GltfRenderer(),
    SpriteRenderer(),
    Fallback25dRenderer(),
  ],
}) {
  final atlanan = <RendererKind, String>{};
  for (final r in renderers) {
    final neden = r.unavailableReason(p);
    if (neden == null) return RendererDecision(r.kind, atlanan);
    atlanan[r.kind] = neden;
  }
  return RendererDecision(RendererKind.fallback25d, atlanan);
}

/// Sprite sayfasında kare konumu (oynatıcı yazıldığında kullanılacak)
class SpriteSheetLayout {
  final int columns;
  final int frameCount;
  final double frameWidth;
  final double frameHeight;

  const SpriteSheetLayout({
    required this.columns,
    required this.frameCount,
    required this.frameWidth,
    required this.frameHeight,
  });

  /// t (0..1) anındaki kare
  int frameAt(double t) =>
      (t.clamp(0.0, 1.0) * frameCount).floor().clamp(0, frameCount - 1);

  /// Karenin sayfadaki dikdörtgeni (sol, üst, genişlik, yükseklik)
  (double, double, double, double) rectOf(int frame) => (
        (frame % columns) * frameWidth,
        (frame ~/ columns) * frameHeight,
        frameWidth,
        frameHeight,
      );
}
