import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'app_tokens.dart';
import 'app_typography.dart';
import 'ref_tokens.dart';

/// Uygulamanin gorsel kimligi.
/// Oyun karanlik tema uzerine kuruludur (stadyum gece atmosferi).
class AppTheme {
  const AppTheme._();

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,

      // ThemeData.copyWith fontFamily KABUL ETMEZ (sadece yapici alir).
      // Bu yuzden aile, metin olceginin her satirina tek tek yaziliyor.
      // primaryTextTheme de ayni olcege baglaniyor; aksi halde koyu
      // zemin uzerindeki bazi Material widget'lari sistem yazi tipiyle
      // cizilirdi.
      textTheme: _metinTemasi(base.textTheme),
      primaryTextTheme: _metinTemasi(base.primaryTextTheme),
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surface,
        error: AppColors.danger,
        // Emerald ustunde beyaz yazi okunmaz (kontrast 2.54).
        onPrimary: AppColors.onPrimary,
        tertiary: AppColors.gold,
        onSurface: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: AppTypography.displayFamily,
          color: AppColors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          // Beyaz DEGIL: bkz. AppColors sinif aciklamasi (kontrast)
          foregroundColor: AppColors.onPrimary,
          disabledBackgroundColor: AppColors.surfaceLight,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(
            fontFamily: AppTypography.displayFamily,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppColors.surfaceLight, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(
            fontFamily: AppTypography.displayFamily,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
      ),
      // FAZ 8: giriş alanı = referans .search (#111e31 zemin, #344a65
      // kenar, 10px köşe); odakta --accent.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Ref.searchBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Ref.searchBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Ref.searchBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Ref.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Ref.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Ref.red, width: 1.5),
        ),
        prefixIconColor: Ref.muted,
        suffixIconColor: Ref.muted,
        hintStyle: const TextStyle(color: Ref.muted),
        labelStyle: const TextStyle(color: Ref.muted),
        errorStyle: const TextStyle(color: Ref.red),
      ),
      // Pencereler: referans modal (.modal-content)
      dialogTheme: DialogThemeData(
        backgroundColor: Ref.modalBg,
        surfaceTintColor: Colors.transparent,
        barrierColor: Ref.modalBack,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(21),
          side: const BorderSide(color: Ref.modalBorder),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Ref.modalBg,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: Ref.modalBack,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Ref.panel2,
        contentTextStyle: const TextStyle(color: Ref.text, fontFamily: AppTypography.bodyFamily),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Ref.cardPanelBorder),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: Ref.accent, linearTrackColor: Ref.barTrack),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((d) => d.contains(WidgetState.selected) ? Ref.bg : Ref.muted),
        trackColor: WidgetStateProperty.resolveWith((d) => d.contains(WidgetState.selected) ? Ref.accent : Ref.barTrack),
        trackOutlineColor: const WidgetStatePropertyAll(Ref.cardPanelBorder),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.surfaceLight,
        thickness: 1,
      ),
    );
  }

  /// Material'in hazir metin olcegini uygulamanin ailelerine cevirir.
  ///
  /// Buyuk basliklar Barlow Condensed'e, gerisi Nunito'ya gidiyor.
  /// Bu sayede `Theme.of(context).textTheme` kullanan hazir Material
  /// widget'lari da (AlertDialog, ListTile, SnackBar) dogru yazi
  /// tipiyle ciziliyor; her birine tek tek stil vermek gerekmiyor.
  static TextTheme _metinTemasi(TextTheme temel) {
    TextStyle? d(TextStyle? s, FontWeight w) =>
        s?.copyWith(fontFamily: AppTypography.displayFamily, fontWeight: w);
    TextStyle? b(TextStyle? s) =>
        s?.copyWith(fontFamily: AppTypography.bodyFamily);

    return temel.copyWith(
      displayLarge: d(temel.displayLarge, FontWeight.w900),
      displayMedium: d(temel.displayMedium, FontWeight.w900),
      displaySmall: d(temel.displaySmall, FontWeight.w900),
      headlineLarge: d(temel.headlineLarge, FontWeight.w900),
      headlineMedium: d(temel.headlineMedium, FontWeight.w800),
      headlineSmall: d(temel.headlineSmall, FontWeight.w800),
      titleLarge: d(temel.titleLarge, FontWeight.w800),
      titleMedium: b(temel.titleMedium),
      titleSmall: b(temel.titleSmall),
      bodyLarge: b(temel.bodyLarge),
      bodyMedium: b(temel.bodyMedium),
      bodySmall: b(temel.bodySmall),
      labelLarge: d(temel.labelLarge, FontWeight.w800),
      labelMedium: b(temel.labelMedium),
      labelSmall: b(temel.labelSmall),
    );
  }
}
