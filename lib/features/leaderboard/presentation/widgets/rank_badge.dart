import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Lig rengini `#RRGGBB` metninden çözer.
///
/// Renkler veritabanında duruyor ki yeni bir lig eklendiğinde ya da
/// bir rengin tonu değiştirilmek istendiğinde uygulama yeniden
/// yayınlanmasın. Metin bozuksa sessizce nötr griye düşülüyor;
/// bir renk yüzünden ekranın çökmesi kabul edilemez.
Color leagueColor(String hex) {
  var metin = hex.trim().replaceFirst('#', '');
  if (metin.length == 6) metin = 'FF$metin';
  final deger = int.tryParse(metin, radix: 16);
  if (deger == null) return AppColors.textSecondary;
  return Color(deger);
}

/// Lig rozeti: kalkan biçiminde, içinde seviye numarası.
///
/// ===================================================================
/// NEDEN KART SEVİYELERİNDEN FARKLI BİR BİÇİM?
/// ===================================================================
/// Kartlar dikdörtgen ve metal/taş renkleri kullanıyor (bronz, gümüş,
/// altın, elmas, mor). Lig rozeti KALKAN biçiminde ve tamamen ayrı
/// bir palet kullanıyor.
///
/// İkisi aynı görünseydi oyuncu "Altın lig" ile "Altın kart"ı
/// karıştırırdı; biri oyuncunun becerisi, diğeri elindeki kartın
/// gücü. Bunlar birbirinden bağımsız iki şey.
class RankBadge extends StatelessWidget {
  final String leagueName;
  final int division;
  final String colorHex;
  final double size;

  /// Rozetin yanında lig adını da yaz
  final bool showLabel;

  const RankBadge({
    super.key,
    required this.leagueName,
    required this.division,
    required this.colorHex,
    this.size = 44,
    this.showLabel = false,
  });

  /// Oyuncunun kendi rütbesinden
  factory RankBadge.fromRank(
    PlayerRank rank, {
    double size = 44,
    bool showLabel = false,
  }) =>
      RankBadge(
        leagueName: rank.leagueName,
        division: rank.division,
        colorHex: rank.color,
        size: size,
        showLabel: showLabel,
      );

  /// Liderlik tablosu satırından
  factory RankBadge.fromEntry(
    LeaderboardEntry entry, {
    double size = 34,
    bool showLabel = false,
  }) =>
      RankBadge(
        leagueName: entry.leagueName,
        division: entry.division,
        colorHex: entry.color,
        size: size,
        showLabel: showLabel,
      );

  @override
  Widget build(BuildContext context) {
    final renk = leagueColor(colorHex);

    final rozet = SizedBox(
      width: size,
      height: size * 1.12,
      child: CustomPaint(
        painter: _KalkanPainter(color: renk),
        child: Center(
          child: Padding(
            // Kalkanın alt ucu sivri; numara biraz yukarıda dursun
            padding: EdgeInsets.only(bottom: size * 0.12),
            child: Text(
              '$division',
              style: AppTypography.display(
                size: size * 0.46,
                weight: FontWeight.w900,
                color: AppColors.background,
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
    );

    if (!showLabel) return rozet;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        rozet,
        SizedBox(width: size * 0.24),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                leagueName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.display(
                  size: size * 0.42,
                  weight: FontWeight.w900,
                  color: renk,
                  height: 1.05,
                ),
              ),
              Text(
                'Seviye $division',
                style: AppTypography.body(
                  size: size * 0.24,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Kalkan biçimi: üstü düz, altı sivri.
class _KalkanPainter extends CustomPainter {
  final Color color;

  const _KalkanPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = w * 0.16;

    final yol = Path()
      ..moveTo(r, 0)
      ..lineTo(w - r, 0)
      ..quadraticBezierTo(w, 0, w, r)
      ..lineTo(w, h * 0.58)
      // Alt uca inen iki yay: kalkanın sivri burnu
      ..quadraticBezierTo(w, h * 0.86, w / 2, h)
      ..quadraticBezierTo(0, h * 0.86, 0, h * 0.58)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..close();

    // Dış ışık: rozet zeminden ayrılsın
    canvas.drawPath(
      yol,
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.14),
    );

    canvas.drawPath(
      yol,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Color.lerp(color, Colors.white, 0.28)!,
            color,
            Color.lerp(color, Colors.black, 0.22)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Üstten gelen parlama
    canvas.save();
    canvas.clipPath(yol);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h * 0.45),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.32),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h * 0.45)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_KalkanPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Rütbe kartı: rozet, lig adı ve bir sonraki basamağa ilerleme.
///
/// Profil ve liderlik ekranlarının üstünde duruyor.
class RankProgressCard extends StatelessWidget {
  final PlayerRank rank;

  /// Liderlik tablosundaki sıra (varsa)
  final int? position;

  const RankProgressCard({super.key, required this.rank, this.position});

  @override
  Widget build(BuildContext context) {
    final renk = leagueColor(rank.color);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: renk.withValues(alpha: 0.45)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              RankBadge.fromRank(rank, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rank.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.display(
                        size: 26,
                        weight: FontWeight.w900,
                        color: renk,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${rank.mmr} puan',
                      style: AppTypography.bodyS,
                    ),
                  ],
                ),
              ),
              if (position != null) _SiraRozeti(position: position!),
            ],
          ),

          const SizedBox(height: 16),

          // ---- İLERLEME ----
          if (rank.isTopTier)
            _EnUstBasamak(color: renk)
          else
            _Ilerleme(rank: rank, color: renk),
        ],
      ),
    );
  }
}

class _Ilerleme extends StatelessWidget {
  final PlayerRank rank;
  final Color color;

  const _Ilerleme({required this.rank, required this.color});

  @override
  Widget build(BuildContext context) {
    final kalanGalibiyet = rank.winsToNext;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Sıradaki: ${rank.nextLabel ?? '—'}',
              style: AppTypography.body(
                size: 12.5,
                weight: FontWeight.w800,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              '${rank.mmr} / ${rank.nextTierMmr}',
              style: AppTypography.display(
                size: 14,
                weight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: rank.progress.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: AppColors.surfaceLight,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        if (kalanGalibiyet != null && kalanGalibiyet > 0) ...[
          const SizedBox(height: 8),
          Text(
            // Puan yerine GALİBİYET yazıyoruz: "175 puan" soyut,
            // "7 galibiyet" somut bir hedef.
            'Yükselmek için $kalanGalibiyet galibiyet',
            style: AppTypography.bodyXS,
          ),
        ],
      ],
    );
  }
}

class _EnUstBasamak extends StatelessWidget {
  final Color color;

  const _EnUstBasamak({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.workspace_premium_rounded, size: 19, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'En üst basamaktasın. Buradan sonrası sıralama yarışı.',
              style: AppTypography.body(
                size: 12,
                weight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SiraRozeti extends StatelessWidget {
  final int position;

  const _SiraRozeti({required this.position});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '#$position',
            style: AppTypography.display(
              size: 19,
              weight: FontWeight.w900,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text('SIRA', style: AppTypography.label),
        ],
      ),
    );
  }
}
