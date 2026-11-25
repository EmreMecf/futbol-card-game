import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/di/injection.dart';
import '../../../core/feedback/game_feedback.dart';
import '../../../core/router/app_routes.dart';
import '../../../ui_v21/screens/deck/v21_emergency_banner.dart';
import '../../../features/deck/presentation/viewmodel/deck_view_model.dart';
import '../rewards/v21_card_sheets.dart';
import '../../../shared/widgets/error_snackbar.dart';
import '../../ui_v21.dart';
import '../home/v21_home_nav.dart';
import '../../web/web_kit.dart';
import '../../web/web_screens.dart';
import '../../../core/l10n/app_language.dart';

/// V2.1 KADROM (referans `assets/v21/screens/deck.png`).
///
///   ‹ KADROM                              ( ● 87 GÜÇ )
///   yeşil saha: 4-4-2, 11 küçük oyuncu kartı
///   (87 GÜÇ) (11/11 KADRO)
///   [ ipucu / eksik mevki / kayıt sonucu ]
///   [ OTOMATİK DİZ ]   — kaydedilmemiş değişiklik varsa [DİZ] [KAYDET]
///
/// Oyun mantığı mevcut `DeckViewModel`'de, DEĞİŞMEDİ:
///   * dokun → o mevkiye uygun kartlardan seç (`V21CardPickerSheet`)
///   * sürükle → yalnız AYNI mevkideki yuvayla yer değiştir (4-4-2 kuralı)
///   * basılı tut → kart vurgulanır
///   * kaydedilmemiş değişiklikle çıkışta onay
///   * kadro kurulamıyorsa acil kadro afişi (Ekonomi V2, 032)
/// Kaydetme `/api/decks/:id` (sunucu doğrular).
class V21DeckScreen extends StatelessWidget {
  const V21DeckScreen({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider<DeckViewModel>(
    create: (_) => getIt<DeckViewModel>()..load(),
    child: Theme(data: V21Theme.data(context), child: const _Root()),
  );
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DeckViewModel>();
    return PopScope(
      canPop: !vm.hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave(context);
      },
      child: v21IsWeb(context)
          ? const _Body(scale: 1)
          : V21ScreenLayout(
              background: V21Background.page,
              body: (context, sc) => _Body(scale: sc.s),
              bottomNavigation: (context, sc) => V21HomeNav(currentRoute: AppRoutes.deck, scale: sc.s),
            ),
    );
  }
}

/// Kaydedilmemiş değişiklik varken çıkış onayı. true: çık.
Future<bool> _askLeave(BuildContext context) async {
  final r = await V21GameDialog.show<bool>(
    context,
    subtitle: 'KAYDEDİLMEDİ'.tr,
    title: 'KADRODAN ÇIK?'.tr,
    message: 'Kadroda yaptığın değişiklikler kaydedilmedi. Çıkarsan kaybolur.'.tr,
    actions: [
      V21DialogAction('VAZGEÇ'.tr, tone: V21ButtonTone.green, result: false),
      V21DialogAction('ÇIK'.tr, tone: V21ButtonTone.red, result: true),
    ],
  );
  return r ?? false;
}

Future<void> _confirmLeave(BuildContext context) async {
  if (await _askLeave(context) && context.mounted) {
    context.canPop() ? context.pop() : context.go(AppRoutes.home);
  }
}

class _Body extends StatefulWidget {
  final double scale;
  const _Body({required this.scale});

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  int? _highlighted;
  int? _dragging;

  Future<void> _pick(DeckViewModel vm, int slot) async {
    final picked = await V21CardPickerSheet.show(
      context,
      position: formationSlotPosition(slot),
      cards: vm.availableForSlot(slot),
      current: vm.cardAt(slot),
    );
    if (picked != null) vm.placeCard(slot, picked);
  }

  Future<void> _save(DeckViewModel vm) async {
    // hf17: 11 kart dolmadan kaydedilemez → KADRO EKSİK uyarısı
    if (!vm.isComplete) return _warnInvalid(vm);
    final tekrar = vm.duplicateMessage;
    if (tekrar != null) return _warnInvalid(vm, message: tekrar);
    final ok = await vm.save();
    if (!mounted) return;
    if (!ok && vm.errorMessage != null) {
      AppSnackBar.showError(context, vm.errorMessage!);
      vm.clearError();
    } else if (!ok && vm.saveMessage != null) {
      // Sunucu doğrulaması reddetti: onun mesajıyla aynı uyarı
      await _warnInvalid(vm, message: vm.saveMessage);
    }
  }

  Future<void> _warnInvalid(DeckViewModel vm, {String? message}) async {
    final edit = await V21SquadWarning.show(
      context,
      message: message,
      missing: {for (final p in CardPosition.values) p: p.requiredCount - vm.countFor(p)},
    );
    if (!edit || !mounted) return;
    final tekrarYuva = vm.firstDuplicateSlot;
    if (tekrarYuva != null) return _pick(vm, tekrarYuva);
    for (var s = 0; s < GameRules.squadSize; s++) {
      if (vm.cardAt(s) == null) return _pick(vm, s);
    }
  }

  Future<void> _back(DeckViewModel vm) async {
    if (vm.hasUnsavedChanges && !await _askLeave(context)) return;
    if (!mounted) return;
    context.canPop() ? context.pop() : context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.scale;
    final vm = context.watch<DeckViewModel>();
    if (v21IsWeb(context)) {
      return WebDeck(
        vm: vm,
        onPick: (s) => _pick(vm, s),
        onSave: () => _save(vm),
        onDrop: (from, to) {
          vm.swapSlots(from, to);
          GameFeedback.haptic(HapticStrength.light);
          GameAudio.sfx(Sfx.squadDrop);
        },
      );
    }

    final header = Padding(
      padding: EdgeInsets.fromLTRB(12 * k, 12 * k, 8 * k, 0),
      child: V21PageTitle(
        title: 'KADROM'.tr,
        scale: k,
        onBack: () => _back(vm),
        trailing: V21ResourcePill(
          icon: V21OrbIcon(size: 24 * k, color: const Color(0xFFFF5A6E)),
          value: vm.averagePower,
          text: '{averagePower} GÜÇ'.trArgs({'averagePower': vm.averagePower}),
          semanticsName: 'takım gücü'.tr,
          semanticsLabel: 'Takım gücü {averagePower}'.trArgs({'averagePower': vm.averagePower}),
          scale: k,
        ),
      ),
    );

    final Widget content;
    if (vm.isLoading) {
      content = const Center(child: CircularProgressIndicator(color: V21Colors.goldTop));
    } else if (vm.hasError && vm.inventory.isEmpty) {
      content = ListView(
        padding: EdgeInsets.all(22 * k),
        children: [
          V21EmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'BAĞLANTI SORUNU'.tr,
            message: vm.errorMessage ?? 'Kadro yüklenemedi.'.tr,
            actionLabel: 'TEKRAR DENE'.tr,
            onAction: vm.load,
            scale: k,
          ),
        ],
      );
    } else {
      final pitch = V21SquadPitch(
        cardAt: vm.cardAt,
        links: const [],
        scale: k,
        highlighted: _dragging ?? _highlighted,
        dragging: _dragging,
        onTapSlot: (s) => _pick(vm, s),
        onHighlight: (s) => setState(() => _highlighted = s),
        onDrag: (s) => setState(() => _dragging = s),
        onDrop: (from, to) {
          vm.swapSlots(from, to);
          GameFeedback.haptic(HapticStrength.light);
          GameAudio.sfx(Sfx.squadDrop);
        },
      );
      final details = <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            V21StatOrb(value: '${vm.averagePower}', label: 'GÜÇ'.tr, color: V21StatOrb.red, scale: k),
            V21StatOrb(
              value: '${vm.totalSelected}/${GameRules.squadSize}',
              label: 'KADRO'.tr,
              color: V21StatOrb.blue,
              scale: k,
            ),
          ],
        ),
        SizedBox(height: 14 * k),
        _HintPanel(vm: vm, scale: k),
        SizedBox(height: 12 * k),
        _Actions(vm: vm, scale: k, onSave: () => _save(vm)),
      ];
      // Ekonomi V2 (032): koleksiyon formasyonu kuramıyorsa acil kadro
      final banner = [if (!vm.isComplete) EmergencySquadBanner(onClaimed: vm.load)];
      if (V21Scale.of(context).isExpanded) {
        // Yatay tablet ve masaüstü: saha pencereye sığar, bilgiler yanında
        content = LayoutBuilder(
          builder: (context, box) {
            final byHeight = (box.maxHeight - 24 * k) * 364 / 448;
            final pitchWidth = math.min(box.maxWidth * 0.6, math.max(byHeight, 300.0));
            return ListView(
              padding: EdgeInsets.fromLTRB(12 * k, 0, 12 * k, 20 * k),
              children: [
                ...banner,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: pitchWidth, child: pitch),
                    SizedBox(width: 16 * k),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: details)),
                  ],
                ),
              ],
            );
          },
        );
      } else {
        content = ListView(
          padding: EdgeInsets.fromLTRB(12 * k, 0, 12 * k, 20 * k),
          children: [
            ...banner,
            Center(
              child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: pitch),
            ),
            SizedBox(height: 18 * k),
            ...details,
          ],
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        SizedBox(height: 12 * k),
        Expanded(child: content),
      ],
    );
  }
}

class _HintPanel extends StatelessWidget {
  final DeckViewModel vm;
  final double scale;
  const _HintPanel({required this.vm, required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final missing = vm.missingMessage;
    final saved = vm.saveMessage;
    final (text, color) = missing != null
        ? (missing, const Color(0xFFFF8A9B))
        : saved != null
        ? (saved, V21Colors.successText)
        : ('Kartı seçmek için boş yuvaya dokun, yer değiştirmek için sürükle'.tr, V21Colors.textMuted);
    return Container(
      padding: EdgeInsets.fromLTRB(14 * k, 8 * k, 14 * k, 8 * k),
      constraints: BoxConstraints(minHeight: 48 * k),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1150),
        borderRadius: BorderRadius.circular(14 * k),
        border: Border.all(color: V21Colors.ink, width: 2 * k),
      ),
      child: Semantics(
        liveRegion: missing != null || saved != null,
        child: Text(
          text,
          style: V21Type.label(13 * k, weight: FontWeight.w700, color: color),
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  final DeckViewModel vm;
  final double scale;
  final VoidCallback onSave;
  const _Actions({required this.vm, required this.scale, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    if (!vm.hasUnsavedChanges) {
      return V21GameButton(
        label: 'OTOMATİK DİZ'.tr,
        tone: V21ButtonTone.green,
        size: V21ButtonSize.large,
        scale: k,
        semanticsLabel: 'Otomatik diz: en güçlü kartlarla doldur'.tr,
        onPressed: vm.autoFillBest,
      );
    }
    return Row(
      children: [
        Expanded(
          child: V21GameButton(
            label: 'OTOMATİK DİZ'.tr,
            tone: V21ButtonTone.blue,
            size: V21ButtonSize.large,
            scale: k,
            onPressed: vm.autoFillBest,
          ),
        ),
        SizedBox(width: 10 * k),
        Expanded(
          child: V21GameButton(
            label: 'KAYDET'.tr,
            tone: V21ButtonTone.green,
            size: V21ButtonSize.large,
            scale: k,
            // Eksik kadroda da basılabilir: KADRO EKSİK uyarısını açar (hf17)
            status: vm.isSaving ? V21ButtonStatus.loading : V21ButtonStatus.normal,
            semanticsLabel: vm.canSave ? 'Kadroyu kaydet'.tr : 'Kaydet: kadro eksik, eksik mevkileri göster'.tr,
            onPressed: onSave,
          ),
        ),
      ],
    );
  }
}
