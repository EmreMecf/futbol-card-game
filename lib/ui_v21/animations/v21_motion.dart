import 'package:flutter/widgets.dart';

import '../../core/feedback/game_feedback.dart';

/// V2.1 hareket süreleri ve eğrileri.
abstract final class V21Motion {
  static const Duration press = Duration(milliseconds: 90);
  static const Duration release = Duration(milliseconds: 160);
  static const Duration fill = Duration(milliseconds: 650);
  static const Duration enter = Duration(milliseconds: 420);
  static const Duration pulse = Duration(milliseconds: 1400);
  static const Duration shake = Duration(milliseconds: 420);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve bounce = Curves.easeOutBack;

  /// Eski/zayıf cihaz modu: sürekli çalışan süs efektleri (nadirlik
  /// parlaması) kapanır. Uygulama başlangıcında ya da ayarlardan verilir.
  static bool lowPower = false;

  /// Erişilebilirlik: "animasyonları azalt" açıksa hareket yok
  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Süs niteliğindeki kart efektleri (parlama, ışın dönmesi, sallanma):
  /// animasyon azaltılmışsa, düşük güç modunda ya da oyuncu Ayarlar'da
  /// "Kart parıltısı"nı kapattıysa çizilmez.
  static bool cardEffects(BuildContext context) => !reduced(context) && !lowPower && GameFeedback.cardAnimationsEnabled;
}

/// Sürekli nabız (0→1→0). Hazır sandık, etkin sekme parlaması.
/// Animasyon azaltılmışsa sabit [restValue] verir ve kare çizmez.
class V21Pulse extends StatefulWidget {
  final Widget Function(BuildContext context, double t) builder;
  final bool enabled;
  final double restValue;
  const V21Pulse({super.key, required this.builder, this.enabled = true, this.restValue = 0.5});

  @override
  State<V21Pulse> createState() => _V21PulseState();
}

class _V21PulseState extends State<V21Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: V21Motion.pulse);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant V21Pulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final run = widget.enabled && !V21Motion.reduced(context) && TickerMode.valuesOf(context).enabled;
    if (run && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!run && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_c.isAnimating) return widget.builder(context, widget.restValue);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => widget.builder(context, Curves.easeInOut.transform(_c.value)),
    );
  }
}

/// Ekran açılışında aşağıdan yukarı süzülerek belirme.
class V21EnterFade extends StatelessWidget {
  final Widget child;
  final Duration delay;
  final double offsetY;
  const V21EnterFade({super.key, required this.child, this.delay = Duration.zero, this.offsetY = 16});

  @override
  Widget build(BuildContext context) {
    if (V21Motion.reduced(context)) return child;
    final total = V21Motion.enter + delay;
    final start = delay.inMicroseconds / total.inMicroseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      builder: (context, v, child) {
        final t = V21Motion.standard.transform(((v - start) / (1 - start)).clamp(0.0, 1.0));
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, (1 - t) * offsetY), child: child),
        );
      },
      child: child,
    );
  }
}
