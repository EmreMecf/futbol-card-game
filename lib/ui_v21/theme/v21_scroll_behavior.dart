import 'dart:ui' show PointerDeviceKind;

import 'package:material_ui/material_ui.dart';

/// Web ve masaüstünde yatay listeler fareyle de sürüklenebilsin.
class V21ScrollBehavior extends MaterialScrollBehavior {
  const V21ScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
  };
}
