import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/premium_card/premium_card.dart';

// ====================================================================
// ELDEKİ KART
// ====================================================================

/// Elindeki tek bir kart: premium kart + kimya rozeti + oynanabilirlik.
///
/// ===================================================================
/// KİMYA ROZETİ NEDEN BURADA?
/// ===================================================================
/// Kartın turu kazanıp kazanmayacağını `güç + kimya` belirliyor.
/// Kimya bonusu daha önce hiçbir yerde gösterilmiyordu; oyuncu 83
/// güçlü kartını oynayıp 86 gibi davrandığını göremiyordu. Bu, oyunun
/// en önemli mekaniğini görünmez kılıyordu.
///
/// Rozet kartın SAĞ ÜST köşesinde duruyor ve seçili kartta altında
/// "MAÇTA 86" yazıyor: oyuncu kararını verirken gerçek gücü görüyor.
class HandCardTile extends StatelessWidget {
  final HandCard card;

  /// Bu tur oynanabilir mi? (zorunlu pozisyona uyuyor mu)
  final bool isPlayable;

  /// Şu an seçili mi? Seçili kart büyür ve öne çıkar.
  final bool isSelected;

  /// Dokunma etkin mi? (sıra bende ve hamle gönderilmiyor)
  final bool isEnabled;

  final VoidCallback? onTap;
  final double width;

  const HandCardTile({
    super.key,
    required this.card,
    required this.isPlayable,
    required this.width,
    this.isSelected = false,
    this.isEnabled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final vurgu = isSelected ? AppColors.success : Colors.transparent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      // Seçili kart yukarı kalkar: elde hangi kartın oynanacağı
      // metin okumadan anlaşılır.
      transform: Matrix4.translationValues(0, isSelected ? -14 : 0, 0),
      child: Opacity(
        // Oynanamayan kartlar silinmiyor, soluklaşıyor. Oyuncunun
        // elinde ne olduğunu görmesi taktik için gerekli.
        opacity: isPlayable ? 1.0 : 0.42,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(width * 0.115),
                border: Border.all(
                  color: vurgu,
                  width: isSelected ? 2.5 : 0,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.success.withValues(alpha: 0.45),
                          blurRadius: 26,
                        ),
                      ]
                    : null,
              ),
              child: PremiumPlayerCard.fromHand(
                card,
                width: width,
                interactive: isEnabled,
                onTap: isEnabled ? onTap : null,
              ),
            ),

            // ---- KİMYA ROZETİ ----
            if (card.hasChemistry)
              Positioned(
                top: -9,
                right: -6,
                child: _KimyaRozeti(chemistry: card.chemistry),
              ),

            // ---- SEÇİLİ KARTTA GERÇEK GÜÇ ----
            if (isSelected && card.hasChemistry)
              Positioned(
                bottom: 6,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'MAÇTA ${card.effectivePower}',
                      style: AppTypography.display(
                        size: 12,
                        weight: FontWeight.w900,
                        color: AppColors.success,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Kartın köşesindeki "+3" rozeti.
class _KimyaRozeti extends StatelessWidget {
  final int chemistry;

  const _KimyaRozeti({required this.chemistry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.success,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        '+$chemistry',
        style: AppTypography.display(
          size: 13,
          weight: FontWeight.w900,
          color: AppColors.background,
        ),
      ),
    );
  }
}

// ====================================================================
// SAYAÇ HALKASI
// ====================================================================

/// Dairesel tur sayacı.
///
/// Çubuk yerine halka: masanın ortasında durduğu için kalan süre
/// karta bakarken çevresel görüşle de algılanıyor. Son 10 saniyede
/// kırmızıya döner.
class TurnRing extends StatelessWidget {
  final Duration remaining;
  final bool isMyTurn;
  final bool isUrgent;
  final double size;

  const TurnRing({
    super.key,
    required this.remaining,
    required this.isMyTurn,
    required this.isUrgent,
    this.size = 92,
  });

  @override
  Widget build(BuildContext context) {
    final toplam = GameRules.turnDuration.inMilliseconds;
    final kalan = remaining.inMilliseconds.clamp(0, toplam);
    final oran = toplam == 0 ? 0.0 : kalan / toplam;

    final renk = !isMyTurn
        ? AppColors.textSecondary
        : isUrgent
            ? AppColors.danger
            : AppColors.success;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CustomPaint(
              painter: _HalkaPainter(progress: oran, color: renk),
            ),
          ),
          Container(
            width: size * 0.8,
            height: size * 0.8,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surfaceLight),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${remaining.inSeconds.clamp(0, 999)}',
                  style: AppTypography.display(
                    size: size * 0.33,
                    weight: FontWeight.w900,
                    height: 1.0,
                    color: renk,
                  ),
                ),
                Text(
                  'SANİYE',
                  style: AppTypography.display(
                    size: size * 0.11,
                    weight: FontWeight.w800,
                    color: AppColors.textSecondary,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HalkaPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _HalkaPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final kalinlik = size.width * 0.065;
    final yaricap = (size.width - kalinlik) / 2;
    final merkez = Offset(size.width / 2, size.height / 2);

    canvas.drawCircle(
      merkez,
      yaricap,
      Paint()
        ..color = AppColors.surfaceLight
        ..style = PaintingStyle.stroke
        ..strokeWidth = kalinlik,
    );

    if (progress <= 0) return;

    // Saat 12'den başlayıp saat yönünde azalır.
    canvas.drawArc(
      Rect.fromCircle(center: merkez, radius: yaricap),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = kalinlik
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_HalkaPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

// ====================================================================
// KAPALI KART (rakibin eli / oynadığı kart)
// ====================================================================

/// Rakibin görmediğimiz kartı.
///
/// Rakibin eli sunucudan hiçbir zaman gelmiyor; bu widget sadece
/// "orada bir kart var" bilgisini çiziyor.
class FaceDownCard extends StatelessWidget {
  final double width;
  final String? label;

  const FaceDownCard({super.key, required this.width, this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: width * 1.5,
      padding: EdgeInsets.all(width * 0.035),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.surfaceLight, AppColors.sidebar],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(width * 0.115),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(width * 0.085),
          border: Border.all(color: AppColors.surfaceLight),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sports_soccer,
              size: width * 0.34,
              color: AppColors.primary.withValues(alpha: 0.55),
            ),

            // DAR KARTTA ETİKET GİZLENİR.
            // 90px'in altında "Bekleniyor" iki satıra bölünüp
            // "Bekleni / yor" diye kırılıyordu. Simge zaten kartın
            // kapalı olduğunu anlatıyor; bölünmüş yazı bilgi değil
            // gürültü katıyor.
            if (label != null && width >= 90) ...[
              SizedBox(height: width * 0.08),
              Text(
                label!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyXS,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// BOŞ OYNAMA YUVASI
// ====================================================================

/// "Kartını buraya oyna" kesikli çerçevesi.
class EmptyPlaySlot extends StatelessWidget {
  final double width;
  final String message;
  final bool isActive;

  const EmptyPlaySlot({
    super.key,
    required this.width,
    required this.message,
    this.isActive = true,
  });

  @override
  Widget build(BuildContext context) {
    final renk = isActive ? AppColors.success : AppColors.textSecondary;

    return Container(
      width: width,
      height: width * 1.5,
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(width * 0.115),
        border: Border.all(
          color: renk.withValues(alpha: 0.55),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_rounded, size: width * 0.2, color: renk),
          SizedBox(height: width * 0.06),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: width * 0.08),
            child: Text(
              message,
              textAlign: TextAlign.center,
              // İKİ SATIRLA SINIRLI, TAŞARSA KISALTILIR.
              // Sınırsız bırakıldığında dar kartta "Sıra rakipte"
              // kelimenin ortasından bölünüp "rakipt / e" oluyordu.
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body(
                // Yazı kartla birlikte küçülür; 11.5 punto 72px'lik
                // bir yuvada taşıyordu.
                size: (width * 0.105).clamp(9.0, 12.0),
                weight: FontWeight.w800,
                color: renk,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// OYNANMIŞ KART (masadaki)
// ====================================================================

/// Masaya çıkmış bir hamlenin kartı.
class PlayedMoveCard extends StatelessWidget {
  final MatchMove move;
  final double width;

  /// Turu bu kart kazandıysa yeşil çerçeve alır.
  final bool isWinner;

  const PlayedMoveCard({
    super.key,
    required this.move,
    required this.width,
    this.isWinner = false,
  });

  @override
  Widget build(BuildContext context) {
    if (move.isPass || move.position == null || move.tier == null) {
      return _PasKarti(width: width);
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(width * 0.115),
        border: Border.all(
          color: isWinner ? AppColors.success : Colors.transparent,
          width: isWinner ? 2.5 : 0,
        ),
        boxShadow: isWinner
            ? [
                BoxShadow(
                  color: AppColors.success.withValues(alpha: 0.4),
                  blurRadius: 24,
                ),
              ]
            : null,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          PremiumPlayerCard(
            fullName: move.fullName ?? 'Kart',
            position: move.position!,
            tier: move.tier!,
            power: move.power ?? 0,
            imageUrl: move.imageUrl,
            width: width,
            interactive: false,
          ),
          if (move.chemistry > 0)
            Positioned(
              top: -9,
              right: -6,
              child: _KimyaRozeti(chemistry: move.chemistry),
            ),
        ],
      ),
    );
  }
}

class _PasKarti extends StatelessWidget {
  final double width;

  const _PasKarti({required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: width * 1.5,
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(width * 0.115),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.45)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.block_rounded,
            size: width * 0.24,
            color: AppColors.danger,
          ),
          SizedBox(height: width * 0.06),
          Text(
            'PAS GEÇTİ',
            style: AppTypography.display(
              size: 13,
              weight: FontWeight.w900,
              color: AppColors.danger,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
