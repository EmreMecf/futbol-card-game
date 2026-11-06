import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/feedback/game_feedback.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/turkish_text.dart';
import '../../../../shared/widgets/game/game_ui.dart';
import '../../../leaderboard/presentation/widgets/rank_badge.dart';

// ====================================================================
// LİG İLERLEME PANELİ (maç sonu)
// ====================================================================
/// Maçın lig etkisi: rozet, puan değişimi ve basamak içi ilerleme.
///
/// HER SAYI SUNUCUDAN (022_match_league_change.sql): maç öncesi ve
/// sonrası puan, iki taraftaki lig ve ilerleme oranı. Bu widget hiçbir
/// eşik hesaplamıyor; sadece "öncesi"nden "sonrası"na animasyon yapıyor.
class LeagueChangePanel extends StatelessWidget {
  final MatchLeagueChange change;

  const LeagueChangePanel({super.key, required this.change});

  @override
  Widget build(BuildContext context) {
    final sonra = change.rankAfter;
    final renk = leagueColor(sonra.color);
    final fark = change.mmrDelta;
    final farkRenk = fark > 0
        ? AppColors.emerald
        : (fark < 0 ? AppColors.danger : AppColors.textSecondary);

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              RankBadge.fromRank(sonra, size: 52),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LİG',
                      style: AppTypography.label,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sonra.label,
                      style: AppTypography.display(
                        size: 24,
                        weight: FontWeight.w900,
                        color: renk,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${fark > 0 ? '+' : ''}$fark',
                    style: AppTypography.display(
                      size: 24,
                      weight: FontWeight.w900,
                      color: farkRenk,
                    ),
                  ),
                  OkluMetin(
                    from: '${change.mmrBefore}',
                    to: '${change.mmrAfter} puan',
                    style: AppTypography.bodyS,
                  ),
                ],
              ),
            ],
          ),
          if (change.isPromoted || change.isDemoted) ...[
            const SizedBox(height: AppSpacing.md),
            _DegisimSeridi(change: change),
          ],
          const SizedBox(height: AppSpacing.md),
          LeagueProgressAnimation(change: change),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _hedefMetni(sonra),
            style: AppTypography.bodyS,
          ),
        ],
      ),
    );
  }

  static String _hedefMetni(PlayerRank r) {
    final sonraki = r.nextLabel;
    final galibiyet = r.winsToNext;
    if (r.isTopTier || sonraki == null || galibiyet == null) {
      return 'En üst basamaktasın.';
    }
    return '$sonraki için $galibiyet galibiyet (${r.pointsToNext} puan).';
  }
}

/// "AMATÖR 3 → USTA 1" şeridi
class _DegisimSeridi extends StatelessWidget {
  final MatchLeagueChange change;

  const _DegisimSeridi({required this.change});

  @override
  Widget build(BuildContext context) {
    final yukseldi = change.isPromoted;
    final renk = yukseldi ? AppColors.victoryGold : AppColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: renk.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(
            yukseldi
                ? Icons.keyboard_double_arrow_up_rounded
                : Icons.keyboard_double_arrow_down_rounded,
            color: renk,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              yukseldi
                  ? (change.changedLeague ? 'LİG ATLADIN' : 'SEVİYE ATLADIN')
                  : 'SEVİYE DÜŞTÜ',
              style: AppTypography.display(
                size: 15,
                weight: FontWeight.w900,
                letterSpacing: 1,
                color: renk,
              ),
            ),
          ),
          Flexible(
            child: OkluMetin(
              from: change.rankBefore.label,
              to: change.rankAfter.label,
              style: AppTypography.body(
                size: 12,
                weight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// İLERLEME ÇUBUĞU ANİMASYONU
// ====================================================================
/// Basamak içi ilerleme, maç öncesinden sonrasına doğru dolar/boşalır.
///
/// Basamak değiştiyse çubuk eski basamakta ucuna kadar gidip (ya da
/// başına inip) yeni basamakta devam eder; "eşiği geçtin" hissi böyle
/// geliyor. Animasyonlar kapalıysa doğrudan son değer çizilir.
class LeagueProgressAnimation extends StatefulWidget {
  final MatchLeagueChange change;

  const LeagueProgressAnimation({super.key, required this.change});

  /// Toplam süre (MD: panel geçişi 250-400 ms; dolum biraz daha uzun
  /// ki oyuncu artışı görebilsin)
  static const duration = Duration(milliseconds: 1100);

  @override
  State<LeagueProgressAnimation> createState() =>
      _LeagueProgressAnimationState();
}

class _LeagueProgressAnimationState extends State<LeagueProgressAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: LeagueProgressAnimation.duration,
    );
    if (GameFeedback.cardAnimationsEnabled) {
      // Panel girişi bitsin, sonra dolsun
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        if (mounted) _c.forward();
      });
    } else {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// t (0-1) anındaki (gösterilen basamak, oran)
  ({PlayerRank rank, double value}) _kare(double t) {
    final d = widget.change;
    final once = d.rankBefore.progress;
    final sonra = d.rankAfter.progress;

    if (!d.isPromoted && !d.isDemoted) {
      return (rank: d.rankAfter, value: once + (sonra - once) * t);
    }

    // Basamak değişti: ilk yarı eski basamakta uca, ikinci yarı yenide
    final hedefUc = d.isPromoted ? 1.0 : 0.0;
    final yeniBas = d.isPromoted ? 0.0 : 1.0;
    if (t < 0.5) {
      final k = t / 0.5;
      return (rank: d.rankBefore, value: once + (hedefUc - once) * k);
    }
    final k = (t - 0.5) / 0.5;
    return (rank: d.rankAfter, value: yeniBas + (sonra - yeniBas) * k);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.change;
    return Semantics(
      label: '${d.rankAfter.label}, ilerleme '
          '%${(d.rankAfter.progress * 100).round()}',
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final kare =
                _kare(Curves.easeInOutCubic.transform(_c.value));
            final renk = leagueColor(kare.rank.color);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: SizedBox(
                    height: 10,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const ColoredBox(color: AppColors.surfaceLight),
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: kare.value.clamp(0.0, 1.0),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                renk.withValues(alpha: 0.7),
                                renk,
                              ]),
                              boxShadow: [
                                BoxShadow(
                                  color: renk.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Text(kare.rank.label, style: AppTypography.bodyS),
                    const Spacer(),
                    if (kare.rank.nextLabel != null)
                      Text(kare.rank.nextLabel!, style: AppTypography.bodyS),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ====================================================================
// LİG ATLAMA EKRANI (ödül ekranı)
// ====================================================================
/// Basamak atlandığında maç sonucunun ÜSTÜNDE bir kez gösterilir.
///
/// Sunucuda lig atlama ödülü YOK; bu ekran ödül uydurmaz. Kutladığı şey
/// gerçek: sunucunun kaydettiği yeni basamak. Dokununca ya da
/// "Devam"a basınca kapanır (MD: animasyon atlanabilir olmalı).
class LeaguePromotionOverlay extends StatefulWidget {
  final MatchLeagueChange change;
  final VoidCallback onContinue;

  const LeaguePromotionOverlay({
    super.key,
    required this.change,
    required this.onContinue,
  });

  @override
  State<LeaguePromotionOverlay> createState() => _LeaguePromotionOverlayState();
}

class _LeaguePromotionOverlayState extends State<LeaguePromotionOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (GameFeedback.cardAnimationsEnabled) {
      _c.forward();
    } else {
      _c.value = 1;
    }
    // Zafer titreşimi (MD bölüm 10: zafer = en güçlü)
    GameFeedback.haptic(HapticStrength.heavy);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.change;
    final renk = leagueColor(d.rankAfter.color);
    final baslik = d.changedLeague ? 'LİG ATLADIN!' : 'SEVİYE ATLADIN!';

    return Semantics(
      liveRegion: true,
      label: '$baslik ${d.rankAfter.label}',
      child: GestureDetector(
        onTap: widget.onContinue,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            final arka = Curves.easeOut.transform((t / 0.3).clamp(0.0, 1.0));
            final rozet = Curves.elasticOut
                .transform(((t - 0.1) / 0.6).clamp(0.0, 1.0));
            final yazi =
                Curves.easeOutCubic.transform(((t - 0.45) / 0.4).clamp(0.0, 1.0));
            return ColoredBox(
              color: AppColors.obsidian.withValues(alpha: 0.92 * arka),
              child: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Rozet + arkasında dönen ışık hüzmeleri
                        SizedBox(
                          width: 220,
                          height: 220,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Opacity(
                                opacity: arka,
                                child: CustomPaint(
                                  size: const Size(220, 220),
                                  painter: _HuzmePainter(
                                    color: renk,
                                    turn: t,
                                  ),
                                ),
                              ),
                              Transform.scale(
                                scale: 0.3 + 0.7 * rozet,
                                child: Opacity(
                                  opacity: rozet.clamp(0.0, 1.0),
                                  child: RankBadge.fromRank(d.rankAfter,
                                      size: 120),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Opacity(
                          opacity: yazi,
                          child: Transform.translate(
                            offset: Offset(0, 16 * (1 - yazi)),
                            child: Column(
                              children: [
                                Text(
                                  baslik,
                                  textAlign: TextAlign.center,
                                  style: AppTypography.display(
                                    size: 40,
                                    weight: FontWeight.w900,
                                    color: AppColors.victoryGold,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  d.rankAfter.label.toUpperTr(),
                                  style: AppTypography.display(
                                    size: 26,
                                    weight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                    color: renk,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                OkluMetin(
                                  from: d.rankBefore.label,
                                  to: '${d.rankAfter.label}  ·  '
                                      '${d.mmrAfter} puan',
                                  style: AppTypography.bodyM,
                                ),
                                const SizedBox(height: AppSpacing.xxl),
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 320),
                                  child: GameButton(
                                    label: 'Devam',
                                    icon: Icons.check_rounded,
                                    onPressed: widget.onContinue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Rozetin arkasında yavaşça dönen ışık hüzmeleri
class _HuzmePainter extends CustomPainter {
  final Color color;
  final double turn;

  _HuzmePainter({required this.color, required this.turn});

  @override
  void paint(Canvas canvas, Size size) {
    final merkez = size.center(Offset.zero);
    final r = size.width / 2;

    // Yumuşak hale
    canvas.drawCircle(
      merkez,
      r * 0.7,
      Paint()
        ..shader = RadialGradient(colors: [
          color.withValues(alpha: 0.45),
          color.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: merkez, radius: r * 0.7)),
    );

    // 12 hüzme
    final boya = Paint()..color = color.withValues(alpha: 0.16);
    const adet = 12;
    final aci0 = turn * math.pi / 3;
    for (var i = 0; i < adet; i++) {
      final a = aci0 + i * 2 * math.pi / adet;
      final yol = Path()
        ..moveTo(merkez.dx, merkez.dy)
        ..lineTo(merkez.dx + r * math.cos(a - 0.09),
            merkez.dy + r * math.sin(a - 0.09))
        ..lineTo(merkez.dx + r * math.cos(a + 0.09),
            merkez.dy + r * math.sin(a + 0.09))
        ..close();
      canvas.drawPath(yol, boya);
    }
  }

  @override
  bool shouldRepaint(_HuzmePainter eski) =>
      eski.turn != turn || eski.color != color;
}

/// "Amatör 3 ➜ Usta 1" — ok İKON olarak çizilir.
///
/// NEDEN METİN DEĞİL? "→" karakteri Nunito ve Barlow Condensed'de yok;
/// ekranda boş bir kutu olarak çıkıyordu (✦ işaretinde de aynısı
/// olmuştu). İkon her yazı tipinde aynı görünür.
class OkluMetin extends StatelessWidget {
  final String from;
  final String to;
  final TextStyle style;

  const OkluMetin({
    super.key,
    required this.from,
    required this.to,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final boy = (style.fontSize ?? 13) + 1;
    return Semantics(
      label: '$from, $to',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(from,
                  style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.arrow_forward_rounded,
                  size: boy, color: style.color ?? AppColors.textSecondary),
            ),
            Flexible(
              child: Text(to,
                  style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
