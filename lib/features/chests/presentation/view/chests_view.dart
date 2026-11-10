import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/ref_tokens.dart';
import '../../../../core/utils/turkish_text.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/ref/ref_ui.dart';
import '../viewmodel/chests_view_model.dart';
import '../widgets/chest_widgets.dart';
import 'chest_open_view.dart';

/// SANDIKLAR (Ekonomi V2, FAZ 1) — yuvalar, anında açılabilenler,
/// posta kutusu ve ödül enerjisi. Referans dili: geri + .sectionhead,
/// .card-panel, .tile.
///
/// Kurallar sunucuda (031). Bu ekran yalnız gösterir ve eylemi iletir.
class ChestsView extends StatelessWidget {
  const ChestsView({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider<ChestsViewModel>(
        create: (_) => getIt<ChestsViewModel>()..load(),
        child: const AppShell(currentRoute: AppRoutes.home, child: _Govde()),
      );
}

class _Govde extends StatelessWidget {
  const _Govde();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ChestsViewModel>();
    final env = vm.inventory;

    final List<Widget> icerik;
    if (env == null) {
      icerik = [
        if (vm.isLoading)
          const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
        else
          RefCardPanel(children: [
            Text(vm.errorMessage ?? 'Sandıklar yüklenemedi.', style: Ref.bodyText(12)),
            RefSecondaryButton('TEKRAR DENE', onTap: vm.load),
          ]),
      ];
    } else if (!env.enabled) {
      icerik = [
        const RefNote('Sandık sistemi henüz açık değil. Açıldığında her dereceli maç bir sandık kazandıracak.',
            title: 'Yakında'),
      ];
    } else {
      icerik = [
        _EnerjiPaneli(env.energy),
        const SizedBox(height: Ref.pageGap),
        RefSectionHead('YUVALAR',
            trailing: Text('${env.slots.length} / ${env.slotCount}', style: Ref.tiny(Ref.accent))),
        const SizedBox(height: 10),
        _Yuvalar(vm: vm, env: env),
        if (vm.actionError != null) ...[
          const SizedBox(height: 10),
          Text(vm.actionError!, style: Ref.bodyText(12, color: Ref.red, weight: FontWeight.w700)),
        ],
        if (env.instant.isNotEmpty) ...[
          const SizedBox(height: Ref.pageGap),
          RefSectionHead('HEMEN AÇ', trailing: Text('${env.instant.length} SANDIK', style: Ref.tiny(Ref.accent))),
          const SizedBox(height: 10),
          for (final c in env.instant) ...[
            _SatirSandik(chest: c, vm: vm, eylem: 'AÇ', onTap: () => _ac(context, vm, c)),
            const SizedBox(height: 8),
          ],
        ],
        const SizedBox(height: Ref.pageGap),
        RefSectionHead('POSTA KUTUSU',
            trailing: Text('${env.mailbox.length} / ${env.mailboxCapacity}', style: Ref.tiny(Ref.muted))),
        const SizedBox(height: 10),
        if (env.mailbox.isEmpty)
          ChestHint('Yuvalar doluyken kazandığın sandıklar burada ${env.mailboxDays} gün bekler. '
              'Süre dolarsa ya da kutu dolarsa sandık kaybolmaz, telafi altınına döner.')
        else
          for (final c in env.mailbox) ...[
            _SatirSandik(
              chest: c,
              vm: vm,
              eylem: 'YUVAYA TAŞI',
              alt: '${_kalanGun(c, env, vm.serverNow)} gün içinde taşı',
              onTap: env.hasFreeSlot ? () => vm.claimMailbox(c) : null,
            ),
            const SizedBox(height: 8),
          ],
        const SizedBox(height: Ref.pageGap),
        RefCardPanel(children: [
          Row(children: [
            const Icon(Icons.percent_rounded, size: 16, color: Ref.accent),
            const SizedBox(width: 6),
            Expanded(child: Text('Olasılıklar', style: Ref.bodyText(13, weight: FontWeight.w700))),
            Text('SÜRÜM ${env.rulesVersion}', style: Ref.tiny(Ref.muted)),
          ]),
          const ChestHint('Sandık türü ve içindeki her kartın nadirlik olasılığı sunucuda belirlenir; '
              'oranlar sürümlüdür ve her zaman buradan görülebilir.'),
          RefSecondaryButton('OLASILIKLARI GÖR', trailing: RefGlyph.arrowRight,
              onTap: () => context.push(AppRoutes.chestOdds)),
        ]),
      ];
    }

    return RefreshIndicator(
      color: Ref.accent,
      onRefresh: vm.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
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
                      onTap: () => context.canPop() ? context.pop() : context.go(AppRoutes.home),
                      child: const Icon(Icons.arrow_back_rounded, size: 16, color: Ref.neutralText),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(child: RefSectionHead('SANDIKLAR', size: 27, kicker: 'MAÇ ÖDÜLLERİ')),
                  ]),
                  const SizedBox(height: Ref.pageGap),
                  ...icerik,
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static int _kalanGun(Chest c, ChestInventory env, DateTime simdi) {
    final son = c.createdAt.add(Duration(days: env.mailboxDays));
    // Yukarı yuvarla: tam 5 gün kala "5 gün" (eskiden sınırda 6 yazıyordu)
    return (son.difference(simdi).inMinutes / 1440).ceil().clamp(0, 365);
  }
}

/// Sandığı açar ve sonucu tam ekran sahnede gösterir
Future<void> _ac(BuildContext context, ChestsViewModel vm, Chest c) async {
  final ok = await vm.open(c);
  final sonuc = vm.lastOpening;
  if (!ok || sonuc == null || !context.mounted) return;
  await Navigator.of(context).push(PageRouteBuilder<void>(
    opaque: true,
    pageBuilder: (_, _, _) => ChestOpenView(result: sonuc, onClose: () => Navigator.of(context).pop()),
    transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
  ));
  vm.clearOpening();
}

class _Yuvalar extends StatelessWidget {
  final ChestsViewModel vm;
  final ChestInventory env;
  const _Yuvalar({required this.vm, required this.env});

  @override
  Widget build(BuildContext context) {
    final kilitAcan = env.slots.any((c) => c.isUnlocking);
    Widget yuva(int no) {
      final c = env.slot(no);
      return ChestSlotTile(
        chest: c,
        slotNo: no,
        remaining: c == null ? null : vm.remaining(c),
        busy: c != null && vm.busyChestId == c.id,
        onTap: c == null
            ? null
            : c.isReady
                ? () => _ac(context, vm, c)
                // FAZ 3: anahtar / hızlandırıcı varsa seçenekler; yoksa eskisi gibi
                : vm.canUseKey(c) || vm.canSpeedUp(c)
                    ? () => _secenekler(context, vm, c, kilitAcan)
                    : c.isSealed && !kilitAcan
                        ? () => vm.startUnlock(c)
                        : null,
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      LayoutBuilder(builder: (context, k) {
        final sutun = k.maxWidth >= 520 ? env.slotCount : 2;
        final satirlar = <Widget>[];
        for (var i = 1; i <= env.slotCount; i += sutun) {
          satirlar.add(IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (var j = i; j < i + sutun; j++) ...[
                if (j > i) const SizedBox(width: 8),
                Expanded(child: j <= env.slotCount ? yuva(j) : const SizedBox.shrink()),
              ],
            ]),
          ));
        }
        return Column(children: [
          for (var i = 0; i < satirlar.length; i++) ...[if (i > 0) const SizedBox(height: 8), satirlar[i]],
        ]);
      }),
      const SizedBox(height: 10),
      ChestHint(kilitAcan
          ? 'Bir sandığın kilidi açılıyor. Aynı anda yalnız bir sandığın kilidi açılabilir.'
          : 'Kilitli bir sandığa dokun: sayaç başlar. Süre dolunca sandık açılmaya hazır olur.'),
    ]);
  }
}

/// Kilitli / sayacı çalışan sandık için seçenekler (FAZ 3 itemleri)
Future<void> _secenekler(BuildContext context, ChestsViewModel vm, Chest c, bool kilitAcan) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Ref.modalBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(21)),
        side: BorderSide(color: Ref.modalBorder),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              ChestIcon(type: c.chestType, size: 44),
              const SizedBox(width: 10),
              Expanded(
                child: Text('${c.typeName.toUpperTr()} SANDIK',
                    style: Ref.heading(20, color: chestColor(c.chestType))),
              ),
            ]),
            const SizedBox(height: 12),
            if (c.isSealed && !kilitAcan) ...[
              RefSecondaryButton('KİLİDİ AÇ (${chestDuration(Duration(seconds: c.unlockSeconds))})',
                  leadingIcon: Icons.lock_clock_rounded, onTap: () {
                Navigator.pop(ctx);
                vm.startUnlock(c);
              }),
              const SizedBox(height: 8),
            ],
            if (vm.canUseKey(c)) ...[
              RefSecondaryButton('ANAHTARLA AÇ (${vm.keyCost(c)} / ${vm.keys} anahtar)',
                  leadingIcon: Icons.vpn_key_rounded, onTap: () {
                Navigator.pop(ctx);
                vm.useKey(c);
              }),
              const SizedBox(height: 8),
            ],
            if (vm.canSpeedUp(c)) ...[
              RefSecondaryButton('2 SAAT HIZLANDIR (${vm.speedups} adet)', leadingIcon: Icons.fast_forward_rounded,
                  onTap: () {
                Navigator.pop(ctx);
                vm.speedUp(c);
              }),
              const SizedBox(height: 8),
            ],
            RefNeutralButton(label: 'VAZGEÇ', onTap: () => Navigator.pop(ctx)),
          ]),
        ),
      ),
    );

class _SatirSandik extends StatelessWidget {
  final Chest chest;
  final ChestsViewModel vm;
  final String eylem;
  final String? alt;
  final VoidCallback? onTap;
  const _SatirSandik({required this.chest, required this.vm, required this.eylem, this.alt, this.onTap});

  @override
  Widget build(BuildContext context) {
    final mesgul = vm.busyChestId == chest.id;
    return RefCardPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: [
        Row(children: [
          ChestIcon(type: chest.chestType, size: 40, glow: chest.isReady),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('${chest.typeName.toUpperTr()} SANDIK',
                  style: Ref.bodyText(12.5, color: chestColor(chest.chestType), weight: FontWeight.w900)),
              Text(alt ?? (chest.sourceType == 'match' ? 'Maç ödülü' : 'Ödül'), style: Ref.bodyText(10.5, color: Ref.muted)),
            ]),
          ),
          mesgul
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : RefNeutralButton(label: eylem, onTap: onTap),
        ]),
      ],
    );
  }
}

/// Ödül enerjisi paneli (taktik enerjisinden AYRI olduğu açıkça yazılır)
class _EnerjiPaneli extends StatelessWidget {
  final RewardEnergy e;
  const _EnerjiPaneli(this.e);

  @override
  Widget build(BuildContext context) {
    final sonraki = e.nextAt?.difference(e.serverTime);
    return RefCardPanel(children: [
      Row(children: [
        const Icon(Icons.bolt_rounded, size: 18, color: Color(0xFFFFB648)),
        const SizedBox(width: 6),
        Expanded(child: Text('Ödül enerjisi', style: Ref.bodyText(13, weight: FontWeight.w700))),
        Text('${e.energy} / ${e.max}', style: Ref.heading(20, color: e.isEmpty ? Ref.red : const Color(0xFFFFB648))),
      ]),
      RefBar(e.max == 0 ? 0 : e.energy / e.max, height: 7,
          gradient: const LinearGradient(colors: [Color(0xFFFF9B3D), Color(0xFFFFD36B)])),
      ChestHint(e.isEmpty
          ? 'Enerjin bitti. Dereceli maç yine oynanır; altın, puan ve koruma hakkı aynen gelir, yalnız sandık çıkmaz.'
              '${sonraki != null ? ' Sonraki enerji: ${chestDuration(sonraki)}.' : ''}'
          : 'Her dereceli maç 1 enerji harcar ve bir sandık kazandırır. Enerji ${e.refillMinutes} dakikada 1 dolar.'
              '${sonraki != null ? ' Sonraki: ${chestDuration(sonraki)}.' : ''}'
              ' Maç içi taktik enerjisinden ayrıdır.'),
    ]);
  }
}
