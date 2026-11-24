import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';

import '../../ui_v21.dart';

/// V2.1 YÜKLEME EKRANI: tam ekran görsel + altta ilerleme çubuğu.
///
/// Telefonda görsel ekranı doldurur (yanlardan az kırpılır). Tablet gibi
/// görselden geniş ekranlarda logo ve top kesilmesin diye görselin tamamı
/// ortada gösterilir, kenarları görselin bulanık hâliyle dolar.
///
/// Yalnız görüntü: süre ve yönlendirme `SplashView`'de. [progress] 0→1 çubuğu
/// doldurur; kart animasyonları kapalıysa çağıran 1 verir.
class V21SplashArt extends StatelessWidget {
  final double progress;
  const V21SplashArt({super.key, required this.progress});

  static const double _gorselOrani = 380 / 679;

  /// Görselin alt kenar rengi (yerel açılış ekranıyla aynı)
  static const Color zemin = Color(0xFF0F1130);

  @override
  Widget build(BuildContext context) {
    final t = Curves.easeOut.transform(progress.clamp(0.0, 1.0));
    return Semantics(
      label: 'Futbol Card Arena yükleniyor',
      excludeSemantics: true,
      child: ColoredBox(
        color: zemin,
        child: LayoutBuilder(
          builder: (context, box) {
            final k = V21Scale.forSize(box.biggest).s;
            final genis = box.maxWidth / box.maxHeight > _gorselOrani + 0.02;
            return Stack(
              fit: StackFit.expand,
              children: [
                if (genis) ...[
                  ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: _gorsel(BoxFit.cover),
                  ),
                  const ColoredBox(color: Color(0x66000000)),
                ],
                _gorsel(genis ? BoxFit.contain : BoxFit.cover),
                SafeArea(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 18 * k),
                      child: SizedBox(
                        width: 230 * k,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'YÜKLENİYOR',
                              style: V21Type.title(15 * k, letterSpacing: 1.4, shadows: V21Type.inkShadow(k)),
                            ),
                            SizedBox(height: 6 * k),
                            Container(
                              height: 10 * k,
                              padding: EdgeInsets.all(2 * k),
                              decoration: BoxDecoration(
                                color: V21Colors.trackDark,
                                borderRadius: BorderRadius.circular(6 * k),
                                border: Border.all(color: V21Colors.goldEdge.withValues(alpha: 0.7)),
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  key: const Key('yukleme-cubugu'),
                                  widthFactor: t,
                                  heightFactor: 1,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(colors: [V21Colors.goldBottom, V21Colors.goldTop]),
                                      borderRadius: BorderRadius.circular(4 * k),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _gorsel(BoxFit fit) => Image.asset(
    V21Assets.loadingSplash,
    fit: fit,
    filterQuality: FilterQuality.medium,
    gaplessPlayback: true,
    excludeFromSemantics: true,
  );
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
