import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../core/di/injection.dart';
import '../../../core/router/app_routes.dart';
import '../../../features/progress/presentation/viewmodel/progress_view_model.dart';
import '../../ui_v21.dart';
import '../../web/web_kit.dart';
import '../../web/web_screens.dart';

/// V2.1 GELİŞİM (referans `assets/v21/screens/progress.png`).
///
///   ‹ GELİŞİM                                    ( ● 2.450 )
///   ┌ JOKER PARÇALAR  ⬡4 ⬡2 ⬡1 ⬡3 ⬡0 ┐
///   [kart] SEVİYE 4  ●●●●○○○○○○  Kopya ▀▀▀░  [JOKERLE ATLA]
///   [kart] SEVİYE 10 (altın kenar) EN YÜKSEK SEVİYE ★
///
/// VERİ: `ProgressViewModel` (mevcut) → `/api/progress`, seviye atlama,
/// kopya dönüştürme, ustalık kitabı, %25 indirim. Ana eylem tek düğme
/// (SEVİYE ATLA / JOKERLE ATLA); diğerleri "SEÇENEKLER" diyaloğunda.
/// Geri alınamaz kopya dönüşümü açık onay ister. Seviye dereceli maçta güç
/// vermez.
class V21ProgressScreen extends StatelessWidget {
  const V21ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider<ProgressViewModel>(
    create: (_) => getIt<ProgressViewModel>()..load(),
    child: const _Body(),
  );
}

const _tierOrder = ['bronze', 'silver', 'gold', 'diamond', 'legend'];
const _tierColor = {
  'bronze': Color(0xFFFFAB76),
  'silver': Color(0xFFE8EEF6),
  'gold': Color(0xFFFFE07A),
  'diamond': Color(0xFF7FF3FF),
  'legend': Color(0xFFE3A9FA),
};
const _tierName = {'bronze': 'Bronz', 'silver': 'Gümüş', 'gold': 'Altın', 'diamond': 'Elmas', 'legend': 'Efsane'};

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProgressViewModel>();
    final o = vm.overview;
    if (v21IsWeb(context) && o != null && o.enabled) return WebProgress(vm: vm, overview: o);
    return V21InnerPage(
      title: 'GELİŞİM',
      route: AppRoutes.progress,
      highlightRoute: AppRoutes.collection,
      fallbackRoute: AppRoutes.collection,
      state: o == null
          ? (vm.isLoading ? V21PageState.loading : V21PageState.error)
          : (o.enabled ? V21PageState.ready : V21PageState.disabled),
      errorMessage: vm.errorMessage,
      onRetry: vm.load,
      onRefresh: vm.load,
      disabledTitle: 'GELİŞİM YAKINDA',
      disabledMessage: 'Futbolcu seviyeleri henüz açık değil.',
      trailing: (context, k) => V21ResourcePill.coins(coins: o?.coins, scale: k),
      children: (context, k) {
        final items = vm.visibleItems;
        return [
          _Jokers(overview: o!, scale: k),
          SizedBox(height: 12 * k),
          Row(
            children: [
              V21FilterPill(
                label: 'TÜMÜ',
                selected: !vm.onlyReady,
                onTap: () => vm.setOnlyReady(false),
                scale: k,
                width: 86,
              ),
              SizedBox(width: 8 * k),
              V21FilterPill(
                label: 'ATLAYABİLİR (${o.suggestedCount})',
                color: V21Colors.success,
                selected: vm.onlyReady,
                onTap: () => vm.setOnlyReady(true),
                scale: k,
                width: 160,
              ),
            ],
          ),
          if (vm.actionError != null && vm.busyCardId == null) ...[
            SizedBox(height: 10 * k),
            Text(
              vm.actionError!,
              textAlign: TextAlign.center,
              style: V21Type.label(13 * k, weight: FontWeight.w800, color: V21Colors.danger),
            ),
          ],
          SizedBox(height: 12 * k),
          if (items.isEmpty)
            V21EmptyState(
              icon: Icons.trending_up_rounded,
              title: 'ŞİMDİLİK YOK',
              message: 'Şu an seviye atlayabilecek futbolcu yok. Gelişim kopyaları sandıklardan gelir.',
              scale: k,
            )
          else
            for (final i in items) ...[_Row(item: i, overview: o, vm: vm, scale: k), SizedBox(height: 12 * k)],
          Text(
            'Seviye dereceli maçta kartın gücünü değiştirmez; ustalık göstergesidir. Kart kaybedilse de seviye korunur.',
            textAlign: TextAlign.center,
            style: V21Type.label(11 * k, weight: FontWeight.w600, color: V21Colors.textDim, height: 1.4),
          ),
        ];
      },
    );
  }
}

class _Jokers extends StatelessWidget {
  final ProgressOverview overview;
  final double scale;
  const _Jokers({required this.overview, required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    return Semantics(
      container: true,
      label: 'Joker parçalar: ${[for (final t in _tierOrder) '${_tierName[t]} ${overview.jokers[t] ?? 0}'].join(', ')}',
      excludeSemantics: true,
      child: V21GamePanel(
        scale: k,
        radius: 16,
        padding: EdgeInsets.fromLTRB(14 * k, 10 * k, 10 * k, 12 * k),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'JOKER PARÇALAR',
              style: V21Type.label(13 * k, weight: FontWeight.w900, color: V21Colors.textMuted, letterSpacing: 0.4),
            ),
            SizedBox(height: 8 * k),
            Row(
              children: [
                for (final t in _tierOrder)
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        V21HexIcon(color: _tierColor[t]!, size: 38 * k),
                        SizedBox(width: 4 * k),
                        Text('${overview.jokers[t] ?? 0}', style: V21Type.title(22 * k)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final PlayerProgressItem item;
  final ProgressOverview overview;
  final ProgressViewModel vm;
  final double scale;
  const _Row({required this.item, required this.overview, required this.vm, required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final i = item;
    final coins = overview.coins;
    final next = i.next;
    final busy = vm.busyCardId == i.cardId;
    final ready = i.canLevelUp(coins);
    final withJokers = i.canLevelWithJokers(coins) && i.copies > 0;
    final hasOptions =
        next != null &&
        i.isOwned &&
        ((vm.canUseItems && i.booksAvailable > 0 && i.missingCopies > 0) ||
            (ready && overview.discounts > 0) ||
            i.convertibleCopies > 0 ||
            i.canLevelWithJokers(coins));

    final Widget action;
    if (i.isMax) {
      action = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('EN YÜKSEK SEVİYE ', style: V21Type.title(17 * k, color: V21Colors.goldTop)),
              V21StarIcon(size: 16 * k, color: V21Colors.goldTop),
            ],
          ),
          Text(
            'Gelecek kopyalar joker parçaya döner',
            style: V21Type.label(12 * k, weight: FontWeight.w600, color: V21Colors.textMuted),
          ),
        ],
      );
    } else if (ready || withJokers || busy) {
      action = V21GameButton(
        label: ready ? 'SEVİYE ATLA' : 'JOKERLE ATLA',
        tone: ready ? V21ButtonTone.green : V21ButtonTone.blue,
        size: V21ButtonSize.medium,
        scale: k,
        status: busy ? V21ButtonStatus.loading : V21ButtonStatus.normal,
        semanticsLabel: ready
            ? '${i.fullName}: seviye ${i.level + 1}\'e atla, ${next!.coins} altın'
            : '${i.fullName}: ${i.missingCopies} joker ve ${next!.coins} altınla atla',
        onPressed: () => ready ? vm.levelUp(i) : vm.levelUp(i, useJokers: true),
      );
    } else {
      action = Text(
        !i.isOwned
            ? 'Bu futbolcu şu an koleksiyonunda yok; seviyesi korunuyor.'
            : i.missingCopies > 0
            ? '${i.missingCopies} kopya daha gerekli · ${V21Format.thousands(next!.coins)} altın'
            : 'Yeterli altın yok (${V21Format.thousands(next!.coins)} altın)',
        style: V21Type.label(12 * k, weight: FontWeight.w700, color: V21Colors.textMuted),
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(10 * k, 10 * k, 12 * k, 10 * k),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16 * k),
        border: Border.all(color: i.isMax ? const Color(0xFFFFC832) : V21Colors.ink, width: 3 * k),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4A2BA8), Color(0xFF2E1675)],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          V21PlayerCard(
            name: i.fullName,
            position: i.position,
            tier: i.tier,
            power: i.power,
            width: 100 * k,
          ),
          SizedBox(width: 12 * k),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'SEVİYE ${i.level}',
                        style: V21Type.title(
                          30 * k,
                          color: i.isMax ? V21Colors.goldTop : Colors.white,
                          shadows: V21Type.inkShadow(k),
                        ),
                      ),
                    ),
                    if (hasOptions && !busy)
                      V21IconPill(
                        icon: Icons.more_horiz_rounded,
                        semanticsLabel: '${i.fullName}: diğer seçenekler',
                        scale: k * 0.85,
                        onTap: () => _options(context, i),
                      ),
                  ],
                ),
                SizedBox(height: 6 * k),
                _Pips(level: i.level, max: overview.maxLevel, scale: k),
                if (next != null) ...[
                  SizedBox(height: 8 * k),
                  Row(
                    children: [
                      Text(
                        'Kopya',
                        style: V21Type.label(12 * k, weight: FontWeight.w700, color: V21Colors.textMuted),
                      ),
                      SizedBox(width: 8 * k),
                      Expanded(
                        child: V21ProgressBar(
                          value: i.progress,
                          height: 14 * k,
                          trackColor: const Color(0xFF201046),
                          fillColors: const [Color(0xFF9EDCFF), Color(0xFF3FA2F5)],
                          semanticsLabel: 'Kopya ${i.copies} / ${next.copies}',
                        ),
                      ),
                    ],
                  ),
                ],
                SizedBox(height: 10 * k),
                action,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _options(BuildContext context, PlayerProgressItem i) async {
    final next = i.next!;
    final coins = overview.coins;
    final choice = await V21GameDialog.show<String>(
      context,
      subtitle: 'GELİŞİM',
      title: V21Format.upper(i.fullName),
      message:
          'Seviye ${i.level} · ${i.copies}/${next.copies} kopya · ${V21Format.thousands(next.coins)} altın'
          '${i.jokersAvailable > 0 ? '\n${_tierName[i.tier.name] ?? ''} joker: ${i.jokersAvailable}' : ''}',
      actions: [
        if (i.canLevelWithJokers(coins))
          V21DialogAction('JOKERLE ATLA (${i.missingCopies})', tone: V21ButtonTone.blue, result: 'jokers'),
        if (i.canLevelUp(coins) && overview.discounts > 0)
          V21DialogAction('%25 İNDİRİMLE ATLA (${V21Format.thousands(next.coins * 3 ~/ 4)})', result: 'discount'),
        if (vm.canUseItems && i.booksAvailable > 0 && i.missingCopies > 0)
          V21DialogAction('USTALIK KİTABI (${i.booksAvailable})', tone: V21ButtonTone.green, result: 'book'),
        if (i.convertibleCopies > 0)
          V21DialogAction('${i.convertibleCopies} KOPYAYI ÇEVİR', tone: V21ButtonTone.red, result: 'convert'),
        const V21DialogAction('KAPAT', tone: V21ButtonTone.purple),
      ],
    );
    if (!context.mounted) return;
    switch (choice) {
      case 'jokers':
        await vm.levelUp(i, useJokers: true);
      case 'discount':
        await vm.levelUp(i, useDiscount: true);
      case 'book':
        await vm.useBook(i);
      case 'convert':
        final ok = await V21GameDialog.show<bool>(
          context,
          subtitle: 'GERİ ALINAMAZ',
          title: 'KOPYALAR ÇEVRİLSİN Mİ?',
          message:
              '${i.fullName}: ${i.convertibleCopies} fiziksel kopya gelişim kopyasına dönüşecek ve koleksiyonundan '
              'çıkacak. Bu işlem GERİ ALINAMAZ. Koleksiyonunda en az ${overview.convertKeep} kopya kalır; destedeki ve '
              'maçtaki kartlara dokunulmaz.',
          actions: [
            V21DialogAction('ÇEVİR (${i.convertibleCopies})', tone: V21ButtonTone.red, result: true),
            const V21DialogAction('VAZGEÇ', tone: V21ButtonTone.blue, result: false),
          ],
        );
        if (ok == true) await vm.convert(i, i.convertibleCopies);
    }
  }
}

/// 10 seviye noktası (referans: dolu yeşil, boş koyu)
class _Pips extends StatelessWidget {
  final int level;
  final int max;
  final double scale;
  const _Pips({required this.level, required this.max, required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    return Semantics(
      label: 'Seviye $level / $max',
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, c) {
          final d = ((c.maxWidth - (max - 1) * 4 * k) / max).clamp(6.0, 20 * k);
          return Row(
            children: [
              for (var i = 1; i <= max; i++) ...[
                if (i > 1) SizedBox(width: 4 * k),
                Container(
                  width: d,
                  height: d,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: V21Colors.ink, width: 2 * k),
                    gradient: i <= level ? const RadialGradient(colors: [Color(0xFFB8FFB0), Color(0xFF3DD15A)]) : null,
                    color: i <= level ? null : const Color(0xFF231353),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
