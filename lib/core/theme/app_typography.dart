import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Uygulamanin yazi tipi olcegi.
///
/// ===================================================================
/// IKI AILE, IKI GOREV
/// ===================================================================
/// [display] -> Barlow Condensed. Dar ve guclu. Kart gucu, skor, sayac,
///              baslik ve buton yazilari. Rakamlari dar oldugu icin
///              "97" degeri 200px genisligindeki karta rahat siger ve
///              ekranin en cok bakilan sayisi guclu gorunur.
///
/// [body]    -> Nunito. Yumusak koseli, uzun metinde yormaz. Aciklama,
///              etiket ve ikincil bilgiler.
///
/// ===================================================================
/// NEDEN fontVariations DA YAZILIYOR?
/// ===================================================================
/// Nunito DEGISKEN (variable) bir font: tek dosya icinde 200-1000
/// arasi tum agirliklari tasiyor. Flutter'da bu tur fontlarda sadece
/// `fontWeight` vermek her platformda calismiyor; bazi platformlarda
/// yazi hep tek agirlikta ciziliyor. Guvenilir yol `fontVariations`
/// ile 'wght' eksenini acikca belirtmek.
///
/// Ikisi birden yaziliyor: fontVariations degiskeni surer,
/// fontWeight ise font yuklenemezse devreye giren sistem yazi tipini
/// dogru kalinlikta gosterir.
class AppTypography {
  const AppTypography._();

  static const String displayFamily = 'BarlowCondensed';
  static const String bodyFamily = 'Nunito';

  /// Font yuklenemezse devreye girecek aileler.
  /// Barlow Condensed dar oldugu icin yedegi de dar bir aile olmali;
  /// yoksa kart gucu tasar.
  static const List<String> _displayFallback = [
    'Arial Narrow',
    'Roboto Condensed',
    'sans-serif',
  ];
  static const List<String> _bodyFallback = ['Roboto', 'sans-serif'];

  // ==================================================================
  // TEMEL URETICILER
  // ==================================================================

  /// Barlow Condensed ile bir stil uretir (baslik, rakam, buton).
  static TextStyle display({
    required double size,
    FontWeight weight = FontWeight.w800,
    Color color = AppColors.textPrimary,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: displayFamily,
      fontFamilyFallback: _displayFallback,
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Nunito ile bir stil uretir (metin, etiket).
  static TextStyle body({
    required double size,
    FontWeight weight = FontWeight.w700,
    Color color = AppColors.textPrimary,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: bodyFamily,
      fontFamilyFallback: _bodyFallback,
      fontSize: size,
      fontWeight: weight,
      // Degisken fontun agirlik ekseni. Bkz. sinif aciklamasi.
      fontVariations: [FontVariation('wght', weight.value.toDouble())],
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  // ==================================================================
  // HAZIR OLCEK
  // ==================================================================
  // Tasarim tuvalindeki degerlerle birebir. Yeni bir boyut gerekiyorsa
  // once buraya eklenmeli; ekranlarda serbest sayi yazilmamali.

  /// Kart uzerindeki guc degeri. Ekranin en buyuk sayisi.
  static TextStyle get cardPower =>
      display(size: 52, weight: FontWeight.w900, height: 0.88);

  /// Ekran basligi: "HIZLI MAC"
  static TextStyle get h1 => display(
        size: 44,
        weight: FontWeight.w900,
        height: 0.95,
        letterSpacing: 0.5,
      );

  /// Bolum basligi
  static TextStyle get h2 =>
      display(size: 30, weight: FontWeight.w900, height: 1.0);

  /// Karo basligi: "MAGAZA", "GOREVLER"
  static TextStyle get h3 =>
      display(size: 20, weight: FontWeight.w800, letterSpacing: 0.5);

  /// Buyuk sayi: skor, sayac
  static TextStyle get numeric =>
      display(size: 30, weight: FontWeight.w900, height: 1.0);

  /// Buton yazisi
  static TextStyle get button =>
      display(size: 18, weight: FontWeight.w900, letterSpacing: 1.0);

  /// Kucuk buyuk-harf etiket: "TUR 6/11", "MASADA"
  static TextStyle get label => display(
        size: 12,
        weight: FontWeight.w800,
        color: AppColors.textSecondary,
        letterSpacing: 1.0,
      );

  /// Normal metin
  static TextStyle get bodyM => body(size: 14);

  /// Ikincil metin
  static TextStyle get bodyS =>
      body(size: 12, color: AppColors.textSecondary);

  /// En kucuk metin (karo alt bilgisi)
  static TextStyle get bodyXS =>
      body(size: 11, color: AppColors.textSecondary);

  /// Vurgulu isim: kullanici adi, kart adi
  static TextStyle get name => body(size: 15, weight: FontWeight.w800);
}
