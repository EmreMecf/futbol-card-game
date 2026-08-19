import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/error_snackbar.dart';
import '../../../../shared/widgets/premium_card/premium_card.dart';
import '../viewmodel/deck_view_model.dart';
import '../widgets/card_picker_sheet.dart';
import '../widgets/formation_pitch.dart';

/// Kadro düzenleme ekranı — kimya sistemiyle.
///
/// Kartlar sahada formasyona göre diziliyor, aralarındaki kimya bağları
/// renkli çizgilerle gösteriliyor:
///   Yeşil = +2 (aynı kulüp, ya da aynı ligde aynı uyruk)
///   Sarı  = +1 (aynı uyruk ya da aynı lig)
///   Kırmızı = bağ yok
class DeckView extends StatelessWidget {
  const DeckView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<DeckViewModel>(
      create: (_) => getIt<DeckViewModel>()..load(),
      child: const _DeckBody(),
    );
  }
}

class _DeckBody extends StatefulWidget {
  const _DeckBody();

  @override
  State<_DeckBody> createState() => _DeckBodyState();
}

class _DeckBodyState extends State<_DeckBody> {
  /// Dokunulan slot — bağlantıları vurgulanır
  int? _vurgulananSlot;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DeckViewModel>();

    return PopScope(
      canPop: !vm.hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cikisOnayi(context, vm);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kadrom'),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.auto_fix_high),
              color: AppColors.surface,
              onSelected: (secim) {
                switch (secim) {
                  case 'kimya':
                    vm.autoFillByChemistry();
                  case 'guc':
                    vm.autoFillBest();
                  case 'temizle':
                    vm.clearAll();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem<String>(
                  value: 'kimya',
                  child: Text('Kimyaya göre diz'),
                ),
                PopupMenuItem<String>(
                  value: 'guc',
                  child: Text('En güçlülerle doldur'),
                ),
                PopupMenuItem<String>(
                  value: 'temizle',
                  child: Text('Kadroyu boşalt'),
                ),
              ],
            ),
          ],
        ),
        body: SafeArea(child: _icerik(context, vm)),
      ),
    );
  }

  Widget _icerik(BuildContext context, DeckViewModel vm) {
    if (vm.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (vm.hasError && vm.inventory.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: AppColors.danger),
              const SizedBox(height: 16),
              Text(
                vm.errorMessage ?? 'Kadro yüklenemedi.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: vm.load,
                icon: const Icon(Icons.refresh),
                label: const Text('Tekrar dene'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        _KimyaBandi(viewModel: vm),
        Expanded(
          child: _Saha(
            viewModel: vm,
            vurgulananSlot: _vurgulananSlot,
            onSlotBasildi: (slot) => setState(() => _vurgulananSlot = slot),
            onSlotSecildi: (slot) => _kartSec(context, vm, slot),
          ),
        ),
        _KaydetBandi(viewModel: vm),
      ],
    );
  }

  Future<void> _kartSec(
    BuildContext context,
    DeckViewModel vm,
    int slot,
  ) async {
    final adaylar = vm.availableForSlot(slot);

    final secilen = await CardPickerSheet.show(
      context,
      position: formationSlotPosition(slot),
      cards: adaylar,
      current: vm.cardAt(slot),
      // Her kartın yanında o slota konursa alacağı kimya gösteriliyor.
      // Kimyayı görmeden seçim yapmak sistemi anlaşılmaz kılardı.
      chemistryPreview: (kart) => vm.chemistryIfPlaced(slot, kart),
    );

    if (secilen == null) return;
    vm.placeCard(slot, secilen);
  }

  Future<void> _cikisOnayi(BuildContext context, DeckViewModel vm) async {
    final cik = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Kaydedilmemiş değişiklik var'),
        content: const Text(
          'Kadroda yaptığın değişiklikler kaydedilmedi. Çıkarsan kaybolur.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Çık',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (cik == true && context.mounted) Navigator.pop(context);
  }
}

// ====================================================================
// KİMYA BANDI
// ====================================================================
class _KimyaBandi extends StatelessWidget {
  final DeckViewModel viewModel;

  const _KimyaBandi({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final kimya = viewModel.chemistry;
    final tamam = viewModel.isComplete;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // ---- TAKIM KİMYASI ----
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.science_outlined,
                            size: 15, color: AppColors.accent),
                        SizedBox(width: 6),
                        Text(
                          'Takım Kimyası',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${kimya.total}',
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                          ),
                        ),
                        Text(
                          ' / ${kimya.maxTotal}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          tamam ? kimya.label : (viewModel.missingMessage ?? ''),
                          style: TextStyle(
                            color: tamam
                                ? AppColors.textPrimary
                                : AppColors.warning,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ---- ORTALAMA GÜÇ ----
              Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${viewModel.averagePower}',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      if (viewModel.averageEffectivePower >
                          viewModel.averagePower)
                        Text(
                          ' +${viewModel.averageEffectivePower - viewModel.averagePower}',
                          style: const TextStyle(
                            color: ChemistryColors.strong,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                  const Text(
                    'ort. güç',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ---- İLERLEME ÇUBUĞU ----
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: kimya.ratio,
              minHeight: 5,
              backgroundColor: AppColors.surfaceLight,
              valueColor: AlwaysStoppedAnimation(
                kimya.ratio >= 0.55
                    ? ChemistryColors.strong
                    : (kimya.ratio >= 0.30
                        ? ChemistryColors.weak
                        : ChemistryColors.none),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ---- BAĞ SAYILARI ----
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _bagSayaci(ChemistryColors.strong, kimya.strongCount, '+2'),
              const SizedBox(width: 14),
              _bagSayaci(ChemistryColors.weak, kimya.weakCount, '+1'),
              const SizedBox(width: 14),
              _bagSayaci(ChemistryColors.none, kimya.noneCount, '0'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bagSayaci(Color renk, int adet, String etiket) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 3, color: renk),
        const SizedBox(width: 5),
        Text(
          '$adet',
          style: TextStyle(
            color: renk,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        Text(
          ' ($etiket)',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10.5,
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
  final DeckViewModel viewModel;
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

          // Kart boyutu sahaya göre ölçekleniyor
          final kartGenisligi = (genislik * 0.19).clamp(52.0, 88.0);

          return Stack(
            children: [
              // ---- ZEMİN ----
              const Positioned.fill(child: PitchBackground()),

              // ---- KİMYA ÇİZGİLERİ (kartların ALTINDA) ----
              Positioned.fill(
                child: CustomPaint(
                  painter: ChemistryLinksPainter(
                    links: viewModel.links,
                    highlightedSlot: vurgulananSlot,
                  ),
                ),
              ),

              // ---- KARTLAR ----
              for (final giris in kSlotPositions.entries)
                _slotWidget(
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

  Widget _slotWidget({
    required int slot,
    required Offset konum,
    required double genislik,
    required double yukseklik,
    required double kartGenisligi,
  }) {
    final kart = viewModel.cardAt(slot);
    final kartYuksekligi = kartGenisligi / 0.70;
    final kimya = viewModel.chemistryAt(slot);

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
              _BosSlot(slot: slot, genislik: kartGenisligi)
            else
              SizedBox(
                width: kartGenisligi,
                height: kartYuksekligi,
                child: PremiumPlayerCard.fromInventory(
                  kart,
                  key: ValueKey('slot-$slot-${kart.userCardId}'),
                  width: kartGenisligi,
                  interactive: false,
                ),
              ),

            // ---- KİMYA ROZETİ ----
            if (kart != null) _kimyaRozeti(kimya),
          ],
        ),
      ),
    );
  }

  Widget _kimyaRozeti(int kimya) {
    // Kartın kimyası: bağlarından topladığı puan.
    // Maçta kart `güç + bu değer` ile oynanır.
    final renk = kimya >= 5
        ? ChemistryColors.strong
        : (kimya >= 2 ? ChemistryColors.weak : ChemistryColors.none);

    return Transform.translate(
      offset: const Offset(0, -6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: renk,
          borderRadius: BorderRadius.circular(9),
          boxShadow: [
            BoxShadow(
              color: renk.withValues(alpha: 0.5),
              blurRadius: 5,
            ),
          ],
        ),
        child: Text(
          '+$kimya',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 10,
          ),
        ),
      ),
    );
  }
}

class _BosSlot extends StatelessWidget {
  final int slot;
  final double genislik;

  const _BosSlot({required this.slot, required this.genislik});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: genislik,
      height: genislik / 0.70,
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
          Icon(
            Icons.add,
            size: genislik * 0.3,
            color: Colors.white.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 2),
          Text(
            formationSlotPosition(slot).shortLabel,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontWeight: FontWeight.w700,
              fontSize: genislik * 0.14,
            ),
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// KAYDET BANDI
// ====================================================================
class _KaydetBandi extends StatelessWidget {
  final DeckViewModel viewModel;

  const _KaydetBandi({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (viewModel.saveMessage != null) ...[
            Text(
              viewModel.saveMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: viewModel.hasUnsavedChanges
                    ? AppColors.danger
                    : AppColors.success,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 8),
          ],
          AppButton(
            label: viewModel.hasUnsavedChanges
                ? 'KADROYU KAYDET'
                : 'KADRO GÜNCEL',
            icon: viewModel.hasUnsavedChanges ? Icons.save : Icons.check,
            isLoading: viewModel.isSaving,
            onPressed: viewModel.canSave
                ? () async {
                    final basarili = await viewModel.save();
                    if (!context.mounted) return;

                    if (basarili) {
                      AppSnackBar.showSuccess(context, 'Kadro kaydedildi.');
                    } else if (viewModel.errorMessage != null) {
                      AppSnackBar.showError(context, viewModel.errorMessage!);
                      viewModel.clearError();
                    }
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
