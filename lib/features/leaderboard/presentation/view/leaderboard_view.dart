import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_breakpoints.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/screen_header.dart';
import '../viewmodel/leaderboard_view_model.dart';
import '../widgets/rank_badge.dart';

/// Liderlik tablosu.
///
/// ===================================================================
/// SIRA SUNUCUDAN GELİYOR
/// ===================================================================
/// Ekran listeyi sayıp sıra numarası üretmiyor. İlk 50'yi çeken bir
/// oyuncu 340. sırada olsaydı kendini bulamazdı; sunucu hem listeyi
/// hem oyuncunun sırasını ayrı ayrı veriyor.
///
/// Oyuncu listede yoksa altta sabit bir "sen buradasın" satırı
/// çiziliyor: ekran hiçbir zaman "sıran belli değil" demiyor.
class LeaderboardView extends StatelessWidget {
  const LeaderboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LeaderboardViewModel>(
      create: (_) => getIt<LeaderboardViewModel>()..initialize(),
      child: const _LeaderboardBody(),
    );
  }
}

class _LeaderboardBody extends StatelessWidget {
  const _LeaderboardBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LeaderboardViewModel>();

    return AppShell(
      currentRoute: AppRoutes.leaderboard,
      child: ResponsiveBuilder(
        builder: (context, boyut) {
          final kenar = AppBreakpoints.pagePadding(boyut);

          return SafeArea(
            bottom: false,
            child: ContentWidth(
              maxWidth: 820,
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      kenar,
                      boyut.usesSidebar ? 32 : 16,
                      kenar,
                      0,
                    ),
                    child: ScreenHeader(
                      title: 'Liderlik',
                      subtitle: 'Puana göre sıralama',
                      actions: [_LiglerButonu()],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Expanded(child: _icerik(context, vm, kenar, boyut)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _icerik(
    BuildContext context,
    LeaderboardViewModel vm,
    double kenar,
    ScreenSize boyut,
  ) {
    if (vm.isBusy && vm.entries.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (vm.hasError && vm.entries.isEmpty) {
      return _HataDurumu(viewModel: vm);
    }

    final rutbe = vm.myRank;

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: vm.refresh,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          kenar,
          0,
          kenar,
          boyut.usesSidebar ? 32 : 110,
        ),
        children: [
          // ---- KENDİ RÜTBEN ----
          if (rutbe != null) ...[
            RankProgressCard(rank: rutbe, position: vm.myPosition),
            const SizedBox(height: 22),
          ],

          const SectionTitle('Sıralama'),
          const SizedBox(height: 10),

          if (vm.entries.isEmpty)
            const _BosTablo()
          else
            for (final kayit in vm.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _SiraSatiri(
                  entry: kayit,
                  isMe: kayit.userId == vm.myUserId,
                ),
              ),

          // ---- LİSTEDE DEĞİLSEN ----
          // Oyuncu ilk 50'de değilse kendi satırı altta ayrıca
          // gösteriliyor. "Sıran 340" demek yerine satırı çizmek
          // oyuncuya nerede olduğunu somut gösteriyor.
          if (!vm.amIInList && vm.myPosition != null && rutbe != null) ...[
            const SizedBox(height: 14),
            const _Ayirac(),
            const SizedBox(height: 14),
            _SiraSatiri(
              entry: LeaderboardEntry(
                rankPosition: vm.myPosition!,
                userId: vm.myUserId ?? '',
                username: 'Sen',
                mmr: rutbe.mmr,
                leagueName: rutbe.leagueName,
                division: rutbe.division,
                color: rutbe.color,
              ),
              isMe: true,
            ),
          ],
        ],
      ),
    );
  }
}

/// Başlıktaki "Ligler" butonu.
///
/// Oyuncu rütbesini gördüğü yerden "kaç lig var, en tepede ne var"
/// sorusuna gidebilmeli. Ayrı bir gezinme maddesi açmak yerine
/// liderlik ekranının içinden ulaşılıyor.
class _LiglerButonu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(AppRoutes.leagueTiers),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.surfaceLight),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.military_tech_rounded,
                size: 17,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 7),
              Text(
                'LİGLER',
                style: AppTypography.display(
                  size: 14,
                  weight: FontWeight.w800,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ====================================================================
// SIRA SATIRI
// ====================================================================
class _SiraSatiri extends StatelessWidget {
  final LeaderboardEntry entry;
  final bool isMe;

  const _SiraSatiri({required this.entry, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final renk = leagueColor(entry.color);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      decoration: BoxDecoration(
        // Kendi satırın vurgulu: uzun bir listede kendini aramak
        // zorunda kalmıyorsun.
        color: isMe
            ? AppColors.primary.withValues(alpha: 0.12)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMe
              ? AppColors.primary.withValues(alpha: 0.45)
              : AppColors.surfaceLight,
        ),
      ),
      child: Row(
        children: [
          SizedBox(width: 38, child: _Sira(entry: entry)),
          const SizedBox(width: 6),
          RankBadge.fromEntry(entry, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(
                    size: 13.5,
                    weight: FontWeight.w800,
                    color: isMe ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${entry.rankLabel} · ${entry.wins}G ${entry.losses}M',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyXS,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.mmr}',
                style: AppTypography.display(
                  size: 18,
                  weight: FontWeight.w900,
                  color: renk,
                  height: 1.0,
                ),
              ),
              Text('PUAN', style: AppTypography.label),
            ],
          ),
        ],
      ),
    );
  }
}

/// Sıra numarası. İlk üç madalya rengiyle çiziliyor.
class _Sira extends StatelessWidget {
  final LeaderboardEntry entry;

  const _Sira({required this.entry});

  @override
  Widget build(BuildContext context) {
    final madalya = entry.medal;

    if (madalya == null) {
      return Text(
        '${entry.rankPosition}',
        textAlign: TextAlign.center,
        style: AppTypography.display(
          size: 16,
          weight: FontWeight.w800,
          color: AppColors.textSecondary,
        ),
      );
    }

    // Madalya renkleri kart seviyelerinden farklı bir bağlamda:
    // burada altın/gümüş/bronz "birincilik" demek, kart gücü değil.
    final renk = switch (madalya) {
      1 => const Color(0xFFFFD24A),
      2 => const Color(0xFFCBD5E1),
      _ => const Color(0xFFD08A5A),
    };

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.16),
        shape: BoxShape.circle,
        border: Border.all(color: renk.withValues(alpha: 0.6)),
      ),
      child: Center(
        child: Text(
          '$madalya',
          style: AppTypography.display(
            size: 15,
            weight: FontWeight.w900,
            color: renk,
          ),
        ),
      ),
    );
  }
}

class _Ayirac extends StatelessWidget {
  const _Ayirac();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.surfaceLight)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('SENİN SIRAN', style: AppTypography.label),
        ),
        const Expanded(child: Divider(color: AppColors.surfaceLight)),
      ],
    );
  }
}

// ====================================================================
// BOŞ VE HATA DURUMLARI
// ====================================================================
class _BosTablo extends StatelessWidget {
  const _BosTablo();

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      child: Column(
        children: [
          const Icon(
            Icons.emoji_events_outlined,
            size: 32,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            'Sıralama henüz oluşmadı',
            style: AppTypography.body(size: 14, weight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'İlk maçlar oynandığında burası dolacak.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyS,
          ),
        ],
      ),
    );
  }
}

class _HataDurumu extends StatelessWidget {
  final LeaderboardViewModel viewModel;

  const _HataDurumu({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 44, color: AppColors.danger),
            const SizedBox(height: 16),
            Text(
              viewModel.errorMessage ?? 'Sıralama yüklenemedi.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyM,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: viewModel.refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('TEKRAR DENE'),
            ),
          ],
        ),
      ),
    );
  }
}
