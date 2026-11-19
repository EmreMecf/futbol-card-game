import 'dart:math' as math;

import 'package:flutter/material.dart';

/// UYRUK BAYRAĞI — görsel dosyası olmadan, tamamen çizilerek.
///
/// -------------------------------------------------------------------
/// NEDEN PNG DEĞİL, NEDEN EMOJİ DEĞİL?
/// -------------------------------------------------------------------
/// PNG : 14 ülke için 14 dosya demek. Kart görselleri henüz hazır
///       değilken bayrak dosyaları eklemek, projeye bakım yükü olan
///       ama hiçbir şey öğretmeyen bir varlık klasörü katardı.
///
/// EMOJİ: 🇹🇷 gibi bayrak emojileri Windows'ta HİÇ çizilmiyor
///        (sistem yazı tipinde bölgesel bayraklar yok), Android'de
///        sürümden sürüme değişiyor. Masaüstünde test ederken iki harf
///        görürdük.
///
/// Çizim ise her yerde aynı görünür ve tek bir dosyada durur. Bayraklar
/// sadeleştirilmiştir (armalar yok); walkout'ta ekranda 1 saniye
/// duracak bir öğe için doğru ayrıntı seviyesi bu.
class NationFlag extends StatelessWidget {
  /// Üç harfli uyruk kodu: 'TUR', 'BRA', ...
  final String? code;

  final double width;

  const NationFlag({super.key, required this.code, this.width = 150});

  double get _height => width * 0.66;

  @override
  Widget build(BuildContext context) {
    final tanim = _FlagData.of(code);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: width,
          height: _height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: CustomPaint(
              painter: _FlagPainter(tanim),
              size: Size(width, _height),
            ),
          ),
        ),
        SizedBox(height: width * 0.07),
        Text(
          code ?? '—',
          style: TextStyle(
            color: Colors.white,
            fontSize: width * 0.14,
            fontWeight: FontWeight.w900,
            letterSpacing: width * 0.03,
            shadows: const [Shadow(color: Colors.black87, blurRadius: 8)],
          ),
        ),
      ],
    );
  }
}

// ====================================================================
// BAYRAK TANIMLARI
// ====================================================================
/// Bir bayrağın nasıl çizileceği.
///
/// Çoğu bayrak yatay ya da dikey bantlardan ibaret; onları tek bir
/// renk listesiyle tanımlıyoruz. Geri kalanı için birkaç "ek işaret"
/// yeterli oluyor (daire, hilal, haç, yıldız).
class _FlagData {
  final List<Color> bands;
  final bool vertical;
  final _Emblem emblem;
  final Color emblemColor;

  const _FlagData({
    required this.bands,
    this.vertical = false,
    this.emblem = _Emblem.none,
    this.emblemColor = Colors.white,
  });

  static const _kirmizi = Color(0xFFD32F2F);
  static const _beyaz = Color(0xFFF5F5F5);
  static const _mavi = Color(0xFF1A47B8);
  static const _yesil = Color(0xFF108B4C);
  static const _sari = Color(0xFFFFD100);
  static const _siyah = Color(0xFF16161A);

  /// Kod bilinmiyorsa nötr bir plaka döner; ekran boş kalmaz.
  static _FlagData of(String? code) {
    return switch (code?.toUpperCase()) {
      'TUR' => const _FlagData(
          bands: [_kirmizi],
          emblem: _Emblem.crescent,
        ),
      'BRA' => const _FlagData(
          bands: [_yesil],
          emblem: _Emblem.diamondDisc,
          emblemColor: _sari,
        ),
      'ESP' => const _FlagData(
          bands: [_kirmizi, _sari, _sari, _kirmizi],
        ),
      'GER' => const _FlagData(
          bands: [_siyah, _kirmizi, _sari],
        ),
      'FRA' => const _FlagData(
          bands: [_mavi, _beyaz, _kirmizi],
          vertical: true,
        ),
      'ITA' => const _FlagData(
          bands: [_yesil, _beyaz, _kirmizi],
          vertical: true,
        ),
      'ENG' => const _FlagData(
          bands: [_beyaz],
          emblem: _Emblem.cross,
          emblemColor: _kirmizi,
        ),
      'NED' => const _FlagData(
          bands: [_kirmizi, _beyaz, _mavi],
        ),
      'ARG' => const _FlagData(
          bands: [Color(0xFF74ACDF), _beyaz, Color(0xFF74ACDF)],
          emblem: _Emblem.disc,
          emblemColor: Color(0xFFF6B40E),
        ),
      'POR' => const _FlagData(
          bands: [_yesil, _yesil, _kirmizi, _kirmizi, _kirmizi],
          vertical: true,
          emblem: _Emblem.discLeft,
          emblemColor: _sari,
        ),
      'JPN' => const _FlagData(
          bands: [_beyaz],
          emblem: _Emblem.disc,
          emblemColor: Color(0xFFBC002D),
        ),
      'SEN' => const _FlagData(
          bands: [_yesil, _sari, _kirmizi],
          vertical: true,
          emblem: _Emblem.star,
          emblemColor: _yesil,
        ),
      'HUN' => const _FlagData(
          bands: [_kirmizi, _beyaz, _yesil],
        ),
      'RUS' => const _FlagData(
          bands: [_beyaz, _mavi, _kirmizi],
        ),
      _ => const _FlagData(
          bands: [Color(0xFF2A3550), Color(0xFF1B2337)],
        ),
    };
  }
}

enum _Emblem {
  none,

  /// Ortada daire (JPN, ARG güneşi)
  disc,

  /// Solda daire (POR)
  discLeft,

  /// Hilal + yıldız (TUR)
  crescent,

  /// Haç (ENG)
  cross,

  /// Sarı eşkenar dörtgen + mavi daire (BRA)
  diamondDisc,

  /// Ortada yıldız (SEN)
  star,
}

class _FlagPainter extends CustomPainter {
  final _FlagData data;

  _FlagPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final boya = Paint()..style = PaintingStyle.fill;

    // ---- BANTLAR ----
    final adet = data.bands.length;
    for (var i = 0; i < adet; i++) {
      boya.color = data.bands[i];
      final rect = data.vertical
          ? Rect.fromLTWH(size.width * i / adet, 0, size.width / adet + 0.5,
              size.height)
          : Rect.fromLTWH(0, size.height * i / adet, size.width,
              size.height / adet + 0.5);
      canvas.drawRect(rect, boya);
    }

    // ---- EK İŞARET ----
    final merkez = Offset(size.width / 2, size.height / 2);
    boya.color = data.emblemColor;

    switch (data.emblem) {
      case _Emblem.none:
        break;

      case _Emblem.disc:
        canvas.drawCircle(merkez, size.height * 0.22, boya);

      case _Emblem.discLeft:
        canvas.drawCircle(
          Offset(size.width * 0.40, merkez.dy),
          size.height * 0.18,
          boya,
        );

      case _Emblem.cross:
        final kalinlik = size.height * 0.18;
        canvas.drawRect(
          Rect.fromLTWH(0, merkez.dy - kalinlik / 2, size.width, kalinlik),
          boya,
        );
        canvas.drawRect(
          Rect.fromLTWH(merkez.dx - kalinlik / 2, 0, kalinlik, size.height),
          boya,
        );

      case _Emblem.crescent:
        // Hilal = büyük daire eksi kaydırılmış daire.
        // saveLayer + BlendMode.clear ile "delik açıyoruz".
        final yaricap = size.height * 0.24;
        canvas.saveLayer(Offset.zero & size, Paint());
        canvas.drawCircle(
          Offset(size.width * 0.36, merkez.dy),
          yaricap,
          boya,
        );
        canvas.drawCircle(
          Offset(size.width * 0.42, merkez.dy),
          yaricap * 0.82,
          Paint()..blendMode = BlendMode.clear,
        );
        canvas.restore();

        _yildiz(
          canvas,
          Offset(size.width * 0.56, merkez.dy),
          size.height * 0.13,
          boya,
        );

      case _Emblem.diamondDisc:
        final yol = Path()
          ..moveTo(merkez.dx, size.height * 0.12)
          ..lineTo(size.width * 0.88, merkez.dy)
          ..lineTo(merkez.dx, size.height * 0.88)
          ..lineTo(size.width * 0.12, merkez.dy)
          ..close();
        canvas.drawPath(yol, boya);
        canvas.drawCircle(
          merkez,
          size.height * 0.17,
          Paint()..color = const Color(0xFF012169),
        );

      case _Emblem.star:
        _yildiz(canvas, merkez, size.height * 0.20, boya);
    }
  }

  /// Beş köşeli yıldız
  void _yildiz(Canvas canvas, Offset merkez, double yaricap, Paint boya) {
    final yol = Path();
    const kose = 5;
    for (var i = 0; i < kose * 2; i++) {
      final r = i.isEven ? yaricap : yaricap * 0.42;
      final aci = -math.pi / 2 + i * math.pi / kose;
      final nokta = Offset(
        merkez.dx + math.cos(aci) * r,
        merkez.dy + math.sin(aci) * r,
      );
      i == 0 ? yol.moveTo(nokta.dx, nokta.dy) : yol.lineTo(nokta.dx, nokta.dy);
    }
    yol.close();
    canvas.drawPath(yol, boya);
  }

  @override
  bool shouldRepaint(_FlagPainter eski) => eski.data != data;
}
