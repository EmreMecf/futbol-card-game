import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/ref_tokens.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/error_snackbar.dart';
import '../../../../shared/widgets/ref/ref_ui.dart';
import '../../../deck/presentation/view/deck_view.dart' show SquadSlotTile;
import '../../../deck/presentation/widgets/card_picker_sheet.dart';
import '../../../deck/presentation/widgets/formation_pitch.dart';
import '../viewmodel/sbc_builder_view_model.dart';
import '../widgets/requirement_checklist.dart';
import 'sbc_result_view.dart';

/// Görev kadrosu kurma ekranı — kadro ekranının referans sahası
/// (.field + .squad-slot) ve aynı panel dili. Görev şartları, eritilecek
/// güç ve gönderme (onaylı, geri alınamaz) korunur.
class SbcBuilderView extends StatelessWidget {
  final SbcChallenge challenge;

  const SbcBuilderView({super.key, required this.challenge});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SbcBuilderViewModel>(
      create: (_) => getIt<SbcBuilderViewModel>(param1: challenge)..load(),
      child: const _Govde(),
    );
  }
}

class _Govde extends StatefulWidget {
  const _Govde();

  @override
  State<_Govde> createState() => _GovdeState();
}

class _GovdeState extends State<_Govde> {
  int? _vurgulanan;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SbcBuilderViewModel>();

    final sonuc = vm.result;
    if (sonuc != null) {
      return SbcResultView(
        result: sonuc,
        onClose: () {
          vm.clearResult();
          Navigator.pop(context);
        },
      );
    }

    return AppShell(
      currentRoute: AppRoutes.sbc,
      child: vm.isLoading
          ? const Center(child: CircularProgressIndicator(color: Ref.accent))
          : LayoutBuilder(builder: (context, k) {
              final genis = k.maxWidth >= 900;
              final saha = _Saha(
                viewModel: vm,
                vurgulanan: _vurgulanan,
                onBasildi: (s) => setState(() => _vurgulanan = s),
                onSec: (s) => _kartSec(context, vm, s),
              );
              final panel = [
                _Sartlar(viewModel: vm),
                const SizedBox(height: Ref.pageGap),
                _Gonder(viewModel: vm),
              ];
              return ListView(
                padding: Ref.pagePadding,
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: genis ? 1100 : 620),
                      child: RefPageEnter(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Row(children: [
                            RefNeutralButton(
                              padding: const EdgeInsets.all(7),
                              semanticLabel: 'Geri',
                              onTap: () => context.canPop() ? context.pop() : context.go(AppRoutes.sbc),
                              child: const Icon(Icons.arrow_back_rounded, size: 16, color: Ref.neutralText),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: RefSectionHead(vm.challenge.name, kicker: 'GÖREV')),
                          ]),
                          const SizedBox(height: Ref.pageGap),
                          if (genis)
                            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Expanded(flex: 6, child: saha),
                              const SizedBox(width: 20),
                              Expanded(
                                flex: 5,
                                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: panel),
                              ),
                            ])
                          else ...[
                            _Sartlar(viewModel: vm),
                            const SizedBox(height: Ref.pageGap),
                            saha,
                            const SizedBox(height: Ref.pageGap),
                            _Gonder(viewModel: vm),
                          ],
                        ]),
                      ),
                    ),
                  ),
                ],
              );
            }),
    );
  }

  Future<void> _kartSec(BuildContext context, SbcBuilderViewModel vm, int slot) async {
    final secilen = await CardPickerSheet.show(
      context,
      position: formationSlotPosition(slot),
      cards: vm.availableForSlot(slot),
      current: vm.cardAt(slot),
      chemistryPreview: (kart) => vm.chemistryIfPlaced(slot, kart),
    );
    if (secilen == null) return;
    vm.placeCard(slot, secilen);
  }
}

/// Şartlar: .statrow (kart · kimya · eritilecek güç) + şart listesi
class _Sartlar extends StatelessWidget {
  final SbcBuilderViewModel viewModel;
  const _Sartlar({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    return RefCardPanel(children: [
      RefStatRow([
        RefStat('${vm.totalSelected}/${GameRules.squadSize}', 'KART', valueSize: 20),
        RefStat('${vm.chemistry.total}', 'KİMYA', valueSize: 20),
        RefStat('${vm.burnValue}', 'ERİTİLECEK GÜÇ', valueSize: 20),
      ]),
      RequirementChecklist(evaluation: vm.evaluation, isSquadComplete: vm.isComplete),
      Wrap(spacing: 6, runSpacing: 6, children: [
        RefNeutralButton(label: 'Kimyaya göre doldur', onTap: vm.autoFillByChemistry),
        RefNeutralButton(label: 'En düşük kartlarla doldur', onTap: vm.autoFill),
        RefNeutralButton(label: 'Boşalt', onTap: vm.clearAll),
      ]),
    ]);
  }
}

/// Kadro ekranıyla aynı referans saha (taşmasız, genişlikle ölçeklenir)
class _Saha extends StatelessWidget {
  final SbcBuilderViewModel viewModel;
  final int? vurgulanan;
  final ValueChanged<int?> onBasildi;
  final ValueChanged<int> onSec;

  const _Saha({required this.viewModel, required this.vurgulanan, required this.onBasildi, required this.onSec});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, kisit) {
        final w = kisit.maxWidth.clamp(0.0, 560.0);
        final k = w / 362;
        final h = 353 * k;
        return Center(
          child: Container(
            width: w,
            height: h,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: const Color(0x919BD7B9), width: 2),
            ),
            child: LayoutBuilder(builder: (context, ic) {
              final iw = ic.maxWidth, ih = ic.maxHeight;
              return Stack(clipBehavior: Clip.none, children: [
                Positioned.fill(child: CustomPaint(painter: RefFieldPainter(k))),
                Positioned.fill(
                  child: CustomPaint(
                    painter: ChemistryLinksPainter(links: viewModel.chemistry.links, highlightedSlot: vurgulanan),
                  ),
                ),
                for (final g in kSlotPositions.entries)
                  Positioned(
                    left: g.value.dx * iw - 47 * k / 2,
                    top: g.value.dy * ih - 55 * k / 2,
                    width: 47 * k,
                    height: 55 * k,
                    child: GestureDetector(
                      onTap: () => onSec(g.key),
                      onLongPressStart: (_) => onBasildi(g.key),
                      onLongPressEnd: (_) => onBasildi(null),
                      child: SquadSlotTile(
                        key: viewModel.cardAt(g.key) == null
                            ? null
                            : ValueKey('sbc-${g.key}-${viewModel.cardAt(g.key)!.userCardId}'),
                        slot: g.key,
                        card: viewModel.cardAt(g.key),
                        chemistry: viewModel.cardAt(g.key) == null ? null : viewModel.chemistry.chemistryAt(g.key),
                        k: k,
                        highlighted: vurgulanan == g.key,
                      ),
                    ),
                  ),
              ]);
            }),
          ),
        );
      });
}

class _Gonder extends StatelessWidget {
  final SbcBuilderViewModel viewModel;
  const _Gonder({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final hata = vm.evaluation.blockingError;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (hata != null) ...[
        Text(hata, textAlign: TextAlign.center, style: Ref.bodyText(12, color: Ref.red, weight: FontWeight.w700)),
        const SizedBox(height: 8),
      ],
      RefSecondaryButton(
        vm.isSubmitting
            ? 'GÖNDERİLİYOR...'
            : (vm.canSubmit ? 'KARTLARI ERİT VE ÖDÜLÜ AL' : 'ŞARTLAR TAMAMLANMADI'),
        leadingIcon: vm.canSubmit ? Icons.local_fire_department_rounded : Icons.lock_outline_rounded,
        onTap: vm.canSubmit && !vm.isSubmitting ? () => _onayAl(context) : null,
      ),
    ]);
  }

  /// GERİ ALINAMAZ bir işlem: onay almadan yapılmaz
  Future<void> _onayAl(BuildContext context) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Ref.modalBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(21),
          side: const BorderSide(color: Ref.modalBorder),
        ),
        title: Text('Kartlar kalıcı olarak silinecek', style: Ref.h3()),
        content: Text(
          '${viewModel.totalSelected} kart eritilecek ve GERİ ALINAMAZ.\n\nÖdül: ${viewModel.challenge.rewardSummary}',
          style: Ref.bodyText(13, color: Ref.muted),
        ),
        actions: [
          RefNeutralButton(label: 'VAZGEÇ', onTap: () => Navigator.pop(ctx, false)),
          RefNeutralButton(
            onTap: () => Navigator.pop(ctx, true),
            child: Text('ERİT', style: Ref.bodyText(11, color: Ref.red, weight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (onay != true || !context.mounted) return;
    final ok = await viewModel.submit();
    if (!context.mounted) return;
    if (!ok && viewModel.errorMessage != null) {
      AppSnackBar.showError(context, viewModel.errorMessage!);
      viewModel.clearError();
    }
  }
}
