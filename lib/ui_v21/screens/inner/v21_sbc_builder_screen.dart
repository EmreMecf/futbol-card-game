import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../core/di/injection.dart';
import '../../../core/router/app_routes.dart';
import '../../../features/sbc/presentation/viewmodel/sbc_builder_view_model.dart';
import '../../../shared/widgets/error_snackbar.dart';
import '../../ui_v21.dart';
import '../rewards/v21_card_sheets.dart';

/// V2.1 KART TAKASI — KADRO KURMA (HTML referansında karşılığı yok; Kadrom
/// ve Kart Takası ekranlarının dilinden).
///
///   ‹ BRONZ TEMİZLİĞİ
///   (8/11 KART) (12 KİMYA) (650 GÜÇ)   şartlar: ✓ / ✗ satırları
///   [KİMYAYA GÖRE] [EN DÜŞÜKLERLE] [BOŞALT]
///   yeşil saha (V21SquadPitch, sürükleme yok) · dokun → V21CardPickerSheet
///   [ KARTLARI ERİT VE ÖDÜLÜ AL ]   → geri alınamaz onayı → sonuç ekranı
///
/// VERİ: `SbcBuilderViewModel` (mevcut). Şartları sunucu değerlendirir;
/// gönderim `/api/sbc/:id/submit`. Eritilen kartlar KALICI olarak silinir:
/// açık onay istenir.
class V21SbcBuilderScreen extends StatelessWidget {
  final SbcChallenge challenge;
  const V21SbcBuilderScreen({super.key, required this.challenge});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider<SbcBuilderViewModel>(
    create: (_) => getIt<SbcBuilderViewModel>(param1: challenge)..load(),
    child: const _Body(),
  );
}

class _Body extends StatefulWidget {
  const _Body();

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  int? _highlighted;

  Future<void> _pick(SbcBuilderViewModel vm, int slot) async {
    final picked = await V21CardPickerSheet.show(
      context,
      position: formationSlotPosition(slot),
      cards: vm.availableForSlot(slot),
      current: vm.cardAt(slot),
    );
    if (picked != null) vm.placeCard(slot, picked);
  }

  Future<void> _submit(SbcBuilderViewModel vm) async {
    final ok = await V21GameDialog.show<bool>(
      context,
      subtitle: 'GERİ ALINAMAZ',
      title: 'KARTLAR ERİTİLSİN Mİ?',
      message:
          '${vm.totalSelected} kart kalıcı olarak silinecek ve GERİ ALINAMAZ.\n\nÖdül: ${vm.challenge.rewardSummary}',
      actions: const [
        V21DialogAction('ERİT', tone: V21ButtonTone.red, result: true),
        V21DialogAction('VAZGEÇ', tone: V21ButtonTone.blue, result: false),
      ],
    );
    if (ok != true || !mounted) return;
    final done = await vm.submit();
    if (!mounted) return;
    if (!done && vm.errorMessage != null) {
      AppSnackBar.showError(context, vm.errorMessage!);
      vm.clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SbcBuilderViewModel>();
    final result = vm.result;
    if (result != null) {
      return V21SbcResultView(
        result: result,
        onClose: () {
          vm.clearResult();
          Navigator.of(context).maybePop();
        },
      );
    }
    final ev = vm.evaluation;
    return V21InnerPage(
      title: V21Format.upper(vm.challenge.name),
      route: AppRoutes.sbcBuilderWithId(vm.challenge.id),
      fallbackRoute: AppRoutes.sbc,
      state: vm.isLoading ? V21PageState.loading : V21PageState.ready,
      children: (context, k) => [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            V21StatOrb(
              value: '${vm.totalSelected}/${GameRules.squadSize}',
              label: 'KART',
              color: V21StatOrb.blue,
              scale: k * 0.85,
            ),
            V21StatOrb(value: '${vm.burnValue}', label: 'ERİYECEK GÜÇ', color: V21StatOrb.red, scale: k * 0.85),
          ],
        ),
        SizedBox(height: 12 * k),
        _Requirements(evaluation: ev, complete: vm.isComplete, scale: k),
        SizedBox(height: 10 * k),
        Row(
          children: [
            for (final (label, action) in [
              ('EN DÜŞÜKLER', vm.autoFill),
              ('BOŞALT', vm.clearAll),
            ]) ...[
              if (label != 'EN DÜŞÜKLER') SizedBox(width: 6 * k),
              Expanded(
                child: V21GameButton(
                  label: label,
                  tone: label == 'BOŞALT' ? V21ButtonTone.purple : V21ButtonTone.blue,
                  size: V21ButtonSize.small,
                  scale: k,
                  semanticsLabel: switch (label) {
                    'EN DÜŞÜKLER' => 'En düşük kartlarla doldur',
                    _ => 'Kadroyu boşalt',
                  },
                  onPressed: action,
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: 12 * k),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: V21SquadPitch(
              cardAt: vm.cardAt,
              links: const [],
              scale: k,
              highlighted: _highlighted,
              dragging: null,
              onTapSlot: (s) => _pick(vm, s),
              onHighlight: (s) => setState(() => _highlighted = s),
            ),
          ),
        ),
        SizedBox(height: 14 * k),
        if (ev.blockingError != null) ...[
          Text(
            ev.blockingError!,
            textAlign: TextAlign.center,
            style: V21Type.label(13 * k, weight: FontWeight.w800, color: const Color(0xFFFF8A9B)),
          ),
          SizedBox(height: 8 * k),
        ],
        V21GameButton(
          label: vm.canSubmit ? 'KARTLARI ERİT VE ÖDÜLÜ AL' : 'ŞARTLAR TAMAMLANMADI',
          tone: vm.canSubmit ? V21ButtonTone.green : V21ButtonTone.purple,
          size: V21ButtonSize.large,
          scale: k,
          leadingIcon: vm.canSubmit ? Icons.local_fire_department_rounded : Icons.lock_rounded,
          status: vm.isSubmitting
              ? V21ButtonStatus.loading
              : (vm.canSubmit ? V21ButtonStatus.normal : V21ButtonStatus.disabled),
          onPressed: () => _submit(vm),
        ),
        SizedBox(height: 8 * k),
        Text(
          'Verilen kartlar kalıcı olarak silinir',
          textAlign: TextAlign.center,
          style: V21Type.label(12 * k, weight: FontWeight.w800, color: const Color(0xFFFF8A9B)),
        ),
      ],
    );
  }
}

class _Requirements extends StatelessWidget {
  final SbcEvaluation evaluation;
  final bool complete;
  final double scale;
  const _Requirements({required this.evaluation, required this.complete, required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    return V21GamePanel(
      scale: k,
      radius: 16,
      padding: EdgeInsets.fromLTRB(12 * k, 10 * k, 12 * k, 10 * k),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('ŞARTLAR', style: V21Type.title(18 * k))),
              V21Tag(
                text: evaluation.progressText,
                background: evaluation.canSubmit ? V21Colors.success : const Color(0xFF3B2F66),
                foreground: Colors.white,
                scale: k,
                fontSize: 12,
              ),
            ],
          ),
          SizedBox(height: 6 * k),
          if (!complete) _Line(text: '11 kartlık kadroyu tamamla', met: false, progress: null, scale: k),
          for (final r in evaluation.requirements)
            _Line(text: r.label, met: r.isMet, progress: r.progressText, ratio: r.ratio, scale: k),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final String text;
  final bool met;
  final String? progress;
  final double ratio;
  final double scale;
  const _Line({required this.text, required this.met, required this.progress, required this.scale, this.ratio = 0});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    return Semantics(
      label: '$text${progress == null ? '' : ', $progress'}, ${met ? 'tamam' : 'eksik'}',
      excludeSemantics: true,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 4 * k),
        child: Row(
          children: [
            Icon(
              met ? Icons.check_circle_rounded : Icons.cancel_rounded,
              size: 20 * k,
              color: met ? V21Colors.success : const Color(0xFFFF8A9B),
            ),
            SizedBox(width: 8 * k),
            Expanded(
              child: Text(
                text,
                style: V21Type.label(13 * k, weight: FontWeight.w700, color: met ? Colors.white : V21Colors.textMuted),
              ),
            ),
            if (progress != null) ...[
              SizedBox(width: 6 * k),
              SizedBox(
                width: 54 * k,
                child: V21ProgressBar(value: ratio, height: 8 * k),
              ),
              SizedBox(width: 6 * k),
              Text(progress!, style: V21Type.title(15 * k, color: met ? V21Colors.successText : V21Colors.textMuted)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Görev tamamlandı (kutlama dili: ışınlar, altın başlık, ödül kartları)
class V21SbcResultView extends StatelessWidget {
  final SbcSubmitResult result;
  final VoidCallback onClose;
  const V21SbcResultView({super.key, required this.result, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final cards = result.rewardCards;
    return Theme(
      data: V21Theme.data(context),
      child: Scaffold(
        backgroundColor: V21Colors.inkDeep,
        body: LayoutBuilder(
          builder: (context, c) {
            final k = V21Scale.forSize(c.biggest).s;
            return Stack(
              children: [
                const Positioned.fill(child: V21RaysBackground()),
                SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: V21Metrics.maxContentWidth * k),
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(16 * k, 20 * k, 16 * k, 24 * k),
                        children: [
                          Text(
                            'GÖREV TAMAMLANDI',
                            textAlign: TextAlign.center,
                            style: V21Type.title(18 * k, color: const Color(0xFFFFE6A0)),
                          ),
                          Center(child: V21HeroTitle(V21Format.upper(result.challengeName), size: 44 * k)),
                          SizedBox(height: 16 * k),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 10 * k,
                            runSpacing: 10 * k,
                            children: [
                              V21RewardCard(
                                icon: Icon(
                                  Icons.local_fire_department_rounded,
                                  size: 46 * k,
                                  color: const Color(0xFFFF7A3C),
                                ),
                                value: '${result.burnedCount}',
                                label: 'ERİTİLEN',
                                scale: k,
                              ),
                              if (result.rewardCoins > 0) V21RewardCard.coins(result.rewardCoins, scale: k),
                              if (cards.isNotEmpty)
                                V21RewardCard(
                                  icon: V21CardStackIcon(size: 46 * k),
                                  value: '+${cards.length}',
                                  label: 'KART',
                                  scale: k,
                                ),
                            ],
                          ),
                          if (cards.isNotEmpty) ...[
                            SizedBox(height: 16 * k),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 10 * k,
                              runSpacing: 12 * k,
                              children: [
                                for (final card in cards)
                                  V21PlayerCard(
                                    key: ValueKey(card.userCardId),
                                    name: card.fullName,
                                    position: card.position,
                                    tier: card.tier,
                                    power: card.power,
                                    width: 100 * k,
                                  ),
                              ],
                            ),
                          ],
                          SizedBox(height: 20 * k),
                          V21GameButton(label: 'TAMAM', size: V21ButtonSize.large, scale: k, onPressed: onClose),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
