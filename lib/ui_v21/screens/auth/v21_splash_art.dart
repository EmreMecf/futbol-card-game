import 'package:flutter/material.dart';

import '../../ui_v21.dart';

/// V2.1 AÇILIŞ GÖRSELİ (giriş referansının üst yarısı; login.png).
///
///          FUTBOL
///        CARD ARENA        ← logo kodla çizilir
///     (üç kahraman, stadyum)
///            ◌             ← yükleniyor
///
/// Yalnız görüntü: yönlendirme ve süre `SplashView`'de (900 ms) değişmedi.
/// [progress] 0→1: logo büyüyerek, kahramanlar aşağıdan gelir. Kart
/// animasyonları kapalıysa çağıran 1 verir (son hâl).
class V21SplashArt extends StatelessWidget {
  final double progress;
  const V21SplashArt({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final t = progress.clamp(0.0, 1.0);
    final logoT = Curves.easeOutBack.transform(((t - 0.2) / 0.8).clamp(0.0, 1.0));
    final heroT = Curves.easeOutCubic.transform((t / 0.7).clamp(0.0, 1.0));
    return Semantics(
      label: 'Futbol Card Arena yükleniyor',
      child: ColoredBox(
        color: const Color(0xFF120830),
        child: LayoutBuilder(
          builder: (context, box) {
            final k = V21Scale.forSize(box.biggest).s;
            final w = box.maxWidth.clamp(0.0, V21Metrics.maxContentWidth * k * 1.2);
            return Stack(
              fit: StackFit.expand,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF3A1C8E), Color(0xFF221060), Color(0xFF120830)],
                      stops: [0, 0.55, 1],
                    ),
                  ),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      SizedBox(height: 28 * k),
                      Opacity(
                        opacity: logoT.clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: 0.82 + 0.18 * logoT,
                          child: V21Logo(scale: k),
                        ),
                      ),
                      SizedBox(height: 12 * k),
                      Expanded(
                        child: Align(
                          alignment: const Alignment(0, -0.5),
                          child: Opacity(
                            opacity: heroT,
                            child: Transform.translate(
                              offset: Offset(0, 40 * k * (1 - heroT)),
                              child: SizedBox(
                                width: w,
                                child: ShaderMask(
                                  // Alt kenar zemine yumuşakça kaybolur
                                  blendMode: BlendMode.dstIn,
                                  shaderCallback: (r) => const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
                                    stops: [0, 0.14, 0.78, 1],
                                  ).createShader(r),
                                  child: Image.asset(
                                    V21Assets.loginHeroes,
                                    fit: BoxFit.fitWidth,
                                    filterQuality: FilterQuality.medium,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 30 * k,
                        height: 30 * k,
                        child: CircularProgressIndicator(strokeWidth: 3.2 * k, color: V21Colors.goldTop),
                      ),
                      SizedBox(height: 40 * k),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// "FUTBOL / CARD ARENA" logosu (referans giriş ekranı: beyaz + altın,
/// kalın mürekkep gölgesi). Giriş ekranı da kullanabilir.
class V21Logo extends StatelessWidget {
  final double scale;
  const V21Logo({super.key, this.scale = 1});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    return ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('FUTBOL', style: V21Type.title(58 * k, height: 1, shadows: V21Type.inkShadow(k * 1.4))),
          V21HeroTitle('CARD ARENA', size: 46 * k),
        ],
      ),
    );
  }
}
