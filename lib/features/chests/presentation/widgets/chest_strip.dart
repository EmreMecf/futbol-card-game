import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/ref_tokens.dart';
import '../../../../shared/widgets/ref/ref_ui.dart';
import '../viewmodel/chests_view_model.dart';
import 'chest_widgets.dart';

/// Sandık envanteri başka bir yerden değişti (ör. günlük sandık alındı):
/// değeri artırınca açık sandık şeritleri sunucudan yenilenir.
final ValueNotifier<int> chestInventoryChanged = ValueNotifier<int>(0);

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
      child: const _Yenileyici(child: _Serit()),
    );
  }
}

/// [chestInventoryChanged] sinyalinde şeridi yeniler
class _Yenileyici extends StatefulWidget {
  final Widget child;
  const _Yenileyici({required this.child});

  @override
  State<_Yenileyici> createState() => _YenileyiciState();
}

class _YenileyiciState extends State<_Yenileyici> {
  @override
  void initState() {
    super.initState();
    chestInventoryChanged.addListener(_yenile);
  }

  void _yenile() {
    if (mounted) context.read<ChestsViewModel>().refresh();
  }

  @override
  void dispose() {
    chestInventoryChanged.removeListener(_yenile);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
