import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/auth/session_manager.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_typography.dart';

/// Ana sayfanın öğeleri.
///
/// NOT — TASARIMDAN BİLEREK ÇIKARILANLAR:
/// Tasarım tuvalinde "günlük ödül" ve "sezon geçidi" alanları vardı.
/// Sunucuda ikisinin de karşılığı yok. Uydurma bir "4. gün" ya da
/// "620/1000 sezon puanı" göstermek, oyuncuya yalan söylemek olurdu.
/// O alan yerine GERÇEK verinin durduğu [IstatistikKarti] konuldu.
/// Sunucuya günlük ödül eklendiğinde buraya yeni bir widget gelir.

// ====================================================================
// HIZLI MAÇ — ekranın ana çağrısı
// ====================================================================
class HizliMacKarti extends StatelessWidget {
  /// Telefonda daha kısa ve daha küçük yazılı hali kullanılır.
  final bool compact;

  const HizliMacKarti({super.key, this.compact = true});

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(compact ? 22 : 26),
      clipBehavior: Clip.antiAlias,
      color: AppColors.primaryDark,
      child: InkWell(
        onTap: () => context.go(AppRoutes.matchmaking),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(compact ? 22 : 26),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.32),
                blurRadius: 36,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: SizedBox(
            height: compact ? 176 : 264,
            child: Stack(
              children: [
                // Saha çizgileri: görsel dosyası değil, çizim.
                // Her ekran boyutunda net ve paket boyutuna etkisi sıfır.
                const Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: SahaCizgileriPainter()),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(compact ? 20 : 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'HIZLI MAÇ',
                            style: AppTypography.display(
                              size: compact ? 40 : 60,
                              weight: FontWeight.w900,
                              height: 0.95,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: compact ? 240 : 400,
                            ),
                            child: Text(
                              'Seninle yakın puanlı bir rakip bulunur. '
                              '${GameRules.squadSize} tur, tur başına '
                              '${GameRules.turnDuration.inSeconds} saniye.',
                              style: AppTypography.body(
                                size: compact ? 12.5 : 15,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          _BeyazButon(compact: compact),
                          const SizedBox(width: 12),
                          if (!compact)
                            Flexible(
                              child: Text(
                                'Kaybedersen korumasız '
                                '${GameRules.penaltyCardCount} kartın gider.',
                                style: AppTypography.body(
                                  size: 12.5,
                                  color: Colors.white.withValues(alpha: 0.75),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BeyazButon extends StatelessWidget {
  final bool compact;

  const _BeyazButon({required this.compact});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 46 : 54,
      padding: EdgeInsets.symmetric(horizontal: compact ? 22 : 30),
      decoration: BoxDecoration(
        color: AppColors.textPrimary,
        borderRadius: BorderRadius.circular(compact ? 14 : 16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.play_arrow_rounded,
            size: 22,
            color: AppColors.primaryDark,
          ),
          const SizedBox(width: 6),
          Text(
            'RAKİP BUL',
            style: AppTypography.display(
              size: compact ? 18 : 21,
              weight: FontWeight.w900,
              color: AppColors.primaryDark,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

/// Yeşil alanın üstündeki saha çizgileri.
class SahaCizgileriPainter extends CustomPainter {
  const SahaCizgileriPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final firca = Paint()
      ..color = Colors.white.withValues(alpha: 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final h = size.height;
    final w = size.width;
    final ust = h * 0.08;
    final alt = h * 0.92;

    // Dış çizgi taşacak şekilde çiziliyor: kart bir sahanın
    // ORTASINDAN kesilmiş parça gibi görünsün, minyatür bir saha gibi
    // değil. Sahayı kadraja sığdırmak ölçek hissini bozardı.
    canvas.drawRect(Rect.fromLTRB(-w * 0.1, ust, w * 1.1, alt), firca);

    // Orta çizgi ve santra dairesi
    canvas.drawLine(Offset(w / 2, ust), Offset(w / 2, alt), firca);
    canvas.drawCircle(Offset(w / 2, h / 2), h * 0.19, firca);

    // Ceza sahaları
    final cezaYuksek = h * 0.46;
    final cezaGenis = w * 0.19;
    canvas.drawRect(
      Rect.fromLTWH(-w * 0.1, (h - cezaYuksek) / 2, cezaGenis, cezaYuksek),
      firca,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        w * 1.1 - cezaGenis,
        (h - cezaYuksek) / 2,
        cezaGenis,
        cezaYuksek,
      ),
      firca,
    );
  }

  @override
  bool shouldRepaint(SahaCizgileriPainter oldDelegate) => false;
}

// ====================================================================
// İSTATİSTİK KARTI — gerçek veriyle
// ====================================================================
class IstatistikKarti extends StatelessWidget {
  const IstatistikKarti({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionManager>();
    final kullanici = session.user;

    final g = kullanici?.wins ?? 0;
    final m = kullanici?.losses ?? 0;
    final b = kullanici?.draws ?? 0;
    final toplam = g + m + b;
    final oran = toplam == 0 ? 0.0 : g / toplam;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('KARNEN', style: AppTypography.label),
              const SizedBox(height: 6),
              Text(
                toplam == 0 ? 'İlk maçın' : '$toplam maç',
                style: AppTypography.display(
                  size: 30,
                  weight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                toplam == 0
                    ? 'Rakip bul ve başla'
                    : '$g galibiyet · $m mağlubiyet · $b beraberlik',
                style: AppTypography.bodyS,
              ),
            ],
          ),

          // BOŞLUK NEDEN AÇIKÇA VERİLİYOR?
          // spaceBetween yalnızca Column'a fazladan yükseklik
          // verildiğinde işe yarar. Masaüstünde kart yanındaki hızlı
          // maç alanına göre uzuyor ve boşluk kendiliğinden oluşuyor;
          // telefonda ise kart içeriğe göre küçülüyor ve üç blok
          // birbirine yapışıyordu.
          const SizedBox(height: 20),

          // ---- KAZANMA ORANI ----
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Kazanma oranı',
                    style: AppTypography.body(
                      size: 12,
                      weight: FontWeight.w800,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    toplam == 0 ? '—' : '%${(oran * 100).round()}',
                    style: AppTypography.display(
                      size: 16,
                      weight: FontWeight.w900,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: oran,
                  minHeight: 8,
                  backgroundColor: AppColors.surfaceLight,
                  valueColor: const AlwaysStoppedAnimation(AppColors.success),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ---- KORUMA HAKKI ----
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.shield_rounded,
                  size: 18,
                  color: AppColors.tierDiamond,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Koruma hakkın',
                        style: AppTypography.body(
                          size: 12.5,
                          weight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Her galibiyette 1 artar',
                        style: AppTypography.bodyXS,
                      ),
                    ],
                  ),
                ),
                Text(
                  '${session.protectionSlots}',
                  style: AppTypography.display(
                    size: 20,
                    weight: FontWeight.w900,
                    color: AppColors.tierDiamond,
                  ),
                ),
                Text(
                  '/${GameRules.maxProtectionSlots}',
                  style: AppTypography.display(
                    size: 14,
                    weight: FontWeight.w700,
                    color: AppColors.textSecondary,
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

// ====================================================================
// MENÜ KAROSU
// ====================================================================
class MenuKarosu extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const MenuKarosu({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.surfaceLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 26, color: iconColor),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.h3,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyXS,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
