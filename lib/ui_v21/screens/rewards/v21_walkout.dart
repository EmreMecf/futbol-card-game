import 'package:material_ui/material_ui.dart';
import 'package:shared_models/shared_models.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/audio/sound_cues.dart';
import '../../../core/feedback/game_feedback.dart';
import '../../../ui_v21/components/v21_club_crest.dart';
import '../../../ui_v21/components/v21_confetti.dart';
import '../../../ui_v21/components/v21_nation_flag.dart';
import '../../ui_v21.dart';

/// V2.1 WALKOUT: Elmas/Efsane kartın açılış sahnesi (paket açılışında,
/// karar mevcut `PackOpeningViewModel.styleFor`).
///
///   0.0–0.5 sn  ışınlar yanar (nadirlik renginde)
///   0.5–1.5 sn  ÜLKE: bayrak
///   1.5–2.5 sn  MEVKİ: "FWD" / FORVET
///   2.5–3.5 sn  KULÜP: arma
///   3.5–4.6 sn  KART ekrana vurur: titreşim, şok halkası, konfeti
///               "EFSANE!" · kart · ad · [DEVAM]
///
/// Eski sahneyle aynı zaman çizelgesi ve aynı kurallar: tek controller,
/// dokununca karta atlar, ikinci dokunuş devam eder. Animasyon azaltılmışsa
/// sahne doğrudan kartla açılır; süs efektleri (konfeti, parlama)
/// `V21Motion.cardEffects` ile kapanır.
class V21WalkoutScreen extends StatefulWidget {
  final InventoryCard card;
  final VoidCallback onContinue;

  const V21WalkoutScreen({super.key, required this.card, required this.onContinue});

  @override
  State<V21WalkoutScreen> createState() => _V21WalkoutScreenState();
}

class _V21WalkoutScreenState extends State<V21WalkoutScreen> with SingleTickerProviderStateMixin {
  static const _total = Duration(milliseconds: 4600);
  static const _flagAt = 0.11, _posAt = 0.33, _clubAt = 0.54, _cardAt = 0.76;

  late final AnimationController _c = AnimationController(vsync: this, duration: _total);
  // Işıklar ve bayrak / mevki / arma vuruşları (dokunup atlanırsa çalmaz)
  SoundCues? _sounds;
  SoundCues _cues() => SoundCues(_c, [
    (0.0, Sfx.walkoutLights),
    (_flagAt, Sfx.walkoutHit),
    (_posAt, Sfx.walkoutHit),
    (_clubAt, Sfx.walkoutHit),
  ]);
  bool _hit = false;
  bool _done = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onTick);
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) setState(() => _done = true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (V21Motion.reduced(context)) {
      // Sahne yok: kart doğrudan, titreşim yine bir kez
      _hit = true;
      _done = true;
      _c.value = 1;
      GameFeedback.haptic(HapticStrength.heavy);
      GameAudio.sfx(Sfx.walkoutCard);
    } else {
      _sounds = _cues();
      _c.forward();
    }
  }

  void _onTick() {
    if (!_hit && _c.value >= _cardAt) {
      _hit = true;
      GameFeedback.haptic(HapticStrength.heavy);
      // Kart vuruşu atlansa da çalar: sahnenin asıl anı
      GameAudio.sfx(Sfx.walkoutCard);
      GameAudio.sfx(Sfx.walkoutConfetti);
      if (mounted) setState(() {});
    }
  }

  void _tap() {
    if (_c.value >= _cardAt) {
      widget.onContinue();
      return;
    }
    _c.value = _cardAt;
    _c.forward();
  }

  @override
  void dispose() {
    _c.removeListener(_onTick);
    _sounds?.dispose();
    _c.dispose();
    super.dispose();
  }

  /// Ara aşama: büyüyerek gelir, durur, büyüyerek söner → (saydamlık, ölçek)
  static (double, double) _stage(double t, double from, double to) {
    if (t < from || t > to) return (0, 0.86);
    final local = (t - from) / (to - from);
    if (local < 0.18) {
      final p = Curves.easeOutBack.transform(local / 0.18);
      return ((local / 0.18).clamp(0.0, 1.0), 0.72 + p * 0.28);
    }
    if (local > 0.82) {
      final p = (1 - local) / 0.18;
      return (p.clamp(0.0, 1.0), 1.0 + (1 - p) * 0.1);
    }
    return (1, 1);
  }

  /// Kart vuruşu: uzaktan (2.3×) hızla küçülüp geri seker → (saydamlık, ölçek, şok)
  static (double, double, double) _impact(double t) {
    if (t < _cardAt) return (0, 2.3, 0);
    final local = ((t - _cardAt) / (1 - _cardAt)).clamp(0.0, 1.0);
    final hit = (local / 0.45).clamp(0.0, 1.0);
    return ((local / 0.15).clamp(0.0, 1.0), 2.3 - Curves.easeOutBack.transform(hit) * 1.3, hit);
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final r = V21Rarity.of(card.tier);
    final effects = V21Motion.cardEffects(context);
    final legend = card.tier == CardTier.legend;
    return Scaffold(
      backgroundColor: const Color(0xFF120830),
      body: LayoutBuilder(
        builder: (context, box) {
          final k = V21Scale.forSize(box.biggest).s;
          final cardW = (230 * k).clamp(96.0, (box.maxHeight * 0.36).clamp(96.0, 230.0 * k));
          return Semantics(
            label: _done
                ? '${r.name} kart: ${card.fullName}, ${card.position.label}, ${card.power} güç. Devam etmek için dokun.'
                : 'Özel kart açılıyor. Atlamak için dokun.',
            liveRegion: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _tap,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // ---- ZEMİN: nadirlik renginde ışınlar, yavaşça yanar ----
                  AnimatedBuilder(
                    animation: _c,
                    builder: (context, child) => Opacity(opacity: (_c.value / _flagAt).clamp(0.0, 1.0), child: child),
                    child: V21RaysBackground(
                      rayColor: r.frameLight.withValues(alpha: 0.16),
                      background: legend
                          ? const [Color(0xFF8A3FD8), Color(0xFF3A1680), Color(0xFF16082F)]
                          : const [Color(0xFF2E7FD0), Color(0xFF1B3A86), Color(0xFF0E1236)],
                    ),
                  ),
                  if (effects && _hit) const V21Sparkles(color: Color(0xFFFFF4D6)),

                  // ---- ARA AŞAMALAR ----
                  AnimatedBuilder(
                    animation: _c,
                    builder: (context, _) {
                      final t = _c.value;
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          _layer(
                            _stage(t, _flagAt, _posAt),
                            _Clue(
                              label: 'ÜLKE',
                              scale: k,
                              child: NationFlag(code: card.nationality, width: 170 * k),
                            ),
                          ),
                          _layer(_stage(t, _posAt, _clubAt), _Position(position: card.position, rarity: r, scale: k)),
                          _layer(
                            _stage(t, _clubAt, _cardAt),
                            _Clue(
                              label: 'KULÜP',
                              scale: k,
                              child: ClubCrest(clubName: card.club, size: 140 * k),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  // ---- KART ----
                  AnimatedBuilder(
                    animation: _c,
                    child: _CardBlock(card: card, rarity: r, width: cardW, glow: effects, scale: k),
                    builder: (context, child) {
                      final (opacity, scale, shock) = _impact(_c.value);
                      if (opacity <= 0) return const SizedBox.shrink();
                      return Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (effects && shock > 0 && shock < 1)
                              IgnorePointer(
                                child: CustomPaint(
                                  size: Size.square(360 * k),
                                  painter: _ShockPainter(progress: shock, color: r.frameLight),
                                ),
                              ),
                            Opacity(
                              opacity: opacity,
                              child: Transform.scale(scale: scale, child: child),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  if (effects)
                    IgnorePointer(
                      child: ConfettiOverlay(
                        active: _hit,
                        colors: [r.frame, r.frameLight, Colors.white, V21Colors.goldTop],
                      ),
                    ),

                  // ---- ALT: atla / devam ----
                  SafeArea(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(32 * k, 0, 32 * k, 20 * k),
                        child: _done
                            ? SizedBox(
                                width: 280 * k,
                                child: V21GameButton(
                                  label: 'DEVAM',
                                  size: V21ButtonSize.large,
                                  scale: k,
                                  onPressed: widget.onContinue,
                                ),
                              )
                            : Text(
                                'Atlamak için dokun',
                                style: V21Type.label(13 * k, weight: FontWeight.w800, color: const Color(0xB3FFFFFF)),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _layer((double, double) s, Widget child) {
    if (s.$1 <= 0) return const SizedBox.shrink();
    return Center(
      child: Opacity(
        opacity: s.$1,
        child: Transform.scale(scale: s.$2, child: child),
      ),
    );
  }
}

/// Ara aşama: üstte küçük altın etiket (ÜLKE / KULÜP) + görsel
class _Clue extends StatelessWidget {
  final String label;
  final Widget child;
  final double scale;
  const _Clue({required this.label, required this.child, required this.scale});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: V21Type.title(22 * scale, color: const Color(0xFFFFE6A0), letterSpacing: 3)),
      SizedBox(height: 14 * scale),
      child,
    ],
  );
}

class _Position extends StatelessWidget {
  final CardPosition position;
  final V21Rarity rarity;
  final double scale;
  const _Position({required this.position, required this.rarity, required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('MEVKİ', style: V21Type.title(22 * k, color: const Color(0xFFFFE6A0), letterSpacing: 3)),
        V21HeroTitle(position.code, size: 110 * k),
        Text(
          V21Format.upper(position.label),
          style: V21Type.title(22 * k, color: Colors.white, letterSpacing: 4, shadows: V21Type.inkShadow(k)),
        ),
      ],
    );
  }
}

/// Vuruştaki kart: "EFSANE!" · parlayan kart · ad
class _CardBlock extends StatelessWidget {
  final InventoryCard card;
  final V21Rarity rarity;
  final double width;
  final bool glow;
  final double scale;
  const _CardBlock({
    required this.card,
    required this.rarity,
    required this.width,
    required this.glow,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final k = scale;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        V21HeroTitle('${rarity.name}!', size: 60 * k),
        SizedBox(height: 12 * k),
        V21RarityGlow(
          color: rarity.frameLight,
          enabled: glow,
          radius: 16 * width / V21PlayerCard.baseWidth,
          child: V21PlayerCard(
            name: card.fullName,
            position: card.position,
            tier: card.tier,
            power: card.power,
            width: width,
          ),
        ),
        SizedBox(height: 12 * k),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 320 * k),
          child: Text(
            V21Format.upper(card.fullName),
            textAlign: TextAlign.center,
            maxLines: 2,
            style: V21Type.title(28 * k, shadows: V21Type.inkShadow(k)),
          ),
        ),
        if (card.club != null)
          Text(
            card.club!,
            style: V21Type.label(13 * k, weight: FontWeight.w800, color: const Color(0xFFD9CAFB)),
          ),
      ],
    );
  }
}

class _ShockPainter extends CustomPainter {
  final double progress;
  final Color color;
  _ShockPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    canvas.drawCircle(
      c,
      size.width * 0.18 + size.width * 0.42 * progress,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10 * (1 - progress)
        ..color = color.withValues(alpha: 0.6 * (1 - progress)),
    );
  }

  @override
  bool shouldRepaint(_ShockPainter old) => old.progress != progress || old.color != color;
}
