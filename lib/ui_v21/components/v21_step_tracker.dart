import 'package:material_ui/material_ui.dart';

import '../foundation/v21_colors.dart';
import '../foundation/v21_typography.dart';
import '../../core/l10n/app_language.dart';

/// V2.1 ADIM ÇİZELGESİ (referans hf7–hf14):
///
///   (✓)────(2)────(3)
///   MEVKİ   KART   TAKTİK
///
/// Geçilen adım yeşil ✓, şu anki altın (parlar), sıradakiler mor.
/// [current] 1'den başlar; [labels] uzunluğu kadar adım çizilir.
class V21StepTracker extends StatelessWidget {
  final List<String> labels;
  final int current;
  final double scale;

  const V21StepTracker({super.key, required this.labels, required this.current, this.scale = 1});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    Widget dot(int i) {
      final n = i + 1;
      final done = n < current, now = n == current;
      final color = done ? V21Colors.success : (now ? V21Colors.goldTop : const Color(0xFF3B2F66));
      return SizedBox(
        width: 64 * k,
        child: Column(
          children: [
            Container(
              width: (now ? 32 : 28) * k,
              height: (now ? 32 : 28) * k,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: V21Colors.ink, width: 2.5 * k),
                boxShadow: now ? [BoxShadow(color: const Color(0x99FFC832), blurRadius: 10 * k)] : null,
              ),
              alignment: Alignment.center,
              child: done
                  ? Icon(Icons.check_rounded, color: Colors.white, size: 18 * k)
                  : Text('$n', style: V21Type.title(16 * k, color: now ? V21Colors.ink : V21Colors.textMuted)),
            ),
            SizedBox(height: 3 * k),
            Text(
              labels[i],
              maxLines: 1,
              style: V21Type.label(
                10 * k,
                weight: FontWeight.w900,
                color: now ? Colors.white : V21Colors.textMuted,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      );
    }

    Widget line(int i) => Expanded(
      child: Padding(
        padding: EdgeInsets.only(bottom: 16 * k),
        child: Container(
          height: 4 * k,
          decoration: BoxDecoration(
            color: i + 1 < current ? V21Colors.success : const Color(0xFF3B2F66),
            borderRadius: BorderRadius.circular(2 * k),
          ),
        ),
      ),
    );

    return Semantics(
      label: 'Adım {current} / {length}: {p}'.trArgs({'current': current, 'length': labels.length, 'p': labels[(current - 1).clamp(0, labels.length - 1)].toLowerCase()}),
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[if (i > 0) line(i - 1), dot(i)],
        ],
      ),
    );
  }
}
