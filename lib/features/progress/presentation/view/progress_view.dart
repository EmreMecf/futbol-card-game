import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/ref_tokens.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/ref/ref_ui.dart';
import '../../../../shared/widgets/ref_card/ref_player_card.dart';
import '../../../chests/presentation/widgets/chest_widgets.dart';
import '../../../items/cosmetics/equipped_cosmetics.dart';
import '../viewmodel/progress_view_model.dart';
import '../widgets/progress_panel.dart';

/// GELİŞİM (Ekonomi V2, FAZ 2) — futbolcu seviyeleri, joker parçalar,
/// seviye atlama. Referans dili: geri + .sectionhead, .card-panel.
class ProgressView extends StatelessWidget {
  const ProgressView({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider<ProgressViewModel>(
        create: (_) => getIt<ProgressViewModel>()..load(),
        child: const AppShell(currentRoute: AppRoutes.collection, child: _Govde()),
      );
}

class _Govde extends StatelessWidget {
  const _Govde();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProgressViewModel>();
    final o = vm.overview;

    final List<Widget> icerik;
    if (o == null) {
      icerik = [
        if (vm.isLoading)
          const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
        else
          RefCardPanel(children: [
            Text(vm.errorMessage ?? 'Gelişim bilgisi yüklenemedi.', style: Ref.bodyText(12)),
            RefSecondaryButton('TEKRAR DENE', onTap: vm.load),
          ]),
      ];
    } else if (!o.enabled) {
      icerik = [const RefNote('Gelişim sistemi henüz açık değil.', title: 'Yakında')];
    } else {
      final liste = vm.visibleItems;
      icerik = [
        _Ozet(o),
        const SizedBox(height: Ref.pageGap),
        Wrap(spacing: 6, runSpacing: 6, children: [
          RefFilterChip('Tümü', active: !vm.onlyReady, onTap: () => vm.setOnlyReady(false)),
          RefFilterChip('Atlayabilir (${o.suggestedCount})',
              active: vm.onlyReady, onTap: () => vm.setOnlyReady(true)),
        ]),
        const SizedBox(height: Ref.pageGap),
        if (liste.isEmpty)
          const ChestHint('Şu an seviye atlayabilecek futbolcu yok. Gelişim kopyaları sandıklardan gelir.')
        else
          for (final i in liste) ...[
            _Satir(item: i, overview: o, vm: vm),
            const SizedBox(height: 9),
          ],
      ];
    }

    return ListView(
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
                    onTap: () => context.canPop() ? context.pop() : context.go(AppRoutes.collection),
                    child: const Icon(Icons.arrow_back_rounded, size: 16, color: Ref.neutralText),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(child: RefSectionHead('GELİŞİM', size: 27, kicker: 'FUTBOLCU SEVİYELERİ')),
                ]),
                const SizedBox(height: Ref.pageGap),
                ...icerik,
              ]),
            ),
          ),
        ),
      ],
    );
  }
}

class _Ozet extends StatelessWidget {
  final ProgressOverview o;
  const _Ozet(this.o);

  @override
  Widget build(BuildContext context) {
    const nadirlik = ['bronze', 'silver', 'gold', 'diamond', 'legend'];
    return RefCardPanel(children: [
      Row(children: [
        const Icon(Icons.extension_rounded, size: 17, color: Ref.purple),
        const SizedBox(width: 6),
        Expanded(child: Text('Joker parçalar', style: Ref.bodyText(13, weight: FontWeight.w700))),
        const CoinGlyph(size: 14),
        const SizedBox(width: 4),
        Text(trThousands(o.coins), style: Ref.bodyText(12, color: Ref.gold, weight: FontWeight.w900)),
      ]),
      Row(children: [
        for (final t in nadirlik)
          Expanded(
            child: Column(children: [
              Text('${o.jokers[t] ?? 0}', style: Ref.heading(18, color: Ref.text)),
              FittedBox(fit: BoxFit.scaleDown, child: Text(tierNameTr(t), style: Ref.tiny(Ref.muted))),
            ]),
          ),
      ]),
      const ChestHint('Joker parça, aynı nadirlikteki herhangi bir futbolcuda eksik gelişim kopyasının yerine geçer. '
          'Seviye dereceli maçta gücü değiştirmez.'),
    ]);
  }
}

class _Satir extends StatelessWidget {
  final PlayerProgressItem item;
  final ProgressOverview overview;
  final ProgressViewModel vm;
  const _Satir({required this.item, required this.overview, required this.vm});

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 78,
          child: RefPlayerCard(
            skin: EquippedCosmetics.current?.cardSkin,
            name: item.fullName,
            position: item.position,
            tier: item.tier,
            power: item.power,
            seed: item.cardId,
            kitSeed: item.club ?? item.nationality,
            imageUrl: item.imageUrl,
            width: 78,
            level: item.level,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: ProgressPanel(item: item, overview: overview, vm: vm, detailed: false)),
      ]);
}
