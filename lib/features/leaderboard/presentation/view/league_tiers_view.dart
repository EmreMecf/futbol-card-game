import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_breakpoints.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/screen_header.dart';
import '../viewmodel/league_tiers_view_model.dart';
import '../widgets/rank_badge.dart';

/// Ligler — bütün basamakların tanıtımı.
///
/// ===================================================================
/// NEDEN AYRI BİR EKRAN?
/// ===================================================================
/// Liderlik ekranı "kim önde" sorusunu cevaplıyor. Bu ekran farklı
/// bir soruyu cevaplıyor: "kaç lig var, sıradaki ne, en tepede ne?"
///
/// İkisini tek ekrana sıkıştırmak sıralamayı 12 basamaklık bir
/// tablonun altına gömerdi. Oyuncu her açılışta sıralamayı görmek
/// istiyor; basamak listesine ise merak ettiğinde bakıyor.
class LeagueTiersView extends StatelessWidget {
  const LeagueTiersView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LeagueTiersViewModel>(
      create: (_) => getIt<LeagueTiersViewModel>()..initialize(),
      child: const _LeagueTiersBody(),
    );
  }
}

class _LeagueTiersBody extends StatelessWidget {
  const _LeagueTiersBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LeagueTiersViewModel>();

    return AppShell(
      currentRoute: AppRoutes.leaderboard,
      child: ResponsiveBuilder(
        builder: (context, boyut) {
          final kenar = AppBreakpoints.pagePadding(boyut);

          return SafeArea(
            bottom: false,
            child: ContentWidth(
              maxWidth: 900,
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      kenar,
                      boyut.usesSidebar ? 32 : 16,
                      kenar,
                      0,
                    ),
                    child: const ScreenHeader(
                      title: 'Ligler',
                      subtitle: '4 lig, her birinde 3 seviye',
                      showBack: true,
                      breadcrumb: 'Liderlik',
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
    LeagueTiersViewModel vm,
    double kenar,
    ScreenSize boyut,
  ) {
    if (vm.isBusy && vm.tiers.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (vm.hasError && vm.tiers.isEmpty) {
      return _HataDurumu(viewModel: vm);
    }

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
          for (final grup in vm.groups)
            Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: _LigGrubu(
                group: grup,
                myTierId: vm.myTierId,
                genis: boyut.usesWideLayout,
              ),
            ),

          NoticeBar.info(
            'Amatör\'de bir seviye atlamak 4 net galibiyet isterken '
            'Master Class 2\'ye geçmek 10 net galibiyet istiyor. Üst '
            'ligler böylece gerçekten seyrek kalıyor. Ligden düşme yok: '
            'en alt basamak zemin.',
            title: 'Bantlar yukarı çıkıldıkça genişliyor',
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// BİR LİG VE ÜÇ SEVİYESİ
// ====================================================================
class _LigGrubu extends StatelessWidget {
  final LeagueGroup group;
  final int? myTierId;
  final bool genis;

  const _LigGrubu({
    required this.group,
    required this.myTierId,
    required this.genis,
  });

  @override
  Widget build(BuildContext context) {
    final renk = leagueColor(group.color);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---- LİG BAŞLIĞI ----
        Row(
          children: [
            Container(
              width: 4,
              height: 22,
              decoration: BoxDecoration(
                color: renk,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              group.name,
              style: AppTypography.display(
                size: genis ? 24 : 21,
                weight: FontWeight.w900,
                color: renk,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                '${_binlik(group.minMmr)} puandan itibaren',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyXS,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // ---- ÜÇ SEVİYE ----
        // Telefonda da yan yana: üç kısa kart dar ekranda da sığıyor
        // ve bir ligin üç seviyesini birlikte görmek bütünü anlatıyor.
        Row(
          children: [
            for (var i = 0; i < group.tiers.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: _SeviyeKarti(
                  tier: group.tiers[i],
                  isMine: group.tiers[i].tierId == myTierId,
                  genis: genis,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  static String _binlik(int sayi) {
    final metin = sayi.toString();
    final tampon = StringBuffer();
    for (var i = 0; i < metin.length; i++) {
      if (i > 0 && (metin.length - i) % 3 == 0) tampon.write('.');
      tampon.write(metin[i]);
    }
    return tampon.toString();
  }
}

class _SeviyeKarti extends StatelessWidget {
  final LeagueTier tier;

  /// Oyuncunun şu an bulunduğu basamak mı?
  final bool isMine;

  final bool genis;

  const _SeviyeKarti({
    required this.tier,
    required this.isMine,
    required this.genis,
  });

  @override
  Widget build(BuildContext context) {
    final renk = leagueColor(tier.color);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: genis ? 14 : 8,
        vertical: genis ? 16 : 13,
      ),
      decoration: BoxDecoration(
        // Oyuncunun basamağı vurgulu: 12 kartlık bir listede kendini
        // aramak zorunda kalmıyor.
        color: isMine ? renk.withValues(alpha: 0.14) : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMine ? renk : AppColors.surfaceLight,
          width: isMine ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          RankBadge(
            leagueName: tier.leagueName,
            division: tier.division,
            colorHex: tier.color,
            size: genis ? 46 : 38,
          ),
          SizedBox(height: genis ? 10 : 8),
          FittedBox(
            child: Text(
              tier.label,
              style: AppTypography.display(
                size: genis ? 17 : 15,
                weight: FontWeight.w900,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            child: Text(
              '${_binlik(tier.minMmr)}+ puan',
              style: AppTypography.body(
                size: genis ? 11.5 : 10.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          if (isMine) ...[
            SizedBox(height: genis ? 8 : 6),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: renk,
                borderRadius: BorderRadius.circular(999),
              ),
              child: FittedBox(
                child: Text(
                  'BURADASIN',
                  style: AppTypography.body(
                    size: 9,
                    weight: FontWeight.w900,
                    color: AppColors.background,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _binlik(int sayi) {
    final metin = sayi.toString();
    final tampon = StringBuffer();
    for (var i = 0; i < metin.length; i++) {
      if (i > 0 && (metin.length - i) % 3 == 0) tampon.write('.');
      tampon.write(metin[i]);
    }
    return tampon.toString();
  }
}

// ====================================================================
// HATA
// ====================================================================
class _HataDurumu extends StatelessWidget {
  final LeagueTiersViewModel viewModel;

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
              viewModel.errorMessage ?? 'Ligler yüklenemedi.',
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
