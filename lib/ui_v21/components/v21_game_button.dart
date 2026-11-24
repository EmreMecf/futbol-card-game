import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../core/audio/game_audio.dart';
import '../animations/v21_motion.dart';
import '../foundation/v21_colors.dart';
import '../foundation/v21_metrics.dart';
import '../foundation/v21_typography.dart';

/// Düğme renk ailesi (referans `.gbutton`, `.gbutton.blue/green/dim`)
enum V21ButtonTone {
  gold(V21Colors.goldTop, V21Colors.goldBottom, V21Colors.goldLip, V21Colors.goldEdge, V21Colors.goldShadow),
  blue(Color(0xFF6FE4FF), Color(0xFF1F7EEB), Color(0xFF064498), Color(0xFF9DF3FF), Color(0xFF0A3F8C)),
  green(Color(0xFFA4FF9C), Color(0xFF16B03D), Color(0xFF146024), Color(0xFFB9FF9B), Color(0xFF0E5A22)),
  purple(Color(0xFF7A66A8), Color(0xFF3B2C6E), Color(0xFF291B4D), Color(0xFF9A82C4), Color(0xFF1B0E3A)),
  red(Color(0xFFFF8A9B), Color(0xFFE5294B), Color(0xFF8E0F2A), Color(0xFFFFB3BF), Color(0xFF7A0A22));

  final Color top;
  final Color bottom;
  final Color lip;
  final Color edge;
  final Color textShadow;
  const V21ButtonTone(this.top, this.bottom, this.lip, this.edge, this.textShadow);
}

/// Düğmenin iş durumu. "pressed" etkileşim durumudur (parmak üstündeyken).
enum V21ButtonStatus { normal, disabled, loading, success, error }

/// Hazır boyutlar (390 tasarım genişliğinde)
enum V21ButtonSize {
  /// Ana sayfa "MAÇA BAŞLA": 82 px, 30 px yazı
  hero(V21Metrics.primaryButtonHeight, 32, V21Metrics.radiusL + 2, V21Metrics.buttonLip),
  large(60, 22, V21Metrics.radiusL, 6),
  medium(48, 18, V21Metrics.radiusM, 5),
  small(36, 14, 10, 4);

  final double height;
  final double fontSize;
  final double radius;
  final double lip;
  const V21ButtonSize(this.height, this.fontSize, this.radius, this.lip);
}

/// V2.1 OYUN DÜĞMESİ — kalın, 3B alt dudaklı, parlak gradyanlı.
///
/// Durumlar:
///   * normal   : [tone] renginde
///   * pressed  : yüz [lip] kadar aşağı iner, dudak kaybolur (dokunurken)
///   * disabled : soluk mor, dokunulmaz
///   * loading  : dönen gösterge + etiket, dokunulmaz
///   * success  : yeşil + onay simgesi
///   * error    : kırmızı + uyarı simgesi + kısa sallanma
///
/// [scale] 390 tasarım tuvalinden ekrana ölçektir (bkz. V21Scale).
class V21GameButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final V21ButtonTone tone;
  final V21ButtonSize size;
  final V21ButtonStatus status;
  final IconData? leadingIcon;

  /// Simge yerine özel öğe (ör. V2.1 altın sikkesi). [leadingIcon]'dan önceliklidir.
  final Widget? leading;
  final double scale;

  /// Ekran okuyucu için ek açıklama (yoksa [label])
  final String? semanticsLabel;

  /// Yalnız görsel test/vitrin: basılı görünümü zorla
  @visibleForTesting
  final bool debugPressed;

  const V21GameButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.tone = V21ButtonTone.gold,
    this.size = V21ButtonSize.large,
    this.status = V21ButtonStatus.normal,
    this.leadingIcon,
    this.leading,
    this.scale = 1,
    this.semanticsLabel,
    this.debugPressed = false,
  });

  @override
  State<V21GameButton> createState() => _V21GameButtonState();
}

class _V21GameButtonState extends State<V21GameButton> with SingleTickerProviderStateMixin {
  bool _down = false;
  late final AnimationController _shake = AnimationController(vsync: this, duration: V21Motion.shake);

  bool get _interactive =>
      widget.onPressed != null && widget.status != V21ButtonStatus.disabled && widget.status != V21ButtonStatus.loading;

  @override
  void didUpdateWidget(covariant V21GameButton old) {
    super.didUpdateWidget(old);
    if (widget.status == V21ButtonStatus.error && old.status != V21ButtonStatus.error && !V21Motion.reduced(context)) {
      _shake.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  V21ButtonTone get _tone => switch (widget.status) {
    V21ButtonStatus.success => V21ButtonTone.green,
    V21ButtonStatus.error => V21ButtonTone.red,
    V21ButtonStatus.disabled => V21ButtonTone.purple,
    _ => widget.tone,
  };

  @override
  Widget build(BuildContext context) {
    final k = widget.scale;
    final size = widget.size;
    final h = size.height * k;
    final lip = size.lip * k;
    final radius = size.radius * k;
    final pressed = (_down || widget.debugPressed) && widget.status != V21ButtonStatus.disabled;
    final drop = pressed ? lip * 0.7 : 0.0;
    final tone = _tone;
    final disabled = widget.status == V21ButtonStatus.disabled;

    final label = _Label(
      text: widget.label,
      fontSize: size.fontSize * k,
      shadow: tone.textShadow,
      status: widget.status,
      leadingIcon: widget.leadingIcon,
      leading: widget.leading,
      scale: k,
    );

    final face = AnimatedContainer(
      duration: pressed ? V21Motion.press : V21Motion.release,
      curve: V21Motion.standard,
      margin: EdgeInsets.only(top: drop, bottom: lip - drop),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: tone.edge, width: math.max(1, 1.5 * k)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [tone.top, Color.lerp(tone.top, tone.bottom, 0.45)!, tone.bottom],
          stops: const [0, 0.42, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Üst parlama
          Positioned(
            left: 6 * k,
            right: 6 * k,
            top: 3 * k,
            height: (h - lip) * 0.36,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius * 0.8),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: disabled ? 0.12 : 0.42),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Center(child: label),
        ],
      ),
    );

    // Referans: düğmenin dışında 2 px lacivert kontur (x=35..36 #1B0E3A)
    final outline = 2 * k;
    Widget body = Container(
      height: h,
      padding: EdgeInsets.all(outline),
      decoration: BoxDecoration(color: V21Colors.ink, borderRadius: BorderRadius.circular(radius + outline)),
      child: Stack(
        children: [
          // 3B dudak + gölge
          Positioned.fill(
            top: lip,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tone.lip,
                borderRadius: BorderRadius.circular(radius),
                boxShadow: disabled
                    ? null
                    : [
                        BoxShadow(
                          color: tone.bottom.withValues(alpha: 0.35),
                          blurRadius: 16 * k,
                          offset: Offset(0, 5 * k),
                        ),
                      ],
              ),
            ),
          ),
          Positioned.fill(child: face),
        ],
      ),
    );

    body = AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        final t = _shake.value;
        final dx = t == 0 ? 0.0 : math.sin(t * math.pi * 6) * (1 - t) * 8 * k;
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: Opacity(opacity: disabled ? 0.7 : 1, child: body),
    );

    return Semantics(
      container: true,
      button: true,
      enabled: _interactive,
      label: widget.semanticsLabel ?? widget.label,
      excludeSemantics: true,
      onTap: _interactive ? widget.onPressed : null,
      child: MouseRegion(
        cursor: _interactive ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _interactive ? (_) => _set(true) : null,
          onTapCancel: _interactive ? () => _set(false) : null,
          onTapUp: _interactive ? (_) => _set(false) : null,
          onTap: _interactive
              ? () {
                  HapticFeedback.lightImpact();
                  GameAudio.sfx(Sfx.tap);
                  widget.onPressed!();
                }
              : null,
          child: body,
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color shadow;
  final V21ButtonStatus status;
  final IconData? leadingIcon;
  final Widget? leading;
  final double scale;

  const _Label({
    required this.text,
    required this.fontSize,
    required this.shadow,
    required this.status,
    required this.leadingIcon,
    required this.leading,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final style = V21Type.title(
      fontSize,
      letterSpacing: 0,
      shadows: [
        Shadow(color: shadow, offset: Offset(0, fontSize * 0.08)),
        Shadow(color: shadow.withValues(alpha: 0.5), blurRadius: fontSize * 0.12),
      ],
    );
    final iconSize = fontSize * 0.9;
    final Widget? lead = switch (status) {
      V21ButtonStatus.loading => SizedBox.square(
        dimension: iconSize * 0.85,
        child: CircularProgressIndicator(strokeWidth: math.max(2, fontSize * 0.1), color: Colors.white),
      ),
      V21ButtonStatus.success => Icon(Icons.check_circle_rounded, size: iconSize, color: Colors.white),
      V21ButtonStatus.error => Icon(Icons.error_rounded, size: iconSize, color: Colors.white),
      _ => leading ?? (leadingIcon == null ? null : Icon(leadingIcon, size: iconSize, color: Colors.white)),
    };
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12 * scale),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (lead != null) ...[lead, SizedBox(width: fontSize * 0.3)],
            Text(text, maxLines: 1, style: style),
          ],
        ),
      ),
    );
  }
}
