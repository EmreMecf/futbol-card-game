import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../ui_v21.dart';

/// V2.1 ÖĞRETİCİ İPUCU (referans hf12–hf14).
///
///        ÖĞRETİCİ · 1/3                [ÖDÜLSÜZ]
///     (✓)────(2)────(3)
///     MEVKİ   KART   TAKTİK
///   (koç) ╭ MEVKİ SEÇ ─────────────────────╮
///         │ Bu turun mevkisini sen …        │
///         ╰─────────────────────────────────╯
///
/// Metinler eski ipucuyla AYNI kaynaktan gelir (`textFor`, sunucu kural
/// sayılarıyla uyumlu). Öğretici maçları ödülsüz ve puansızdır (042);
/// ödül yalnız 3. adım bitince verilen Gümüş sandık.
class V21TutorialHint extends StatelessWidget {
  final MatchState state;

  /// (başlık, açıklama): eski `TutorialHint.textFor`
  final (String, String) Function(MatchState) textFor;
  final double scale;

  const V21TutorialHint({super.key, required this.state, required this.textFor, this.scale = 1});

  static const _steps = ['MEVKİ', 'KART', 'TAKTİK'];

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final step = (state.tutorialStep ?? 1).clamp(1, 3);
    final (title, text) = textFor(state);
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Öğretici, adım $step / 3, ${_steps[step - 1].toLowerCase()}. $title. $text',
      excludeSemantics: true,
      child: V21GamePanel(
        scale: k,
        radius: 16,
        padding: EdgeInsets.fromLTRB(12 * k, 10 * k, 12 * k, 12 * k),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(width: 76 * k),
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'ÖĞRETİCİ · $step/3',
                        style: V21Type.title(24 * k, color: V21Colors.goldTop, shadows: V21Type.inkShadow(k)),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 76 * k,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: V21Tag(
                        text: 'ÖDÜLSÜZ',
                        background: const Color(0xFF3B2F66),
                        foreground: V21Colors.textMuted,
                        scale: k,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8 * k),
            V21StepTracker(labels: _steps, current: step, scale: k),
            SizedBox(height: 10 * k),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Coach(size: 52 * k),
                SizedBox(width: 8 * k),
                Expanded(
                  child: _Bubble(title: title, text: text, scale: k),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Coach extends StatelessWidget {
  final double size;
  const _Coach({required this.size});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: V21Colors.goldTop, width: size * 0.05),
      color: const Color(0xFF4B23A8),
    ),
    clipBehavior: Clip.antiAlias,
    child: Transform.scale(
      scale: 2.1,
      alignment: const Alignment(0.18, -0.55),
      child: Image.asset(V21Assets.victoryMascot, fit: BoxFit.cover),
    ),
  );
}

class _Bubble extends StatelessWidget {
  final String title;
  final String text;
  final double scale;
  const _Bubble({required this.title, required this.text, required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    return Container(
      padding: EdgeInsets.fromLTRB(10 * k, 8 * k, 10 * k, 10 * k),
      decoration: BoxDecoration(
        color: const Color(0xFF241552),
        borderRadius: BorderRadius.circular(14 * k),
        border: Border.all(color: V21Colors.goldTop, width: 2 * k),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: V21Type.title(18 * k, shadows: V21Type.inkShadow(k * 0.8))),
          SizedBox(height: 2 * k),
          Text(
            text,
            style: V21Type.label(12.5 * k, weight: FontWeight.w700, color: const Color(0xFFE6DBFF), height: 1.35),
          ),
        ],
      ),
    );
  }
}
