import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/error_snackbar.dart';
import '../../../../shared/widgets/premium_card/premium_card.dart';
import '../../../deck/presentation/widgets/card_picker_sheet.dart';
import '../../../deck/presentation/widgets/formation_pitch.dart';
import '../viewmodel/sbc_builder_view_model.dart';
import '../widgets/requirement_checklist.dart';
import 'sbc_result_view.dart';

/// Görev kadrosu kurma ekranı.
class SbcBuilderView extends StatelessWidget {
  final SbcChallenge challenge;

  const SbcBuilderView({super.key, required this.challenge});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SbcBuilderViewModel>(
      create: (_) =>
          getIt<SbcBuilderViewModel>(param1: challenge)..load(),
      child: const _SbcBuilderBody(),
    );
  }
}

class _SbcBuilderBody extends StatefulWidget {
  const _SbcBuilderBody();

  @override
  State<_SbcBuilderBody> createState() => _SbcBuilderBodyState();
}

class _SbcBuilderBodyState extends State<_SbcBuilderBody> {
  int? _vurgulananSlot;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SbcBuilderViewModel>();

    // Görev tamamlandıysa ödül ekranı
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

    return Scaffold(
      appBar: AppBar(
        title: Text(vm.challenge.name),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.auto_fix_high),
            color: AppColors.surface,
            onSelected: (secim) {
              switch (secim) {
                case 'kimya':
                  vm.autoFillByChemistry();
                case 'doldur':
                  vm.autoFill();
                case 'temizle':
                  vm.clearAll();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'kimya',
                child: Text('Kimyaya göre doldur'),
              ),
              PopupMenuItem<String>(
                value: 'doldur',
                child: Text('En düşük kartlarla doldur'),
              ),
              PopupMenuItem<String>(
                value: 'temizle',
                child: Text('Kadroyu boşalt'),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: vm.isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : Column(
                children: [
                  _SartBandi(viewModel: vm),
                  Expanded(
                    child: _Saha(
                      viewModel: vm,
                      vurgulananSlot: _vurgulananSlot,
                      onSlotBasildi: (s) =>
                          setState(() => _vurgulananSlot = s),
                      onSlotSecildi: (s) => _kartSec(context, vm, s),
                    ),
                  ),
                  _GonderBandi(viewModel: vm),
                ],
              ),
      ),
    );
  }

  Future<void> _kartSec(
    BuildContext context,
    SbcBuilderViewModel vm,
    int slot,
  ) async {
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

// ====================================================================
// ŞART BANDI
// ====================================================================
class _SartBandi extends StatelessWidget {
  final SbcBuilderViewModel viewModel;

  const _SartBandi({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final degerlendirme = viewModel.evaluation;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          // ---- ÜST SATIR: kart sayısı ve kimya ----
          Row(
            children: [
              _olcum(
                '${viewModel.totalSelected}/${GameRules.squadSize}',
                'kart',
                viewModel.isComplete
                    ? AppColors.success
                    : AppColors.warning,
              ),
              const SizedBox(width: 16),
              _olcum(
                '${viewModel.chemistry.total}',
                'kimya',
                AppColors.accent,
              ),
              const Spacer(),
              if (viewModel.totalSelected > 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${viewModel.burnValue}',
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const Text(
                      'eritilecek güç',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.surfaceLight),
          const SizedBox(height: 12),

          RequirementChecklist(
            evaluation: degerlendirme,
            isSquadComplete: viewModel.isComplete,
          ),
        ],
      ),
    );
  }

  Widget _olcum(String deger, String etiket, Color renk) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          deger,
          style: TextStyle(
            color: renk,
            fontWeight: FontWeight.w900,
            fontSize: 17,
          ),
        ),
        Text(
          etiket,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

// ====================================================================
// SAHA
// ====================================================================
class _Saha extends StatelessWidget {
  final SbcBuilderViewModel viewModel;
  final int? vurgulananSlot;
  final ValueChanged<int?> onSlotBasildi;
  final ValueChanged<int> onSlotSecildi;

  const _Saha({
    required this.viewModel,
    required this.vurgulananSlot,
    required this.onSlotBasildi,
    required this.onSlotSecildi,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: LayoutBuilder(
        builder: (context, kisitlar) {
          final genislik = kisitlar.maxWidth;
          final yukseklik = kisitlar.maxHeight;
          final kartGenisligi = (genislik * 0.19).clamp(50.0, 84.0);

          return Stack(
            children: [
              const Positioned.fill(child: PitchBackground()),
              Positioned.fill(
                child: CustomPaint(
                  painter: ChemistryLinksPainter(
                    links: viewModel.chemistry.links,
                    highlightedSlot: vurgulananSlot,
                  ),
                ),
              ),
              for (final giris in kSlotPositions.entries)
                _slot(
                  slot: giris.key,
                  konum: giris.value,
                  genislik: genislik,
                  yukseklik: yukseklik,
                  kartGenisligi: kartGenisligi,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _slot({
    required int slot,
    required Offset konum,
    required double genislik,
    required double yukseklik,
    required double kartGenisligi,
  }) {
    final kart = viewModel.cardAt(slot);
    final kartYuksekligi = kartGenisligi / 0.70;
    final kimya = viewModel.chemistry.chemistryAt(slot);

    return Positioned(
      left: konum.dx * genislik - kartGenisligi / 2,
      top: konum.dy * yukseklik - kartYuksekligi / 2,
      width: kartGenisligi,
      height: kartYuksekligi + 16,
      child: GestureDetector(
        onTap: () => onSlotSecildi(slot),
        onLongPressStart: (_) => onSlotBasildi(slot),
        onLongPressEnd: (_) => onSlotBasildi(null),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (kart == null)
              Container(
                width: kartGenisligi,
                height: kartYuksekligi,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 1.4,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add,
                        size: kartGenisligi * 0.3,
                        color: Colors.white.withValues(alpha: 0.5)),
                    Text(
                      formationSlotPosition(slot).shortLabel,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w700,
                        fontSize: kartGenisligi * 0.14,
                      ),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                width: kartGenisligi,
                height: kartYuksekligi,
                child: PremiumPlayerCard.fromInventory(
                  kart,
                  key: ValueKey('sbc-$slot-${kart.userCardId}'),
                  width: kartGenisligi,
                  interactive: false,
                ),
              ),
            if (kart != null)
              Transform.translate(
                offset: const Offset(0, -6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: kimya >= 5
                        ? ChemistryColors.strong
                        : (kimya >= 2
                            ? ChemistryColors.weak
                            : ChemistryColors.none),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '+$kimya',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 9.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// GÖNDER BANDI
// ====================================================================
class _GonderBandi extends StatelessWidget {
  final SbcBuilderViewModel viewModel;

  const _GonderBandi({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final degerlendirme = viewModel.evaluation;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (degerlendirme.blockingError != null) ...[
            Text(
              degerlendirme.blockingError!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.warning,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 8),
          ],
          AppButton(
            label: viewModel.canSubmit
                ? 'KARTLARI ERİT VE ÖDÜLÜ AL'
                : 'ŞARTLAR TAMAMLANMADI',
            icon: viewModel.canSubmit
                ? Icons.local_fire_department
                : Icons.lock_outline,
            isLoading: viewModel.isSubmitting,
            color: viewModel.canSubmit ? AppColors.danger : null,
            onPressed:
                viewModel.canSubmit ? () => _onayAl(context) : null,
          ),
        ],
      ),
    );
  }

  /// GERİ ALINAMAZ bir işlem: onay almadan yapılmamalı.
  Future<void> _onayAl(BuildContext context) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Kartlar kalıcı olarak silinecek'),
        content: Text(
          '${viewModel.totalSelected} kart eritilecek ve GERİ ALINAMAZ.\n\n'
          'Ödül: ${viewModel.challenge.rewardSummary}',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Erit',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (onay != true || !context.mounted) return;

    final basarili = await viewModel.submit();
    if (!context.mounted) return;

    if (!basarili && viewModel.errorMessage != null) {
      AppSnackBar.showError(context, viewModel.errorMessage!);
      viewModel.clearError();
    }
  }
}
