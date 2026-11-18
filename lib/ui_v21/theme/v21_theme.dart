import 'package:flutter/material.dart';

import '../foundation/v21_colors.dart';
import '../foundation/v21_typography.dart';

/// V2.1 ekranları için Material teması.
///
/// Uygulamanın genel temasını (AppTheme.dark) DEĞİŞTİRMEZ; V2.1 ekranı
/// kendi alt ağacını `Theme(data: V21Theme.data(context))` ile sarar.
/// Böylece eski Ref ekranları aynen kalır.
abstract final class V21Theme {
  static ThemeData data(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      scaffoldBackgroundColor: V21Colors.inkDeep,
      colorScheme: base.colorScheme.copyWith(
        primary: V21Colors.goldTop,
        secondary: V21Colors.navActiveBorder,
        surface: V21Colors.panel,
        error: V21Colors.danger,
      ),
      textTheme: base.textTheme.apply(
        fontFamily: V21Type.body,
        bodyColor: V21Colors.text,
        displayColor: V21Colors.text,
      ),
      snackBarTheme: base.snackBarTheme.copyWith(
        backgroundColor: V21Colors.panel,
        contentTextStyle: V21Type.label(13),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
