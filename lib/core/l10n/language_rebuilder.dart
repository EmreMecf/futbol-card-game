import 'package:flutter/widgets.dart';

import 'app_language.dart';

/// Dil değişince altındaki BÜTÜN ekranı yeni dille yeniden çizer.
///
/// Metinler `.tr` ile okunduğu için Flutter'ın dil bağımlılığından
/// habersizdir: sabit (const) widget'lar kendiliğinden yeniden çizilmez.
/// Bu yüzden dil değişince alttaki her öğe elle "kirli" işaretlenir.
/// Açık sayfalar, kaydırma yerleri ve form içerikleri korunur (öğeler
/// yeniden kurulmaz, yalnız yeniden çizilir).
class LanguageRebuilder extends StatefulWidget {
  final Widget child;

  const LanguageRebuilder({super.key, required this.child});

  @override
  State<LanguageRebuilder> createState() => _LanguageRebuilderState();
}

class _LanguageRebuilderState extends State<LanguageRebuilder> {
  @override
  void initState() {
    super.initState();
    AppLanguageController.instance.addListener(_dilDegisti);
  }

  @override
  void dispose() {
    AppLanguageController.instance.removeListener(_dilDegisti);
    super.dispose();
  }

  void _dilDegisti() {
    if (!mounted) return;
    void kirlet(Element e) {
      e.markNeedsBuild();
      e.visitChildren(kirlet);
    }

    (context as Element).visitChildren(kirlet);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
