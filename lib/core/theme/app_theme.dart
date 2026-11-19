import 'package:flutter/material.dart';

import '../../ui_v21/animations/v21_card_motion.dart';
import '../../ui_v21/foundation/v21_colors.dart';
import '../../ui_v21/foundation/v21_typography.dart';

/// Uygulamanın Material teması: V2.1 renkleri ve yazı tipleri.
class AppTheme {
  const AppTheme._();

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: V21Colors.inkDeep,
      pageTransitionsTheme: V21PageTransitionsBuilder.theme,
      textTheme: base.textTheme.apply(
        fontFamily: V21Type.body,
        bodyColor: V21Colors.text,
        displayColor: V21Colors.text,
      ),
      primaryTextTheme: base.primaryTextTheme.apply(fontFamily: V21Type.body),
      colorScheme: const ColorScheme.dark(
        primary: V21Colors.goldTop,
        secondary: V21Colors.navActiveBorder,
        surface: V21Colors.panel,
        error: V21Colors.danger,
        onPrimary: V21Colors.ink,
        onSurface: V21Colors.text,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: V21Colors.panel,
        contentTextStyle: V21Type.label(13),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
