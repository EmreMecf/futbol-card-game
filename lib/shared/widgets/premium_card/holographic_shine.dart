import 'package:flutter/material.dart';

import 'card_tier_theme.dart';

/// Kartin uzerinden gecen HOLOGRAFIK PARLAMA.
///
/// NASIL CALISIYOR?
/// Kartin uzerine capraz duran, cok dar ve cok parlak bir degrade
/// koyuyoruz. Bu degradeyi soldan saga kaydirdigimizda, sanki isik
/// kartin yuzeyinden geciyormus gibi gorunuyor.
///
/// BlendMode.plus kullanmamizin sebebi: alttaki rengin USTUNE ekleme
/// yapar (carpma ya da degistirme degil). Boylece koyu alanlar hafifce,
/// zaten acik olan metalik alanlar ise gozle gorulur sekilde parlar -
/// tipki gercek holografik folyoda oldugu gibi.
///
/// PERFORMANS NOTU:
/// Bu efekt sadece Altin ve ustu seviyelerde calisir. Bronz/Gumus
/// kartlarda animasyon HIC baslatilmaz; koleksiyon ekraninda yuzlerce
/// kart olabilecegi icin bu onemli.
class HolographicShine extends StatefulWidget {
  final CardTierTheme theme;

  /// Kartin siluetini kirpmak icin
  final CustomClipper<Path>? clipper;

  /// Efekt aktif mi? (liste icinde kapatmak isteyebiliriz)
  final bool enabled;

  const HolographicShine({
    super.key,
    required this.theme,
    this.clipper,
    this.enabled = true,
  });

  @override
  State<HolographicShine> createState() => _HolographicShineState();
}

class _HolographicShineState extends State<HolographicShine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _kontrolcu;

  @override
  void initState() {
    super.initState();

    _kontrolcu = AnimationController(
      vsync: this,
      duration: widget.theme.sweepInterval,
    );

    if (_calismaliMi) _kontrolcu.repeat();
  }

  bool get _calismaliMi => widget.enabled && widget.theme.hasHolographicSweep;

  @override
  void didUpdateWidget(HolographicShine oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_calismaliMi && !_kontrolcu.isAnimating) {
      _kontrolcu
        ..duration = widget.theme.sweepInterval
        ..repeat();
    } else if (!_calismaliMi && _kontrolcu.isAnimating) {
      _kontrolcu.stop();
    }
  }

  @override
  void dispose() {
    _kontrolcu.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_calismaliMi) return const SizedBox.shrink();

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _kontrolcu,
        builder: (context, _) {
          // -1.5'ten 1.5'e giden bir ilerleme.
          // Sinirlarin disina tasmasi, parlamanin kart disindan
          // gelip kart disina cikmasini saglar.
          final ilerleme = _kontrolcu.value * 3.0 - 1.5;

          return ShaderMask(
            blendMode: BlendMode.plus,
            shaderCallback: (rect) {
              return LinearGradient(
                begin: Alignment(ilerleme - 0.6, -1),
                end: Alignment(ilerleme + 0.6, 1),
                colors: [
                  Colors.transparent,
                  widget.theme.specularColor.withValues(alpha: 0.0),
                  widget.theme.specularColor.withValues(alpha: 0.55),
                  Colors.white.withValues(alpha: 0.35),
                  widget.theme.specularColor.withValues(alpha: 0.55),
                  widget.theme.specularColor.withValues(alpha: 0.0),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.35, 0.45, 0.5, 0.55, 0.65, 1.0],
              ).createShader(rect);
            },
            // ShaderMask'in bir seyi boyamasi icin opak bir zemin gerekir.
            child: const ColoredBox(color: Colors.white),
          );
        },
      ),
    );
  }
}

/// Legend kartlarin cerceve etrafinda DONEN renkli isigi.
///
/// Cerceve degradesinin acisini surekli dondurerek, renklerin kartin
/// kenarinda akiyormus gibi gorunmesini saglar. Bu efekt sadece
/// Legend kartlarda vardir ve onlari uzaktan bile ayirt edilebilir kilar.
class AnimatedBorderGlow extends StatefulWidget {
  final CardTierTheme theme;
  final Widget Function(BuildContext context, double rotation) builder;
  final bool enabled;

  const AnimatedBorderGlow({
    super.key,
    required this.theme,
    required this.builder,
    this.enabled = true,
  });

  @override
  State<AnimatedBorderGlow> createState() => _AnimatedBorderGlowState();
}

class _AnimatedBorderGlowState extends State<AnimatedBorderGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _kontrolcu;

  bool get _calismaliMi => widget.enabled && widget.theme.hasAnimatedBorder;

  @override
  void initState() {
    super.initState();
    _kontrolcu = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    if (_calismaliMi) _kontrolcu.repeat();
  }

  @override
  void dispose() {
    _kontrolcu.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Animasyon yoksa sabit acili tek bir cizim yeter.
    if (!_calismaliMi) {
      return widget.builder(context, -0.785); // -45 derece
    }

    return AnimatedBuilder(
      animation: _kontrolcu,
      builder: (context, _) {
        // 0 -> 2*pi arasi tam tur
        final aci = _kontrolcu.value * 6.28318;
        return widget.builder(context, aci);
      },
    );
  }
}
