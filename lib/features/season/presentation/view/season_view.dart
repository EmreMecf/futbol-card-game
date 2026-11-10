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
import '../viewmodel/season_view_model.dart';
import '../widgets/season_widgets.dart';

/// SEZON YOLU (Ekonomi V2, FAZ 4) — Battle Pass ve görevler.
///
///   özet     sezon adı, kalan süre, kademe, XP çubuğu, TÜMÜNÜ AL
///   görevler GÜNLÜK · HAFTALIK · SEZON (yalnız oynayarak)
///   ödül yolu 50 kademe × ÜCRETSİZ | PREMIUM (premium satın alma yok, K4)
///
/// Sezon XP'si ve ödüller dereceli maçta güç vermez (K1).
class SeasonView extends StatelessWidget {
  const SeasonView({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider<SeasonViewModel>(
        create: (_) => getIt<SeasonViewModel>()..load(),
        child: const AppShell(currentRoute: AppRoutes.home, child: _Govde()),
      );
}

class _Govde extends StatelessWidget {
  const _Govde();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SeasonViewModel>();
    final s = vm.overview;

    final List<Widget> icerik;
    if (s == null) {
      icerik = [
        if (vm.isLoading)
          const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
        else
          RefCardPanel(children: [
            Text(vm.errorMessage ?? 'Sezon bilgisi yüklenemedi.', style: Ref.bodyText(12)),
            RefSecondaryButton('TEKRAR DENE', onTap: vm.load),
          ]),
      ];
    } else if (!s.enabled) {
      icerik = [const RefNote('Sezon yolu henüz açık değil.', title: 'Yakında')];
    } else {
      final g = vm.missions;
      icerik = [
        _Ozet(s: s, vm: vm),
        if (vm.lastInfo != null) ...[
          const SizedBox(height: 8),
          Text(vm.lastInfo!, style: Ref.bodyText(12, color: Ref.accent, weight: FontWeight.w700)),
        ],
        if (vm.actionError != null) ...[
          const SizedBox(height: 8),
          Text(vm.actionError!, style: Ref.bodyText(12, color: Ref.red, weight: FontWeight.w700)),
        ],
        if (g != null && g.enabled) ...[
          const SizedBox(height: Ref.pageGap + 4),
          const RefSectionHead('GÖREVLER'),
          const SizedBox(height: 10),
          for (final (ad, donem) in const [('GÜNLÜK', 'daily'), ('HAFTALIK', 'weekly'), ('SEZON', 'season')])
            if (g.period(donem).isNotEmpty) ...[
              _GorevGrubu(baslik: ad, gorevler: g.period(donem)),
              const SizedBox(height: 9),
            ],
        ],
        const SizedBox(height: Ref.pageGap),
        const RefSectionHead('ÖDÜL YOLU'),
        const SizedBox(height: 10),
        _YolBasligi(premium: s.premium),
        const SizedBox(height: 6),
        for (final t in s.tiers) ...[
          _KademeSatiri(t: t, s: s, vm: vm),
          const SizedBox(height: 6),
        ],
        const SizedBox(height: Ref.pageGap),
        const RefNote(
            'Sezon XP\'si ve ödüller dereceli maçta güç vermez. Kademe başına 1.000 XP. Enerjili maç: '
            'galibiyet 100, beraberlik 70, yenilgi 60 XP; enerjisiz maçta %25. 4. turdan önce biten maç XP vermez. '
            'Sezon bitince ulaştığın ama almadığın ödüller otomatik verilir.',
            title: 'Nasıl ilerlerim?'),
      ];
    }

    return ListView(
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
                  Expanded(
                    child: RefSectionHead('SEZON YOLU',
                        size: 27, kicker: s == null || !s.enabled ? 'BATTLE PASS' : s.name.toUpperTr()),
                  ),
                ]),
                const SizedBox(height: Ref.pageGap),
                ...icerik,
              ]),
            ),
          ),
        ),
      ],
    );
  }
}

class _Ozet extends StatelessWidget {
  final SeasonOverview s;
  final SeasonViewModel vm;
  const _Ozet({required this.s, required this.vm});

  @override
  Widget build(BuildContext context) {
    final kalan = s.endsAt != null && s.serverTime != null ? s.endsAt!.difference(s.serverTime!) : null;
    final n = s.claimableCount;
    return RefCardPanel(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('KADEME', style: Ref.caps(Ref.muted)),
            Text.rich(TextSpan(children: [
              TextSpan(text: '${s.tier}', style: Ref.heading(40, color: Ref.gold, height: 1)),
              TextSpan(text: ' / ${s.maxTier}', style: Ref.heading(20, color: Ref.muted)),
            ])),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (kalan != null) RefPill('${seasonRemaining(kalan)} KALDI'),
          const SizedBox(height: 6),
          Text('${trThousands(s.xp)} XP', style: Ref.bodyText(12, weight: FontWeight.w800)),
        ]),
      ]),
      RefBar(s.tierProgress, height: 9),
      Text(
        s.isMaxed ? 'Son kademeye ulaştın.' : '${s.tier + 1}. kademeye ${trThousands(s.xpToNext)} XP',
        style: Ref.tiny(Ref.muted),
      ),
      if (n > 0)
        RefSecondaryButton(vm.busyAction == 'all' ? 'ALINIYOR…' : 'TÜMÜNÜ AL ($n)',
            leadingIcon: Icons.redeem_rounded, onTap: vm.busyAction == null ? vm.claimAll : null),
    ]);
  }
}

class _GorevGrubu extends StatelessWidget {
  final String baslik;
  final List<Mission> gorevler;
  const _GorevGrubu({required this.baslik, required this.gorevler});

  @override
  Widget build(BuildContext context) {
    final biten = gorevler.where((m) => m.completed).length;
    return RefCardPanel(children: [
      Row(children: [
        Expanded(child: Text(baslik, style: Ref.caps(Ref.accent))),
        Text('$biten/${gorevler.length} TAMAM', style: Ref.tiny(Ref.muted)),
      ]),
      for (final m in gorevler) MissionRow(m),
    ]);
  }
}

class _YolBasligi extends StatelessWidget {
  final bool premium;
  const _YolBasligi({required this.premium});

  @override
  Widget build(BuildContext context) => Row(children: [
        const SizedBox(width: 40),
        Expanded(child: Text('ÜCRETSİZ', textAlign: TextAlign.center, style: Ref.caps(Ref.accent))),
        const SizedBox(width: 6),
        Expanded(
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (!premium) ...[const Icon(Icons.lock_rounded, size: 11, color: Ref.gold), const SizedBox(width: 4)],
            Flexible(child: Text(premium ? 'PREMIUM' : 'PREMIUM (YAKINDA)',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: Ref.caps(Ref.gold))),
          ]),
        ),
      ]);
}

class _KademeSatiri extends StatelessWidget {
  final SeasonTier t;
  final SeasonOverview s;
  final SeasonViewModel vm;
  const _KademeSatiri({required this.t, required this.s, required this.vm});

  @override
  Widget build(BuildContext context) {
    final ulasti = s.isReached(t.tier);
    final simdiki = t.tier == s.tier + 1;
    return Row(children: [
      Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ulasti ? Ref.filterActiveBg : Ref.panel2,
          border: Border.all(color: ulasti ? Ref.accent : (simdiki ? Ref.gold : Ref.cardPanelBorder), width: 1.4),
        ),
        child: Text('${t.tier}',
            style: Ref.heading(15, color: ulasti ? Ref.filterActiveText : (simdiki ? Ref.gold : Ref.muted))),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: SeasonRewardCell(
          reward: t.free,
          reached: ulasti,
          claimed: t.freeClaimed,
          busy: vm.isClaiming(t.tier, 'free'),
          onClaim: vm.canClaim(t, 'free') ? () => vm.claim(t, 'free') : null,
        ),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: SeasonRewardCell(
          reward: t.premium,
          reached: ulasti,
          claimed: t.premiumClaimed,
          locked: !s.premium,
          busy: vm.isClaiming(t.tier, 'premium'),
          onClaim: vm.canClaim(t, 'premium') ? () => vm.claim(t, 'premium') : null,
        ),
      ),
    ]);
  }
}
