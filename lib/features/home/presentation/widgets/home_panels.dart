import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/utils/turkish_text.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/game/game_ui.dart';
import '../../../leaderboard/presentation/widgets/rank_badge.dart';

/// ANA SAYFA PANELLERİ — HTML prototipindeki "Lobby" ekranının
/// Flutter karşılığı.
///
/// Hiyerarşi (MD bölüm 4-C): "MAÇA BAŞLA" ekranın merkezi. Görevler,
/// geçmiş ve kısayollar görünür biçimde ondan daha sönük.

// ====================================================================
// ARENA KAHRAMAN PANELİ
// ====================================================================
/// "ARENA SENİ BEKLİYOR" — lig, kupa, seri ve büyük altın buton.
///
/// KUPA = MMR. Prototipte ayrı bir "kupa" sayacı vardı; oyunda zaten
/// MMR var ve lig basamakları ona göre hesaplanıyor. İkinci bir sayaç
/// eklemek yerine MMR'ı kupa simgesiyle gösteriyoruz (FAZ 1 kararı).
class ArenaHeroPanel extends StatelessWidget {
  final UserModel? user;
  final PlayerRank? rank;
  final int winStreak;
  final bool isStreakCapped;

  /// Masaüstünde daha yüksek ve büyük yazılı
  final bool large;

  const ArenaHeroPanel({
    super.key,
    required this.user,
    required this.rank,
    required this.winStreak,
    this.isStreakCapped = false,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final r = rank;
    final ligRengi = r == null ? AppColors.emerald : leagueColor(r.color);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.emerald.withValues(alpha: 0.35)),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF142A43), Color(0xFF0B1527)],
          ),
        ),
        child: Stack(
          children: [
            // ---- Arka plan: orta saha halkaları + ışık ----
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(painter: _HalkaPainter(ligRengi)),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(large ? AppSpacing.xxxl : AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---- Lig hapı ----
                  if (r != null)
                    _LigHapi(rank: r)
                  else
                    const _IskeletHap(),

                  SizedBox(height: large ? AppSpacing.xl : AppSpacing.md),

                  Text(
                    'ARENA\nSENİ BEKLİYOR',
                    style: AppTypography.display(
                      size: large ? 52 : 38,
                      weight: FontWeight.w900,
                      height: 0.92,
                      letterSpacing: 0.4,
                    ).copyWith(
                      shadows: const [
                        Shadow(color: Colors.black54, blurRadius: 18),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Kartlarını hazırla. Rakip aynı mevkiden oynamak zorunda.',
                    style: AppTypography.bodyS,
                  ),

                  SizedBox(height: large ? AppSpacing.xl : AppSpacing.lg),

                  // ---- Kupa + seri ----
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.emoji_events_rounded,
                              color: AppColors.victoryGold, size: 26),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            formatThousands(user?.mmr ?? 0),
                            style: AppTypography.display(
                              size: 28,
                              weight: FontWeight.w900,
                              color: AppColors.victoryGold,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                      if (winStreak >= 2)
                        _Hap(
                          icon: Icons.local_fire_department_rounded,
                          color: AppColors.warning,
                          text:
                              '${isStreakCapped ? '$winStreak+' : winStreak} galibiyet serisi',
                        ),
                    ],
                  ),

                  // ---- Bir sonraki basamağa ilerleme ----
                  if (r != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    _LigIlerlemesi(rank: r),
                  ],

                  SizedBox(height: large ? AppSpacing.xxl : AppSpacing.lg),

                  GameButton(
                    label: 'Maça başla',
                    icon: Icons.sports_soccer_rounded,
                    trailingIcon: Icons.play_arrow_rounded,
                    onPressed: () => context.go(AppRoutes.matchmaking),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LigHapi extends StatelessWidget {
  final PlayerRank rank;

  const _LigHapi({required this.rank});

  @override
  Widget build(BuildContext context) {
    final renk = leagueColor(rank.color);

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      onTap: () => context.push(AppRoutes.leagueTiers),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xs, AppSpacing.xs, AppSpacing.md, AppSpacing.xs),
        decoration: BoxDecoration(
          color: renk.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: renk.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RankBadge.fromRank(rank, size: 22),
            const SizedBox(width: AppSpacing.sm),
            Text(
              rank.label.toUpperTr(),
              style: AppTypography.display(
                size: 13,
                weight: FontWeight.w900,
                color: renk,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LigIlerlemesi extends StatelessWidget {
  final PlayerRank rank;

  const _LigIlerlemesi({required this.rank});

  @override
  Widget build(BuildContext context) {
    final sonraki = rank.nextLabel;
    final galibiyet = rank.winsToNext;

    final metin = rank.isTopTier || sonraki == null
        ? 'En üst basamaktasın'
        : galibiyet == null || galibiyet <= 0
            ? '$sonraki basamağına çok yakınsın'
            : '$sonraki için $galibiyet galibiyet';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GameProgressBar(
          value: rank.isTopTier ? 1 : rank.progress,
          kind: ProgressKind.task,
          semanticLabel: metin,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(metin, style: AppTypography.bodyXS),
      ],
    );
  }
}

/// Rütbe yüklenirken lig hapının yerini tutar; yerleşim zıplamasın.
class _IskeletHap extends StatelessWidget {
  const _IskeletHap();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      height: 30,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
    );
  }
}

class _Hap extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _Hap({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: AppSpacing.xs),
          // Flexible: dar telefonda ya da büyük yazı boyutu ayarında
          // hap taşmasın, gerekirse "…" ile kısalsın.
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body(
                  size: 11, weight: FontWeight.w800, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Orta saha yuvarlağını andıran iç içe halkalar + sağ üstte ışık.
/// Görsel dosya yok; her boyutta net ve paket boyutuna etkisi sıfır.
class _HalkaPainter extends CustomPainter {
  final Color renk;

  _HalkaPainter(this.renk);

  @override
  void paint(Canvas canvas, Size size) {
    final merkez = Offset(size.width * 0.92, size.height * 0.22);

    canvas.drawCircle(
      merkez,
      size.width * 0.55,
      Paint()
        ..shader = RadialGradient(colors: [
          renk.withValues(alpha: 0.22),
          renk.withValues(alpha: 0),
        ]).createShader(
          Rect.fromCircle(center: merkez, radius: size.width * 0.55),
        ),
    );

    final cizgi = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    final r0 = math.min(size.width, size.height) * 0.28;
    for (var i = 0; i < 3; i++) {
      cizgi.color = AppColors.emerald.withValues(alpha: 0.10 - i * 0.03);
      canvas.drawCircle(merkez, r0 + i * 18, cizgi);
    }
  }

  @override
  bool shouldRepaint(_HalkaPainter eski) => eski.renk != renk;
}

// ====================================================================
// KISAYOL KAROLARI
// ====================================================================
class HomeShortcut {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;

  const HomeShortcut({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
  });
}

/// Kadrom, Kartlarım, Mağaza, Görevler.
class HomeShortcutGrid extends StatelessWidget {
  final int columns;

  const HomeShortcutGrid({super.key, required this.columns});

  @override
  Widget build(BuildContext context) {
    final karolar = [
      const HomeShortcut(
        title: 'KADROM',
        subtitle: '4-4-2 · kimya',
        icon: Icons.groups_rounded,
        color: AppColors.cyan,
        route: AppRoutes.deck,
      ),
      const HomeShortcut(
        title: 'KARTLARIM',
        subtitle: 'Koleksiyon',
        icon: Icons.style_rounded,
        color: AppColors.epicPurple,
        route: AppRoutes.collection,
      ),
      const HomeShortcut(
        title: 'MAĞAZA',
        subtitle: 'Paketler',
        icon: Icons.storefront_rounded,
        color: AppColors.victoryGold,
        route: AppRoutes.store,
      ),
      const HomeShortcut(
        title: 'GÖREVLER',
        subtitle: 'Kart erit, ödül al',
        icon: Icons.checklist_rounded,
        color: AppColors.emerald,
        route: AppRoutes.sbc,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        // Sabit yükseklik: ekran genişledikçe karo uzamasın
        mainAxisExtent: 104,
      ),
      itemCount: karolar.length,
      itemBuilder: (context, i) {
        final k = karolar[i];
        return GlassPanel(
          padding: const EdgeInsets.all(AppSpacing.md),
          onTap: () => context.go(k.route),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: k.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(k.icon, color: k.color, size: 22),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(k.title, style: AppTypography.h3.copyWith(fontSize: 17)),
                  Text(
                    k.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyXS,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ====================================================================
// SON MAÇLAR — gerçek veri
// ====================================================================
class RecentMatchesPanel extends StatelessWidget {
  final List<MatchHistoryEntry> matches;
  final bool isLoaded;

  const RecentMatchesPanel({
    super.key,
    required this.matches,
    required this.isLoaded,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          title: 'Son maçlar',
          actionLabel: matches.isEmpty ? null : 'Tümü',
          onAction: () => context.go(AppRoutes.profile),
        ),
        const SizedBox(height: AppSpacing.sm),
        GlassPanel(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          child: !isLoaded
              ? const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : matches.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text(
                        'Henüz maç oynamadın. İlk maçın burada görünecek.',
                        style: AppTypography.bodyS,
                      ),
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < matches.length; i++) ...[
                          if (i > 0)
                            const Divider(height: 1, color: AppColors.surfaceLight),
                          _MacSatiri(entry: matches[i]),
                        ],
                      ],
                    ),
        ),
      ],
    );
  }
}

class _MacSatiri extends StatelessWidget {
  final MatchHistoryEntry entry;

  const _MacSatiri({required this.entry});

  @override
  Widget build(BuildContext context) {
    final (renk, harf) = switch (entry.outcome) {
      MatchOutcome.win => (AppColors.emerald, 'G'),
      MatchOutcome.loss => (AppColors.danger, 'M'),
      MatchOutcome.draw => (AppColors.textSecondary, 'B'),
    };
    final transfer = entry.transferText;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          // Sonuç harfi: renk körü oyuncular için renk TEK ipucu değil
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: renk.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: renk.withValues(alpha: 0.5)),
            ),
            child: Text(
              harf,
              semanticsLabel: entry.outcome.label,
              style: AppTypography.display(
                  size: 16, weight: FontWeight.w900, color: renk),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'vs ${entry.opponentUsername}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(size: 13, weight: FontWeight.w800),
                ),
                if (transfer != null)
                  Text(
                    transfer,
                    style: AppTypography.body(
                      size: 11,
                      color: entry.cardsWon > 0
                          ? AppColors.emerald
                          : AppColors.danger,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            entry.scoreText,
            style: AppTypography.display(size: 20, weight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// YAKINDA — günlük görevler ve sezon
// ====================================================================
/// Sunucuda karşılığı OLMAYAN özellikler.
///
/// Prototipte "3 karşılaşma kazan 2/3" ve "Sezon seviye 12/20" vardı.
/// Bunları sahte sayılarla çizmek oyuncuya yalan söylemek olurdu
/// (MD kural 11-12). Ödül veren yeni bir mekanik olduğu için de
/// onaysız eklenmiyor (MD kural 13). Bu panel, yerin ayrıldığını
/// dürüstçe gösteriyor.
class ComingSoonPanel extends StatelessWidget {
  const ComingSoonPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        children: [
          _satir(
            Icons.track_changes_rounded,
            'Günlük görevler',
            'Her gün yenilenen küçük hedefler ve coin ödülü',
          ),
          const Divider(height: AppSpacing.xl, color: AppColors.surfaceLight),
          _satir(
            Icons.workspace_premium_rounded,
            'Sezon yolu',
            'Sezon boyunca açılan ödül basamakları',
          ),
        ],
      ),
    );
  }

  Widget _satir(IconData ikon, String baslik, String aciklama) {
    return Row(
      children: [
        Icon(ikon, color: AppColors.textSecondary, size: 24),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(baslik,
                  style: AppTypography.body(size: 13, weight: FontWeight.w800)),
              Text(aciklama, style: AppTypography.bodyXS),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            'YAKINDA',
            style: AppTypography.display(
              size: 11,
              weight: FontWeight.w900,
              color: AppColors.textSecondary,
              letterSpacing: 1.1,
            ),
          ),
        ),
      ],
    );
  }
}

// ====================================================================
// ORTAK
// ====================================================================
class HomeSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const HomeSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title.toUpperTr(), style: AppTypography.h3),
        const Spacer(),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            child: Text(
              actionLabel!,
              style: AppTypography.body(
                  size: 12, weight: FontWeight.w800, color: AppColors.emerald),
            ),
          ),
      ],
    );
  }
}

/// 2450 -> "2.450". Türkçe binlik ayracı nokta.
String formatThousands(int sayi) {
  final metin = sayi.abs().toString();
  final tampon = StringBuffer(sayi < 0 ? '-' : '');
  for (var i = 0; i < metin.length; i++) {
    if (i > 0 && (metin.length - i) % 3 == 0) tampon.write('.');
    tampon.write(metin[i]);
  }
  return tampon.toString();
}
