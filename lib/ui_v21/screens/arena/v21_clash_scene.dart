import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:shared_models/shared_models.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/audio/sound_cues.dart';
import '../../../features/match/domain/clash_event.dart';
import '../../ui_v21.dart';
import '../../../core/l10n/app_language.dart';

/// TUR SONUCU: iki kart karşılaşır, sonuç şeridi çıkar. Sonucu sunucu
/// belirler ([ClashEvent]); sahne yalnız gösterir. Dokununca atlanır.
class V21ClashScene extends StatefulWidget {
  final ClashEvent event;
  final VoidCallback onFinished;
  const V21ClashScene({super.key, required this.event, required this.onFinished});

  @override
  State<V21ClashScene> createState() => _V21ClashSceneState();
}

class _V21ClashSceneState extends State<V21ClashScene> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  Timer? _timer;
  SoundCues? _sounds;
  bool _started = false;
  bool _done = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final reduced = V21Motion.reduced(context);
    if (reduced) {
      _c.value = 1;
      _playOutcome();
    } else {
      // Kartlar birlikte açılır, ortada çarpışır, sonuç şeridiyle sonuç sesi
      _sounds = SoundCues(_c, [(0.0, Sfx.reveal), (0.55, Sfx.clash)]);
      _c.forward().whenComplete(() {
        if (mounted && !_done) _playOutcome();
      });
    }
    _timer = Timer(Duration(milliseconds: reduced ? 1400 : 2300), _finish);
  }

  void _playOutcome() {
    final e = widget.event;
    if (e.wonByLegendRule) GameAudio.sfx(Sfx.legend);
    GameAudio.sfx(switch (e.outcome) {
      ClashOutcome.win => Sfx.roundWin,
      ClashOutcome.loss => Sfx.roundLose,
      ClashOutcome.draw => Sfx.roundDraw,
    });
  }

  void _finish() {
    if (_done || !mounted) return;
    _done = true;
    _timer?.cancel();
    widget.onFinished();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sounds?.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    final color = switch (e.outcome) {
      ClashOutcome.win => V21Colors.success,
      ClashOutcome.loss => V21Colors.danger,
      ClashOutcome.draw => V21Colors.goldBottom,
    };
    return Semantics(
      liveRegion: true,
      button: true,
      label: '${e.headline}. ${e.detail}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _finish,
        child: ColoredBox(
          color: const Color(0xEE120830),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, box) {
                final k = V21Scale.forSize(box.biggest).s;
                final w = (box.maxWidth * 0.36).clamp(96.0, box.maxHeight * 0.3);
                return AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) {
                    final t = Curves.easeOutBack.transform(_c.value);
                    final shift = (1 - t) * box.maxWidth * 0.5;
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Transform.translate(
                              offset: Offset(-shift, 0),
                              child: _Side(move: e.myMove, width: w, won: e.outcome == ClashOutcome.win, scale: k),
                            ),
                            SizedBox(
                              width: 56 * k,
                              child: Center(
                                child: Text(
                                  'VS',
                                  style: V21Type.title(34 * k, color: V21Colors.goldTop, shadows: V21Type.inkShadow(k)),
                                ),
                              ),
                            ),
                            Transform.translate(
                              offset: Offset(shift, 0),
                              child: _Side(
                                move: e.opponentMove,
                                width: w,
                                won: e.outcome == ClashOutcome.loss,
                                scale: k,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 18 * k),
                        Opacity(
                          opacity: _c.value,
                          child: Container(
                            margin: EdgeInsets.symmetric(horizontal: 20 * k),
                            padding: EdgeInsets.symmetric(horizontal: 22 * k, vertical: 10 * k),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(16 * k),
                              border: Border.all(color: V21Colors.ink, width: 3 * k),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(e.headline, style: V21Type.title(30 * k, shadows: V21Type.inkShadow(k))),
                                if (e.detail.isNotEmpty)
                                  Text(
                                    e.detail,
                                    textAlign: TextAlign.center,
                                    style: V21Type.label(13 * k, weight: FontWeight.w800, color: Colors.white),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Side extends StatelessWidget {
  final MatchMove? move;
  final double width;
  final bool won;
  final double scale;
  const _Side({required this.move, required this.width, required this.won, required this.scale});

  @override
  Widget build(BuildContext context) {
    final m = move;
    if (m == null || m.isPass) {
      return Stack(
        alignment: Alignment.center,
        children: [
          V21CardBack(width: width, semanticsLabel: 'Pas'.tr),
          Text('PAS'.tr, style: V21Type.title(30 * scale, shadows: V21Type.inkShadow(scale))),
        ],
      );
    }
    return AnimatedScale(
      scale: won ? 1.08 : 0.96,
      duration: const Duration(milliseconds: 240),
      child: V21PlayerCard(
        name: m.fullName ?? '',
        position: m.position ?? CardPosition.midfielder,
        tier: m.tier ?? CardTier.bronze,
        power: m.effectivePower ?? 0,
        width: width,
        selected: won,
      ),
    );
  }
}
