import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/ref_tokens.dart';
import '../../../../core/utils/turkish_text.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/ref/ref_ui.dart';
import '../viewmodel/league_tiers_view_model.dart';
import 'leaderboard_view.dart' show kLigRozetleri;

/// LİGLER — bütün basamaklar (4 lig x 3 seviye).
///
/// Referansta ayrı bir ekranı yok; "Ligler / Sıralama" ekranının dili
/// kullanıldı: .sectionhead, .card-panel, lig rozetleri, .bar. Basamak
/// eşikleri sunucudan (league_tiers); oyuncunun basamağı vurgulanır.
class LeagueTiersView extends StatelessWidget {
  const LeagueTiersView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LeagueTiersViewModel>(
      create: (_) => getIt<LeagueTiersViewModel>()..initialize(),
      child: const AppShell(currentRoute: AppRoutes.leaderboard, child: _Govde()),
    );
  }
}

class _Govde extends StatelessWidget {
  const _Govde();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LeagueTiersViewModel>();
    final Widget icerik;
    if (vm.isBusy && vm.tiers.isEmpty) {
      icerik = const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator(color: Ref.accent)),
      );
    } else if (vm.hasError && vm.tiers.isEmpty) {
      icerik = RefCardPanel(children: [
        Text(vm.errorMessage ?? 'Ligler yüklenemedi.', style: Ref.bodyText(12)),
        RefSecondaryButton('TEKRAR DENE', onTap: vm.refresh),
      ]);
    } else {
      icerik = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final g in vm.groups) ...[
          _LigGrubu(group: g, myTierId: vm.myTierId),
          const SizedBox(height: Ref.pageGap),
        ],
        const RefNote(
          'Amatör\'de bir seviye atlamak 4 net galibiyet isterken Master Class 2\'ye geçmek 10 net galibiyet '
          'istiyor. Üst ligler böylece gerçekten seyrek kalıyor. Ligden düşme yok: en alt basamak zemin.',
          title: 'Bantlar yukarı çıkıldıkça genişliyor',
        ),
      ]);
    }

    return RefreshIndicator(
      color: Ref.accent,
      backgroundColor: Ref.panel,
      onRefresh: vm.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: Ref.pagePadding,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: RefPageEnter(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    RefNeutralButton(
                      padding: const EdgeInsets.all(7),
                      semanticLabel: 'Geri',
                      onTap: () => context.canPop() ? context.pop() : context.go(AppRoutes.leaderboard),
                      child: const Icon(Icons.arrow_back_rounded, size: 16, color: Ref.neutralText),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(child: RefSectionHead('LİGLER', size: 27, kicker: '4 LİG · HER BİRİNDE 3 SEVİYE')),
                  ]),
                  const SizedBox(height: Ref.pageGap),
                  icerik,
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LigGrubu extends StatelessWidget {
  final LeagueGroup group;
  final int? myTierId;
  const _LigGrubu({required this.group, required this.myTierId});

  @override
  Widget build(BuildContext context) {
    final emoji = kLigRozetleri.where((r) => r.$1 == group.code).firstOrNull?.$2 ?? '🏅';
    final buradayim = group.tiers.any((t) => t.tierId == myTierId);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        gradient: Ref.cardPanelGradient,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: buradayim ? Ref.accent : Ref.cardPanelBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Em(emoji, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(group.name.toUpperTr(), style: Ref.h3()),
              Text('${trThousands(group.minMmr)} puandan başlar', style: Ref.tiny(Ref.muted)),
            ]),
          ),
          if (buradayim) const RefPill('BURADASIN', dot: true),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          for (var i = 0; i < group.tiers.length; i++) ...[
            if (i > 0) const SizedBox(width: 7),
            Expanded(child: _Basamak(tier: group.tiers[i], benim: group.tiers[i].tierId == myTierId)),
          ],
        ]),
      ]),
    );
  }
}

class _Basamak extends StatelessWidget {
  final LeagueTier tier;
  final bool benim;
  const _Basamak({required this.tier, required this.benim});

  @override
  Widget build(BuildContext context) => Semantics(
        label: '${tier.label}, ${tier.minMmr} puan${benim ? ', şu an buradasın' : ''}',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 9),
          decoration: BoxDecoration(
            color: benim ? Ref.filterActiveBg : Ref.statBg,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: benim ? Ref.filterActiveBorder : Ref.statBorder),
          ),
          child: Column(children: [
            Text('Seviye ${tier.division}', style: Ref.bodyText(10, color: Ref.statLabel)),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(trThousands(tier.minMmr), style: Ref.heading(22, color: Ref.statValue, height: 1.2)),
            ),
            Text('puan', style: Ref.bodyText(10, color: Ref.statLabel)),
          ]),
        ),
      );
}
