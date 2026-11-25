import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../core/di/injection.dart';
import '../../../core/router/app_routes.dart';
import '../rewards/v21_chest_opening.dart';
import '../../../features/chests/presentation/viewmodel/chests_view_model.dart';
import '../../ui_v21.dart';
import '../../web/web_kit.dart';
import '../../web/web_screens.dart';
import '../../../core/l10n/app_language.dart';

/// V2.1 SANDIKLAR (referans `assets/v21/screens/chests.png`).
///
///   ‹ SANDIKLAR
///   ┌ SANDIK HAKKI 7/10  ▮▮▮▮▮▮▮▯▯▯  Her 96 dk'da 1 hak · sonraki 41 dk ┐
///   YUVALAR (2×2 V21ChestCard)          Aynı anda 1 sandık açılır
///   HEMEN AÇ (anında açılabilen sandıklar)  ·  POSTA KUTUSU  ·  OLASILIKLAR
///
/// VERİ ve KURALLAR: `ChestsViewModel` (mevcut) → `/api/chests`; sayaç
/// sunucu saatine göre. Dokunma davranışı eski ekranla aynı:
///   * hazır → aç (V2.1 `V21ChestOpening` sahnesi)
///   * anahtar / hızlandırıcı varsa → seçenek diyaloğu
///   * kapalı ve başka sayaç yoksa → sayacı başlat
class V21ChestsScreen extends StatelessWidget {
  const V21ChestsScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      ChangeNotifierProvider<ChestsViewModel>(create: (_) => getIt<ChestsViewModel>()..load(), child: const _Body());
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ChestsViewModel>();
    final env = vm.inventory;
    if (v21IsWeb(context) && env != null && env.enabled) {
      final unlocking = env.slots.any((c) => c.isUnlocking);
      return WebChests(
        vm: vm,
        env: env,
        onOpen: (c) => openChest(context, vm, c),
        actionOf: (c) {
          if (vm.busyChestId == c.id) return null;
          if (c.isReady) return () => openChest(context, vm, c);
          if (vm.canUseKey(c) || vm.canSpeedUp(c)) return () => _options(context, vm, c, unlocking);
          if (c.isSealed && !unlocking) return () => vm.startUnlock(c);
          return null;
        },
      );
    }
    return V21InnerPage(
      title: 'SANDIKLAR'.tr,
      route: AppRoutes.chests,
      highlightRoute: AppRoutes.home,
      fallbackRoute: AppRoutes.home,
      state: env == null
          ? (vm.isLoading ? V21PageState.loading : V21PageState.error)
          : (env.enabled ? V21PageState.ready : V21PageState.disabled),
      errorMessage: vm.errorMessage,
      onRetry: vm.load,
      onRefresh: vm.refresh,
      disabledTitle: 'SANDIKLAR YAKINDA'.tr,
      disabledMessage: 'Sandık sistemi henüz açık değil. Açıldığında her dereceli maç bir sandık kazandıracak.'.tr,
      children: (context, k) => _content(context, vm, env!, k),
    );
  }

  List<Widget> _content(BuildContext context, ChestsViewModel vm, ChestInventory env, double k) {
    final unlocking = env.slots.any((c) => c.isUnlocking);
    return [
      _EnergyPanel(energy: env.energy, now: vm.serverNow, scale: k),
      SizedBox(height: 14 * k),
      V21SectionTitle('YUVALAR'.tr, trailing: 'Aynı anda 1 sandık açılır'.tr, scale: k),
      _SlotGrid(vm: vm, env: env, unlocking: unlocking, scale: k),
      if (vm.actionError != null) ...[
        SizedBox(height: 10 * k),
        Text(
          vm.actionError!,
          textAlign: TextAlign.center,
          style: V21Type.label(13 * k, weight: FontWeight.w800, color: V21Colors.danger),
        ),
      ],
      for (final c in env.instant) ...[
        SizedBox(height: 12 * k),
        _WideChest(
          name: '{p} SANDIK'.trArgs({'p': V21Format.upper(c.typeName)}),
          tier: c.chestType,
          subtitle: 'Maç ödülü · hazır'.tr,
          action: 'AÇ!'.tr,
          busy: vm.busyChestId == c.id,
          scale: k,
          onPressed: () => openChest(context, vm, c),
        ),
      ],
      SizedBox(height: 16 * k),
      V21SectionTitle('POSTA KUTUSU'.tr, trailing: '${env.mailbox.length} / ${env.mailboxCapacity}', scale: k),
      if (env.mailbox.isEmpty)
        Text(
          'Yuvalar doluyken kazandığın sandıklar burada {mailboxDays} gün bekler. Süre dolarsa ya da kutu dolarsa sandık kaybolmaz, telafi altınına döner.'.trArgs({'mailboxDays': env.mailboxDays}),
          style: V21Type.label(12 * k, weight: FontWeight.w600, color: V21Colors.textMuted, height: 1.4),
        )
      else
        for (final c in env.mailbox) ...[
          _WideChest(
            name: '{p} SANDIK'.trArgs({'p': V21Format.upper(c.typeName)}),
            tier: c.chestType,
            subtitle: '{p} gün içinde yuvaya taşı'.trArgs({'p': _daysLeft(c, env, vm.serverNow)}),
            action: 'TAŞI'.tr,
            tone: V21ButtonTone.blue,
            busy: vm.busyChestId == c.id,
            scale: k,
            onPressed: env.hasFreeSlot ? () => vm.claimMailbox(c) : null,
          ),
          SizedBox(height: 10 * k),
        ],
      SizedBox(height: 16 * k),
      V21GameButton(
        label: 'OLASILIKLAR'.tr,
        tone: V21ButtonTone.purple,
        size: V21ButtonSize.medium,
        leadingIcon: Icons.percent_rounded,
        scale: k,
        semanticsLabel: 'Sandık olasılıklarını gör (sürüm {rulesVersion})'.trArgs({'rulesVersion': env.rulesVersion}),
        onPressed: () => context.push(AppRoutes.chestOdds),
      ),
    ];
  }

  static int _daysLeft(Chest c, ChestInventory env, DateTime now) {
    final end = c.createdAt.add(Duration(days: env.mailboxDays));
    return (end.difference(now).inMinutes / 1440).ceil().clamp(0, 365);
  }
}

/// Sandığı açar ve sonucu mevcut tam ekran sahnede gösterir
Future<void> openChest(BuildContext context, ChestsViewModel vm, Chest c) async {
  final ok = await vm.open(c);
  if (!ok || !context.mounted) return;
  await _showOpening(context, vm);
}

/// Son açılan sandığın sahnesi (normal açılış ve elmasla açılış)
Future<void> _showOpening(BuildContext context, ChestsViewModel vm) async {
  final result = vm.lastOpening;
  if (result == null || !context.mounted) return;
  await Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: true,
      pageBuilder: (_, _, _) => V21ChestOpening(result: result, onClose: () => Navigator.of(context).pop()),
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    ),
  );
  vm.clearOpening();
}

/// Sandık hakkı paneli (referans: turuncu-kırmızı zemin, 10 hücre)
class _EnergyPanel extends StatelessWidget {
  final RewardEnergy energy;
  final DateTime now;
  final double scale;
  const _EnergyPanel({required this.energy, required this.now, required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final e = energy;
    final next = e.nextAt == null || e.isFull ? null : e.nextAt!.difference(now);
    final nextText = next == null ? '' : ' · sonraki {p} dk'.trArgs({'p': (next.inSeconds / 60).ceil().clamp(0, 9999)});
    return Semantics(
      container: true,
      label: 'Sandık hakkı {energy} / {max}. Her {refillMinutes} dakikada bir hak yenilenir{nextText}'.trArgs({'energy': e.energy, 'max': e.max, 'refillMinutes': e.refillMinutes, 'nextText': nextText}),
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.fromLTRB(14 * k, 12 * k, 14 * k, 12 * k),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16 * k),
          border: Border.all(color: V21Colors.ink, width: 3 * k),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFF9A2E), Color(0xFFE5394B)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('SANDIK HAKKI'.tr, style: V21Type.title(19 * k, shadows: V21Type.inkShadow(k * 0.7))),
                ),
                Text('${e.energy}/${e.max}', style: V21Type.title(28 * k, shadows: V21Type.inkShadow(k))),
              ],
            ),
            SizedBox(height: 8 * k),
            Row(
              children: [
                for (var i = 0; i < e.max; i++) ...[
                  if (i > 0) SizedBox(width: 5 * k),
                  Expanded(
                    child: Container(
                      height: 20 * k,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5 * k),
                        border: Border.all(color: V21Colors.ink, width: 2 * k),
                        color: i < e.energy ? null : const Color(0xFF6A1F3A),
                        gradient: i < e.energy
                            ? const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFFFFF0A8), Color(0xFFFFC94A)],
                              )
                            : null,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: 7 * k),
            Text(
              'Her {refillMinutes} dk\'da 1 hak yenilenir{nextText}'.trArgs({'refillMinutes': e.refillMinutes, 'nextText': nextText}),
              style: V21Type.label(12 * k, weight: FontWeight.w700, color: const Color(0xFFFFE6DC)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotGrid extends StatelessWidget {
  final ChestsViewModel vm;
  final ChestInventory env;
  final bool unlocking;
  final double scale;
  const _SlotGrid({required this.vm, required this.env, required this.unlocking, required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    Widget slot(int no) {
      final c = env.slot(no);
      if (c == null) {
        return V21ChestCard(state: V21ChestSlotState.empty, semanticsLabel: 'Yuva {no} boş'.trArgs({'no': no}), scale: 1);
      }
      final name = '{p} SANDIK'.trArgs({'p': V21Format.upper(c.typeName)});
      final busy = vm.busyChestId == c.id;
      VoidCallback? onTap;
      if (busy) {
        onTap = null;
      } else if (c.isReady) {
        onTap = () => openChest(context, vm, c);
      } else if (vm.canUseKey(c) || vm.canSpeedUp(c) || vm.canOpenWithGems(c)) {
        onTap = () => _options(context, vm, c, unlocking);
      } else if (c.isSealed && !unlocking) {
        onTap = () => vm.startUnlock(c);
      }
      if (c.isUnlocking) {
        final left = V21Format.countdown(vm.remaining(c) ?? Duration.zero);
        return V21ChestCard(
          state: V21ChestSlotState.unlocking,
          tier: c.chestType,
          name: name,
          footer: left,
          onTap: onTap,
          semanticsLabel: '{name} açılıyor, kalan {left}{p}'.trArgs({'name': name, 'left': left, 'p': onTap == null ? '' : ', seçenekler için dokun'.tr}),
        );
      }
      if (c.isReady) {
        return V21ChestCard(
          state: V21ChestSlotState.ready,
          tier: c.chestType,
          name: name,
          footer: 'AÇ!'.tr,
          onTap: onTap,
          semanticsLabel: '{name} hazır, açmak için dokun'.trArgs({'name': name}),
        );
      }
      final d = V21Format.shortDuration(c.unlockSeconds);
      return V21ChestCard(
        state: V21ChestSlotState.sealed,
        tier: c.chestType,
        name: name,
        footer: d,
        onTap: onTap,
        semanticsLabel: onTap == null
            ? '{name} kilitli, {d}. Başka bir sandık açılıyor'.trArgs({'name': name, 'd': d})
            : '{name} kilitli, {d}. Sayacı başlatmak için dokun'.trArgs({'name': name, 'd': d}),
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final gap = 10 * k;
        // Telefonda 2 sütun; genişledikçe 4 yuva yan yana
        final columns = ((c.maxWidth + gap) / (178 * k + gap)).floor().clamp(2, 4);
        final w = (c.maxWidth - gap * (columns - 1)) / columns;
        // Kart 178×184 tasarım ölçüsünde; genişliğe sığdırılır
        final s = w / 178;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 1; i <= env.slotCount; i++)
              SizedBox(
                width: w,
                height: 184 * s,
                child: FittedBox(child: slot(i)),
              ),
          ],
        );
      },
    );
  }
}

/// Kilitli / sayacı çalışan sandık için seçenekler (FAZ 3 itemleri)
Future<void> _options(BuildContext context, ChestsViewModel vm, Chest c, bool unlocking) async {
  final choice = await V21GameDialog.show<String>(
    context,
    subtitle: 'SANDIK'.tr,
    title: '{p} SANDIK'.trArgs({'p': V21Format.upper(c.typeName)}),
    icon: V21ChestArt.tier(c.chestType, height: 80),
    message: c.isUnlocking
        ? 'Sayaç çalışıyor. Beklemeden açmak için elmas ya da anahtar kullanabilirsin.'.tr
        : 'Sayacı başlatabilir ya da elmasla hemen açabilirsin.'.tr,
    actions: [
      if (c.isSealed && !unlocking)
        V21DialogAction(
          'KİLİDİ AÇ ({p})'.trArgs({'p': V21Format.shortDuration(c.unlockSeconds)}),
          tone: V21ButtonTone.green,
          result: 'unlock',
        ),
      if (vm.canOpenWithGems(c))
        V21DialogAction(
          'ELMASLA AÇ ({p} ELMAS · sende {gems})'.trArgs({'p': vm.gemCost(c), 'gems': vm.gems}),
          tone: V21ButtonTone.blue,
          result: 'gems',
        ),
      if (vm.canUseKey(c)) V21DialogAction('ANAHTARLA AÇ ({p} / {keys})'.trArgs({'p': vm.keyCost(c), 'keys': vm.keys}), result: 'key'),
      if (vm.canSpeedUp(c))
        V21DialogAction('2 SAAT HIZLANDIR ({speedups})'.trArgs({'speedups': vm.speedups}), tone: V21ButtonTone.blue, result: 'speed'),
      V21DialogAction('VAZGEÇ'.tr, tone: V21ButtonTone.purple),
    ],
  );
  switch (choice) {
    case 'unlock':
      await vm.startUnlock(c);
    case 'gems':
      if (await vm.openWithGems(c) && context.mounted) await _showOpening(context, vm);
    case 'key':
      await vm.useKey(c);
    case 'speed':
      await vm.speedUp(c);
  }
}

/// Geniş sandık satırı (referans "BRONZ SANDIK · Maç ödülü · hazır · AÇ!")
class _WideChest extends StatelessWidget {
  final String? tier;
  final String name;
  final String subtitle;
  final String action;
  final V21ButtonTone tone;
  final bool busy;
  final double scale;
  final VoidCallback? onPressed;

  const _WideChest({
    this.tier,
    required this.name,
    required this.subtitle,
    required this.action,
    required this.busy,
    required this.scale,
    required this.onPressed,
    this.tone = V21ButtonTone.green,
  });

  @override
  Widget build(BuildContext context) {
    final k = scale;
    return Container(
      height: 104 * k,
      padding: EdgeInsets.fromLTRB(8 * k, 6 * k, 12 * k, 6 * k),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16 * k),
        border: Border.all(color: V21Colors.ink, width: 3 * k),
        gradient: const LinearGradient(colors: [Color(0xFF4A2BA8), Color(0xFF2E1675)]),
      ),
      child: Row(
        children: [
          V21ChestArt.tier(tier, width: 104 * k),
          SizedBox(width: 8 * k),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    name,
                    style: V21Type.title(21 * k, color: const Color(0xFFFFC07A), shadows: V21Type.inkShadow(k)),
                  ),
                ),
                Text(
                  subtitle,
                  style: V21Type.label(12 * k, weight: FontWeight.w700, color: V21Colors.textMuted),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 92 * k,
            child: V21GameButton(
              label: action,
              tone: tone,
              size: V21ButtonSize.small,
              scale: k,
              status: busy
                  ? V21ButtonStatus.loading
                  : (onPressed == null ? V21ButtonStatus.disabled : V21ButtonStatus.normal),
              semanticsLabel: '$name: $action',
              onPressed: onPressed,
            ),
          ),
        ],
      ),
    );
  }
}
