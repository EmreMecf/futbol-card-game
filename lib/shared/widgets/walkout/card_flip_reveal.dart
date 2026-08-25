import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_models/shared_models.dart';

import '../../../features/store/domain/reveal_style.dart';
import '../premium_card/premium_card.dart';

/// BASİT VE ALTIN AÇILIŞ — kartın dönerek (flip) açılması.
///
/// -------------------------------------------------------------------
/// 3B DÖNDÜRME NASIL ÇALIŞIYOR?
/// -------------------------------------------------------------------
/// Kart Y ekseni etrafında 180° dönüyor. Dönerken:
///   0° -  90°  -> kartın ARKASI görünür
///  90° - 180°  -> kartın ÖNÜ görünür
///
/// 90°'yi geçtikten sonra ön yüzü DÜZ göstermek için `rotateY(pi)`
/// ile bir kez daha çeviriyoruz; yoksa kart aynadaki gibi ters
/// görünürdü. Bu, flip animasyonlarında en sık yapılan hatadır.
///
/// `setEntry(3, 2, 0.0012)` satırı perspektif katsayısı. Olmadan kart
/// dönerken derinlik hissi vermez, sadece yatayda ezilir.
///
/// -------------------------------------------------------------------
/// SÜRE FARKI NEDEN ÖNEMLİ?
/// -------------------------------------------------------------------
/// Bronz/Gümüş 350 ms, Altın 750 ms. Oyuncu bu farkı bilinçli olarak
/// fark etmez ama HİSSEDER: kart yavaşladığında "bir şey çıktı"
/// beklentisi doğar. Görkem, sürenin kendisinden değil, alışılmış
/// süreden SAPMASINDAN gelir.
class CardFlipReveal extends StatefulWidget {
  final InventoryCard card;
  final RevealStyle style;
  final double width;

  const CardFlipReveal({
    super.key,
    required this.card,
    required this.style,
    this.width = 210,
  });

  @override
  State<CardFlipReveal> createState() => _CardFlipRevealState();
}

class _CardFlipRevealState extends State<CardFlipReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _kontrolcu = AnimationController(
    vsync: this,
    duration: widget.style.flipDuration,
  );

  bool _titredi = false;

  CardTierTheme get _tema => CardTierTheme.of(widget.card.tier);

  @override
  void initState() {
    super.initState();
    _kontrolcu.addListener(_yariyiGecti);
    _kontrolcu.forward();
  }

  /// Kartın ön yüzü göründüğü anda titreşim.
  ///
  /// Titreşimi animasyonun BAŞINDA vermek yanlış olurdu: geri bildirim,
  /// olayın kendisiyle aynı karede olmalı. Göz "kart açıldı" derken
  /// parmak da aynı anda hissetmeli.
  void _yariyiGecti() {
    if (_titredi || _kontrolcu.value < 0.5) return;
    _titredi = true;

    switch (widget.style.haptic) {
      case HapticStrength.none:
        break;
      case HapticStrength.light:
        HapticFeedback.lightImpact();
      case HapticStrength.heavy:
        HapticFeedback.heavyImpact();
    }
  }

  @override
  void dispose() {
    _kontrolcu.removeListener(_yariyiGecti);
    _kontrolcu.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _kontrolcu,
        // Ön yüz bir kez kuruluyor; her karede yeniden kurmak kartın
        // kendi animasyonlarını baştan başlatırdı.
        child: PremiumPlayerCard.fromInventory(
          widget.card,
          width: widget.width,
          // Dönme bitene kadar etkileşim kapalı; iki Transform'un
          // birbirine karışmaması için.
          interactive: false,
        ),
        builder: (context, onYuz) {
          final t = Curves.easeInOutCubic.transform(_kontrolcu.value);
          final aci = t * math.pi;
          final onYuzGorunur = t >= 0.5;

          final matris = Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(aci);

          // 90°'yi geçtiysek ön yüzü bir kez daha çevir ki ters
          // görünmesin.
          if (onYuzGorunur) matris.rotateY(math.pi);

          return Transform(
            alignment: Alignment.center,
            transform: matris,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Altın ve üstünde kart açılırken arkadan bir parlama
                if (widget.style != RevealStyle.simple && onYuzGorunur)
                  _parlama(t),

                onYuzGorunur
                    ? onYuz!
                    : _ArkaYuz(width: widget.width, theme: _tema),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Kart açılırken arkadan yayılan ışık. Süresi kısa; kart tam
  /// göründüğünde sönmüş oluyor.
  Widget _parlama(double t) {
    final siddet = ((t - 0.5) / 0.35).clamp(0.0, 1.0) * (1 - (t - 0.5) / 0.5);

    return IgnorePointer(
      child: Container(
        width: widget.width * 1.5,
        height: widget.width * 1.5,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              _tema.frameGradient[1].withValues(alpha: 0.55 * siddet),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

/// KARTIN ARKA YÜZÜ
///
/// Ön yüzle aynı siluete sahip olması şart: dönerken kenar çizgisi
/// değişirse göz "iki ayrı nesne" olarak algılar ve dönme yanılsaması
/// bozulur.
class _ArkaYuz extends StatelessWidget {
  final double width;
  final CardTierTheme theme;

  const _ArkaYuz({required this.width, required this.theme});

  @override
  Widget build(BuildContext context) {
    final yukseklik = width / 0.70; // kartla aynı en-boy oranı

    return Container(
      width: width,
      height: yukseklik,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(width * 0.09),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF16203A), Color(0xFF0A1024), Color(0xFF1B2748)],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.sports_soccer,
          size: width * 0.38,
          color: Colors.white.withValues(alpha: 0.13),
        ),
      ),
    );
  }
}
