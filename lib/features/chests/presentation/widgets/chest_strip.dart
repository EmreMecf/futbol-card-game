import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/ref_tokens.dart';
import '../../../../shared/widgets/ref/ref_ui.dart';
import '../viewmodel/chests_view_model.dart';
import 'chest_widgets.dart';

/// Ana sayfa SANDIK ŞERİDİ: 4 yuva + hazır sandık + posta kutusu +
/// ödül enerjisi. Ekonomi V2 kapalıysa ya da sandık servisi kayıtlı
/// değilse (testler) HİÇ yer kaplamaz.
class ChestStrip extends StatelessWidget {
  const ChestStrip({super.key});

  @override
  Widget build(BuildContext context) {
    if (!getIt.isRegistered<ChestsViewModel>()) return const SizedBox.shrink();
    return ChangeNotifierProvider<ChestsViewModel>(
      create: (_) => getIt<ChestsViewModel>()..load(),
      child: const _Serit(),
    );
  }
}

class _Serit extends StatelessWidget {
  const _Serit();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ChestsViewModel>();
    final env = vm.inventory;
    if (env == null || !env.enabled) return const SizedBox.shrink();

    void git() => context.push(AppRoutes.chests).then((_) => vm.refresh());
    final hazir = env.readyCount;

    return Padding(
      padding: const EdgeInsets.only(bottom: Ref.pageGap),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        RefSectionHead('SANDIKLAR',
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (env.mailbox.isNotEmpty) ...[
                RefPill('${env.mailbox.length}', leading: const Icon(Icons.mail_rounded, size: 12, color: Ref.pillText)),
                const SizedBox(width: 6),
              ],
              RewardEnergyPill(env.energy),
            ])),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: git,
          behavior: HitTestBehavior.opaque,
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (var i = 1; i <= env.slotCount; i++) ...[
                if (i > 1) const SizedBox(width: 7),
                Expanded(
                  child: ChestSlotTile(
                    chest: env.slot(i),
                    slotNo: i,
                    compact: true,
                    remaining: env.slot(i) == null ? null : vm.remaining(env.slot(i)!),
                    onTap: git,
                  ),
                ),
              ],
            ]),
          ),
        ),
        if (hazir > 0) ...[
          const SizedBox(height: 8),
          RefSecondaryButton('$hazir SANDIK AÇILMAYA HAZIR', leadingIcon: Icons.lock_open_rounded,
              trailing: RefGlyph.arrowRight, onTap: git),
        ],
      ]),
    );
  }
}
