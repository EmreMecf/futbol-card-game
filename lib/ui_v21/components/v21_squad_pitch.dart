import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/feedback/game_feedback.dart';
import '../../features/deck/presentation/widgets/formation_pitch.dart';
import '../animations/v21_motion.dart';
import '../foundation/v21_colors.dart';
import '../foundation/v21_typography.dart';
import 'v21_game_panel.dart';
import 'v21_player_card.dart';

/// V2.1 KADRO SAHASI (referans Kadrom: 364×448, 3 px lacivert kenar, köşe 16).
///
/// 4-4-2 yuvaları (`kSlotPositions`), kimya bağları kartların altında. Hem
/// Kadrom hem Kart Takası kadro kurma ekranı kullanır.
///   * dokun → [onTapSlot]; basılı tut → [onHighlight] (kimya bağları vurgu)
///   * [onDrop] verilirse sürükle-bırak açık: yalnız AYNI mevkideki yuvaya
///     bırakılabilir (4-4-2 kuralı); null ise yalnız dokunma.
class V21SquadPitch extends StatelessWidget {
  final InventoryCard? Function(int slot) cardAt;
  final List<ChemistryLink> links;
  final double scale;
  final int? highlighted;
  final int? dragging;
  final ValueChanged<int> onTapSlot;
  final ValueChanged<int?> onHighlight;
  final ValueChanged<int?>? onDrag;
  final void Function(int from, int to)? onDrop;

  const V21SquadPitch({
    super.key,
    required this.cardAt,
    required this.links,
    required this.scale,
    required this.highlighted,
    required this.dragging,
    required this.onTapSlot,
    required this.onHighlight,
    this.onDrag,
    this.onDrop,
  });

  /// Aynı mevki, farklı yuva (4-4-2 kuralı)
  static bool accepts(int from, int to) => from != to && formationSlotPosition(from) == formationSlotPosition(to);

  @override
  Widget build(BuildContext context) {
    final k = scale;
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = w * 448 / 364;
        // Kart 57×81 (364 genişlikte)
        final cw = w * 57 / 364;
        final ch = cw * V21PlayerCard.baseHeight / V21PlayerCard.baseWidth;
        return Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16 * k),
            border: Border.all(color: V21Colors.ink, width: 3 * k),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13 * k),
            child: LayoutBuilder(
              builder: (context, inner) {
                final iw = inner.maxWidth, ih = inner.maxHeight;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Positioned.fill(child: CustomPaint(painter: _PitchPainter())),
                    Positioned.fill(
                      child: CustomPaint(
                        painter: ChemistryLinksPainter(links: links, highlightedSlot: highlighted),
                      ),
                    ),
                    for (final e in kSlotPositions.entries)
                      Positioned(
                        left: e.value.dx * iw - cw / 2,
                        top: e.value.dy * ih - ch / 2,
                        width: cw,
                        height: ch,
                        child: _slot(e.key, cw),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _slot(int slot, double cw) {
    final card = cardAt(slot);
    final from = dragging;
    final valid = from != null && accepts(from, slot);
    final dim = from != null && !valid && from != slot;
    final position = formationSlotPosition(slot);

    Widget tile({double scaleUp = 1}) => card == null
        ? _EmptySlot(position: position, width: cw * scaleUp, highlighted: valid)
        : V21PlayerCard(
            key: ValueKey('slot-$slot-${card.userCardId}'),
            name: card.fullName,
            position: card.position,
            tier: card.tier,
            power: card.power,
            seed: card.cardId,
            kitSeed: card.club ?? card.nationality,
            imageUrl: card.imageUrl,
            width: cw * scaleUp,
            selected: valid || highlighted == slot,
          );

    final drop = onDrop;
    return DragTarget<int>(
      onWillAcceptWithDetails: (d) => drop != null && accepts(d.data, slot),
      onAcceptWithDetails: (d) => drop?.call(d.data, slot),
      builder: (context, candidates, _) {
        Widget body = card == null || drop == null
            ? tile()
            : Draggable<int>(
                data: slot,
                feedback: Material(color: Colors.transparent, child: tile(scaleUp: 1.15)),
                childWhenDragging: Opacity(opacity: 0.25, child: tile()),
                onDragStarted: () {
                  GameFeedback.haptic(HapticStrength.selection);
                  onDrag?.call(slot);
                },
                onDragEnd: (_) => onDrag?.call(null),
                onDraggableCanceled: (_, _) => onDrag?.call(null),
                child: tile(),
              );
        body = Semantics(
          button: true,
          label: card == null
              ? '${position.label} yuvası boş, kart seç'
              : '${position.label}: ${card.fullName}, güç ${card.power}, değiştirmek için dokun',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: () => onTapSlot(slot),
            onLongPressStart: (_) => onHighlight(slot),
            onLongPressEnd: (_) => onHighlight(null),
            child: body,
          ),
        );
        return AnimatedOpacity(
          duration: V21Motion.release,
          opacity: dim ? 0.35 : 1,
          child: AnimatedScale(duration: V21Motion.release, scale: candidates.isNotEmpty ? 1.1 : 1, child: body),
        );
      },
    );
  }
}

class _EmptySlot extends StatelessWidget {
  final CardPosition position;
  final double width;
  final bool highlighted;
  const _EmptySlot({required this.position, required this.width, required this.highlighted});

  @override
  Widget build(BuildContext context) {
    final k = width / 57;
    return SizedBox(
      width: width,
      height: width * V21PlayerCard.baseHeight / V21PlayerCard.baseWidth,
      child: V21GamePanel(
        style: V21PanelStyle.empty,
        accent: highlighted ? V21Colors.goldTop : Colors.white.withValues(alpha: 0.75),
        radius: 9,
        scale: k,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, size: 20 * k, color: Colors.white),
            Text(position.code, style: V21Type.title(13 * k)),
          ],
        ),
      ),
    );
  }
}

/// Referans saha: açık/koyu yeşil şeritler (#59D172 / #49C864), aşağı doğru
/// koyulaşır; beyaz yarı saydam çizgiler, orta yuvarlak, alt ceza sahası.
class _PitchPainter extends CustomPainter {
  const _PitchPainter();

  @override
  void paint(Canvas canvas, Size s) {
    const stripes = 15;
    final sh = s.height / stripes;
    for (var i = 0; i < stripes; i++) {
      final t = i / stripes;
      final light = Color.lerp(const Color(0xFF5BD374), const Color(0xFF2E9E48), t * 0.75)!;
      final dark = Color.lerp(const Color(0xFF49C864), const Color(0xFF268F3E), t * 0.75)!;
      canvas.drawRect(Rect.fromLTWH(0, i * sh, s.width, sh + 1), Paint()..color = i.isEven ? light : dark);
    }
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s.width * 0.008
      ..color = Colors.white.withValues(alpha: 0.6);
    // Orta çizgi ve yuvarlak (saha yüksekliğinin ~%49'u)
    final midY = s.height * 0.49;
    canvas.drawLine(Offset(0, midY), Offset(s.width, midY), line);
    canvas.drawCircle(Offset(s.width / 2, midY), s.width * 0.135, line);
    // Alt ceza sahası
    final boxW = s.width * 0.44, boxH = s.height * 0.155;
    canvas.drawRect(Rect.fromLTWH((s.width - boxW) / 2, s.height - boxH, boxW, boxH + 2), line);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
