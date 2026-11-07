import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/feedback/game_feedback.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/ref_tokens.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/error_snackbar.dart';
import '../../../../shared/widgets/ref/ref_ui.dart';
import '../viewmodel/deck_view_model.dart';
import '../widgets/card_picker_sheet.dart';
import '../widgets/formation_pitch.dart';

/// KADROM — referans `squad()` ekranı.
///
///   .sectionhead   h2 "TAKIMIM" + .pill.status "11 / 11"
///   satır          FORMASYON SEÇİMİ · KİMYA BONUSU AKTİF
///   .form-tiles    4-4-2 (etkin) · 4-3-3 · 3-5-2 (oyunda yok → pasif)
///   .field         353px saha, 47x55 .squad-slot kutuları
///   .statrow       TAKIM GÜCÜ · KİMYA · KADRO
///   .card-panel    🔗 Kimya bağlantıları + Güçlü / Orta / Zayıf
///   .secondary-button  ✓ KADROYU KAYDET
///
/// Oyun mantığı DeckViewModel'de, DEĞİŞMEDİ:
///   * dokun → o mevkiye uygun kartlardan seç
///   * sürükle → yalnızca AYNI mevkideki yuvayla yer değiştir (4-4-2 kuralı)
///   * basılı tut → o kartın kimya bağları vurgulanır
///   * kaydedilmemiş değişiklikle çıkışta onay
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
  int? _vurgulananSlot;
  int? _suruklenenSlot;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DeckViewModel>();
    return PopScope(
      canPop: !vm.hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cikisOnayi(context);
      },
      child: AppShell(currentRoute: AppRoutes.deck, child: _icerik(context, vm)),
    );
  }

  Widget _icerik(BuildContext context, DeckViewModel vm) {
    if (vm.isLoading) {
      return const Center(child: CircularProgressIndicator(color: Ref.accent));
    }
    if (vm.hasError && vm.inventory.isEmpty) {
      return ListView(padding: Ref.pagePadding, children: [
        RefCardPanel(children: [
          Text(vm.errorMessage ?? 'Kadro yüklenemedi.', style: Ref.bodyText(12)),
          RefSecondaryButton('TEKRAR DENE', onTap: vm.load),
        ]),
      ]);
    }

    final saha = _Saha(
      viewModel: vm,
      vurgulananSlot: _suruklenenSlot ?? _vurgulananSlot,
      suruklenenSlot: _suruklenenSlot,
      onSlotBasildi: (s) => setState(() => _vurgulananSlot = s),
      onSlotSecildi: (s) => _kartSec(context, vm, s),
      onSurukleme: (s) => setState(() => _suruklenenSlot = s),
      onBirakildi: (kaynak, hedef) {
        vm.swapSlots(kaynak, hedef);
        GameFeedback.haptic(HapticStrength.light);
      },
    );

    return LayoutBuilder(builder: (context, k) {
      final genis = k.maxWidth >= 900;
      final ust = [
        RefSectionHead('TAKIMIM',
            size: 27, trailing: RefPill('${vm.totalSelected} / ${GameRules.squadSize}', dot: vm.isComplete)),
        const SizedBox(height: Ref.pageGap),
        _FormasyonSatiri(viewModel: vm),
        const SizedBox(height: Ref.pageGap),
      ];
      final alt = [
        RefStatRow([
          RefStat('${vm.averagePower}', 'TAKIM GÜCÜ'),
          RefStat('${vm.chemistry.total}', 'KİMYA'),
          RefStat('${vm.totalSelected}/${GameRules.squadSize}', 'KADRO'),
        ]),
        const SizedBox(height: Ref.pageGap),
        _KimyaPaneli(viewModel: vm),
        const SizedBox(height: Ref.pageGap),
        _Kaydet(viewModel: vm),
      ];

      return ListView(
        padding: Ref.pagePadding,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: genis ? 1180 : 620),
              child: RefPageEnter(
                child: genis
                    ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        ...ust,
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 6, child: saha),
                            const SizedBox(width: 20),
                            Expanded(
                              flex: 5,
                              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: alt),
                            ),
                          ],
                        ),
                      ])
                    : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        ...ust,
                        saha,
                        const SizedBox(height: Ref.pageGap),
                        ...alt,
                      ]),
              ),
            ),
          ),
        ],
      );
    });
  }

  Future<void> _kartSec(BuildContext context, DeckViewModel vm, int slot) async {
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

  Future<void> _cikisOnayi(BuildContext context) async {
    final cik = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Ref.modalBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(21),
          side: const BorderSide(color: Ref.modalBorder),
        ),
        title: Text('Kaydedilmemiş değişiklik var', style: Ref.h3()),
        content: Text('Kadroda yaptığın değişiklikler kaydedilmedi. Çıkarsan kaybolur.',
            style: Ref.bodyText(13, color: Ref.muted)),
        actions: [
          RefNeutralButton(label: 'VAZGEÇ', onTap: () => Navigator.pop(ctx, false)),
          RefNeutralButton(
            onTap: () => Navigator.pop(ctx, true),
            child: Text('ÇIK', style: Ref.bodyText(11, color: Ref.red, weight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (cik == true && context.mounted) Navigator.pop(context);
  }
}

// ====================================================================
// FORMASYON SEÇİMİ
// ====================================================================
class _FormasyonSatiri extends StatelessWidget {
  final DeckViewModel viewModel;
  const _FormasyonSatiri({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final kimyaVar = viewModel.chemistry.total > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('FORMASYON SEÇİMİ', style: Ref.caps())),
            Text(kimyaVar ? 'KİMYA BONUSU AKTİF' : 'KİMYA BONUSU YOK',
                style: Ref.caps(kimyaVar ? Ref.accent : Ref.muted)),
          ],
        ),
        const SizedBox(height: 8),
        // .form-tiles { grid-template-columns:repeat(3,1fr); gap:7px }
        Row(
          children: [
            const Expanded(child: _FormasyonKarosu('4-4-2', etkin: true)),
            const SizedBox(width: 7),
            // Oyunda yalnızca 4-4-2 geçerli (aynı mevki eşleşmesi buna
            // bağlı). Diğerleri referanstaki gibi görünür ama PASİF.
            Expanded(
              child: Tooltip(
                message: 'Oyunda şimdilik yalnızca 4-4-2 geçerli',
                child: _FormasyonKarosu('4-3-3', etkin: false, onTap: () => _bilgi(context)),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Tooltip(
                message: 'Oyunda şimdilik yalnızca 4-4-2 geçerli',
                child: _FormasyonKarosu('3-5-2', etkin: false, onTap: () => _bilgi(context)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _bilgi(BuildContext context) => ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Oyunda şimdilik yalnızca 4-4-2 dizilişi geçerli.')),
      );
}

/// .form-tiles button { border:1px solid #3c536a; background:#13233a;
/// padding:9px 4px; border-radius:9px; font-size:11px }
/// .active { border-color:#27ecac; background:#174b3b }
class _FormasyonKarosu extends StatelessWidget {
  final String ad;
  final bool etkin;
  final VoidCallback? onTap;
  const _FormasyonKarosu(this.ad, {required this.etkin, this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: etkin,
        label: etkin ? '$ad diziliş, seçili' : '$ad diziliş, oyunda yok',
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onTap,
          child: Opacity(
            // button:disabled { opacity:.42 }
            opacity: etkin ? 1 : 0.42,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
              decoration: BoxDecoration(
                color: etkin ? const Color(0xFF174B3B) : const Color(0xFF13233A),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: etkin ? const Color(0xFF27ECAC) : const Color(0xFF3C536A)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Em('⚽', size: 11),
                  const SizedBox(width: 4),
                  Text(ad, style: Ref.bodyText(11, color: Colors.white)),
                ],
              ),
            ),
          ),
        ),
      );
}

// ====================================================================
// SAHA (.field) + OYUNCU KUTULARI (.squad-slot)
// ====================================================================
class _Saha extends StatelessWidget {
  final DeckViewModel viewModel;
  final int? vurgulananSlot;
  final int? suruklenenSlot;
  final ValueChanged<int?> onSlotBasildi;
  final ValueChanged<int> onSlotSecildi;
  final ValueChanged<int?> onSurukleme;
  final void Function(int kaynak, int hedef) onBirakildi;

  const _Saha({
    required this.viewModel,
    required this.vurgulananSlot,
    required this.suruklenenSlot,
    required this.onSlotBasildi,
    required this.onSlotSecildi,
    required this.onSurukleme,
    required this.onBirakildi,
  });

  /// Aynı mevki ve farklı yuva olmalı (4-4-2 aynı mevki kuralı)
  static bool kabulEder(int kaynak, int hedef) =>
      kaynak != hedef && formationSlotPosition(kaynak) == formationSlotPosition(hedef);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, kisit) {
      final w = kisit.maxWidth.clamp(0.0, 560.0);
      // Referans: 362 px genişlikte 353 px yükseklik
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
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(child: CustomPaint(painter: RefFieldPainter(k))),
                // Kimya bağları kutuların ALTINDA
                Positioned.fill(
                  child: CustomPaint(
                    painter: ChemistryLinksPainter(links: viewModel.links, highlightedSlot: vurgulananSlot),
                  ),
                ),
                for (final g in kSlotPositions.entries) _yuva(g.key, g.value, iw, ih, k),
              ],
            );
          }),
        ),
      );
    });
  }

  Widget _yuva(int slot, Offset konum, double w, double h, double k) {
    final kart = viewModel.cardAt(slot);
    final kaynak = suruklenenSlot;
    final surukleniyor = kaynak != null;
    final gecerli = surukleniyor && kabulEder(kaynak, slot);
    final soluk = surukleniyor && !gecerli && kaynak != slot;
    // .squad-slot { width:47px; height:55px }
    final kw = 47 * k, kh = 55 * k;

    Widget kutu({double olcek = 1, bool vurgu = false}) => SquadSlotTile(
          key: kart == null ? null : ValueKey('slot-$slot-${kart.userCardId}'),
          slot: slot,
          card: kart,
          chemistry: kart == null ? null : viewModel.chemistryAt(slot),
          k: k * olcek,
          highlighted: vurgu || vurgulananSlot == slot,
        );

    return Positioned(
      left: konum.dx * w - kw / 2,
      top: konum.dy * h - kh / 2,
      width: kw,
      height: kh,
      child: DragTarget<int>(
        onWillAcceptWithDetails: (d) => kabulEder(d.data, slot),
        onAcceptWithDetails: (d) => onBirakildi(d.data, slot),
        builder: (context, adaylar, _) {
          final ustunde = adaylar.isNotEmpty;
          Widget govde = kart == null
              ? kutu(vurgu: gecerli)
              : Draggable<int>(
                  data: slot,
                  feedback: Material(color: Colors.transparent, child: kutu(olcek: 1.15, vurgu: true)),
                  childWhenDragging: Opacity(opacity: 0.25, child: kutu()),
                  onDragStarted: () {
                    GameFeedback.haptic(HapticStrength.selection);
                    onSurukleme(slot);
                  },
                  onDragEnd: (_) => onSurukleme(null),
                  onDraggableCanceled: (_, _) => onSurukleme(null),
                  child: kutu(vurgu: gecerli),
                );
          govde = GestureDetector(
            onTap: () => onSlotSecildi(slot),
            onLongPressStart: (_) => onSlotBasildi(slot),
            onLongPressEnd: (_) => onSlotBasildi(null),
            child: govde,
          );
          return AnimatedOpacity(
            duration: Ref.cardHover,
            opacity: soluk ? 0.35 : 1,
            child: AnimatedScale(duration: Ref.cardHover, scale: ustunde ? 1.1 : 1, child: govde),
          );
        },
      ),
    );
  }
}

/// .squad-slot { width:47px; height:55px; background:linear-gradient(160deg,
/// #5a4721,#0a2033 66%); border:1px solid #e1bd63; border-radius:7px;
/// padding:4px; box-shadow:0 4px 8px #000a } span { 900 19px Barlow }
/// small { 900 9px } :hover { border-color:#71ffc9; box-shadow:0 0 17px #14f2a077 }
class SquadSlotTile extends StatelessWidget {
  final int slot;
  final InventoryCard? card;
  final int? chemistry;
  final double k;
  final bool highlighted;

  const SquadSlotTile({
    super.key,
    required this.slot,
    required this.card,
    required this.chemistry,
    this.k = 1,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final kart = card;
    final mevki = formationSlotPosition(slot);
    final kimya = chemistry;
    final kimyaRengi = kimya == null
        ? null
        : (kimya >= 5 ? ChemistryColors.strong : (kimya >= 2 ? ChemistryColors.weak : ChemistryColors.none));

    return Semantics(
      button: true,
      label: kart == null
          ? 'Boş ${mevki.label} yuvası'
          : '${kart.fullName}, ${mevki.label}, güç ${kart.power}, kimya ${kimya ?? 0}',
      excludeSemantics: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: Ref.cardHover,
            width: 47 * k,
            height: 55 * k,
            padding: EdgeInsets.all(4 * k),
            decoration: BoxDecoration(
              gradient: kart == null
                  ? null
                  : const LinearGradient(
                      begin: Alignment(-0.34, -0.94),
                      end: Alignment(0.34, 0.94),
                      colors: [Color(0xFF5A4721), Color(0xFF0A2033)],
                      stops: [0, 0.66],
                    ),
              color: kart == null ? const Color(0x990A2033) : null,
              borderRadius: BorderRadius.circular(7 * k),
              border: Border.all(
                color: highlighted
                    ? const Color(0xFF71FFC9)
                    : (kart == null ? const Color(0x55FFFFFF) : const Color(0xFFE1BD63)),
              ),
              boxShadow: [
                const BoxShadow(color: Color(0xAA000000), blurRadius: 8, offset: Offset(0, 4)),
                if (highlighted) const BoxShadow(color: Color(0x7714F2A0), blurRadius: 17),
              ],
            ),
            // Sadece sığmazsa küçülür (referans ölçüsü: 19px + 9px)
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  kart == null
                      ? Text('+', style: Ref.heading(19 * k, weight: FontWeight.w900, color: const Color(0x99FFFFFF), height: 1.1))
                      : Text('${kart.power}', style: Ref.heading(19 * k, weight: FontWeight.w900, height: 1.1)),
                  Text(mevki.code,
                      style: Ref.bodyText(9 * k,
                          weight: FontWeight.w900, color: kart == null ? const Color(0x99FFFFFF) : Colors.white)),
                ],
              ),
            ),
          ),
          // Kartın kimyası (maçta güce eklenir): sağ üst köşede renkli rozet
          if (kimya != null)
            Positioned(
              top: -5 * k,
              right: -6 * k,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 3.5 * k, vertical: 1 * k),
                decoration: BoxDecoration(
                  color: kimyaRengi,
                  borderRadius: BorderRadius.circular(7 * k),
                  border: Border.all(color: const Color(0xFF0A2033)),
                ),
                child: Text('+$kimya',
                    style: Ref.bodyText(8 * k, weight: FontWeight.w900, color: const Color(0xFF0A2033), height: 1.2)),
              ),
            ),
        ],
      ),
    );
  }
}

// ====================================================================
// KİMYA PANELİ
// ====================================================================
class _KimyaPaneli extends StatelessWidget {
  final DeckViewModel viewModel;
  const _KimyaPaneli({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final kimya = viewModel.chemistry;
    Widget hap(String emoji, String ad, int adet) => RefPill('$ad · $adet', emoji: emoji);

    return RefCardPanel(children: [
      Row(children: [
        const Em('🔗', size: 14),
        const SizedBox(width: 6),
        Text('Kimya bağlantıları', style: Ref.bodyText(14, weight: FontWeight.w700)),
      ]),
      Text(
        'Aynı kulüp ya da aynı ligde aynı uyruk +2, aynı uyruk ya da aynı lig +1. '
        'Kartın kimyası maçta gücüne eklenir. Kartı basılı tut: bağları vurgulanır.',
        style: Ref.tiny(Ref.muted).copyWith(height: 1.4),
      ),
      Wrap(spacing: 9, runSpacing: 6, children: [
        hap('🟢', 'Güçlü', kimya.strongCount),
        hap('🟡', 'Orta', kimya.weakCount),
        hap('🔴', 'Zayıf', kimya.noneCount),
      ]),
      if (viewModel.missingMessage != null)
        Text(viewModel.missingMessage!, style: Ref.bodyText(11, color: Ref.red, weight: FontWeight.w800)),
      // Otomatik dizme (oyunda gerçek; referansta yok)
      Wrap(spacing: 6, runSpacing: 6, children: [
        RefNeutralButton(label: 'Kimyaya göre diz', onTap: viewModel.autoFillByChemistry),
        RefNeutralButton(label: 'En güçlülerle doldur', onTap: viewModel.autoFillBest),
        RefNeutralButton(label: 'Kadroyu boşalt', onTap: viewModel.clearAll),
      ]),
    ]);
  }
}

// ====================================================================
// KAYDET
// ====================================================================
class _Kaydet extends StatelessWidget {
  final DeckViewModel viewModel;
  const _Kaydet({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (vm.saveMessage != null) ...[
          Text(vm.saveMessage!,
              textAlign: TextAlign.center,
              style: Ref.bodyText(12, color: vm.hasUnsavedChanges ? Ref.red : Ref.accent, weight: FontWeight.w700)),
          const SizedBox(height: 8),
        ],
        RefSecondaryButton(
          vm.isSaving ? 'KAYDEDİLİYOR...' : (vm.hasUnsavedChanges ? 'KADROYU KAYDET' : 'KADRO GÜNCEL'),
          leadingIcon: Icons.check_rounded,
          onTap: vm.canSave
              ? () async {
                  final ok = await vm.save();
                  if (!context.mounted) return;
                  if (ok) {
                    AppSnackBar.showSuccess(context, 'Kadro kaydedildi.');
                  } else if (vm.errorMessage != null) {
                    AppSnackBar.showError(context, vm.errorMessage!);
                    vm.clearError();
                  }
                }
              : null,
        ),
      ],
    );
  }
}
