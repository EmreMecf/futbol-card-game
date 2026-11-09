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
import '../viewmodel/sbc_list_view_model.dart';
import '../widgets/requirement_checklist.dart';

/// GÖREVLER (kart görevleri) — referansın görev dili:
/// .sectionhead + "N / M TAMAMLANDI", .card-panel içinde .task satırı
/// (🎯 + başlık + ödül), .note uyarısı.
///
/// Referansta ayrı bir görev ekranı yok; ana sayfadaki "GÜNLÜK GÖREVLER"
/// panelinin dili kullanıldı. Görevler ve ödüller sunucudan.
class SbcListView extends StatelessWidget {
  const SbcListView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SbcListViewModel>(
      create: (_) => getIt<SbcListViewModel>()..load(),
      child: const AppShell(currentRoute: AppRoutes.sbc, child: _Govde()),
    );
  }
}

class _Govde extends StatelessWidget {
  const _Govde();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SbcListViewModel>();
    final toplam = vm.challenges.length;

    final List<Widget> icerik;
    if (vm.isLoading && vm.challenges.isEmpty) {
      icerik = [
        const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: Ref.accent))),
      ];
    } else if (vm.challenges.isEmpty) {
      icerik = [
        RefCardPanel(children: [
          Text(vm.errorMessage ?? 'Şu an aktif görev yok.', style: Ref.bodyText(12)),
          RefSecondaryButton('TEKRAR DENE', onTap: vm.load),
        ]),
      ];
    } else {
      icerik = [
        const RefNote(
          'Kullanmadığın kartları eritip daha değerli ödüllere çevir. Eritilen kartlar KALICI olarak silinir.',
          title: 'Kart görevleri',
        ),
        for (final grup in vm.grouped.entries) ...[
          const SizedBox(height: Ref.pageGap),
          Text(grup.key.toUpperTr(), style: Ref.caps(Ref.muted)),
          const SizedBox(height: 8),
          for (final g in grup.value) ...[
            _GorevKarti(challenge: g),
            const SizedBox(height: 9),
          ],
        ],
      ];
    }

    return RefreshIndicator(
      color: Ref.accent,
      backgroundColor: Ref.panel,
      onRefresh: vm.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: Ref.pagePadding,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: RefPageEnter(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  RefSectionHead(
                    'GÖREVLER',
                    size: 27,
                    kicker: 'KART ERİT, ÖDÜL KAZAN',
                    trailing: toplam == 0
                        ? null
                        : Text('${vm.completedCount} / $toplam TAMAMLANDI', style: Ref.tiny(Ref.accent)),
                  ),
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
}

class _GorevKarti extends StatelessWidget {
  final SbcChallenge challenge;
  const _GorevKarti({required this.challenge});

  @override
  Widget build(BuildContext context) {
    final bitti = challenge.isCompleted;
    void ac() => context.push(AppRoutes.sbcBuilderWithId(challenge.id), extra: challenge);

    return Opacity(
      opacity: bitti ? 0.55 : 1,
      child: RefCardPanel(
        onTap: bitti ? null : ac,
        children: [
          // .task { gap:10px } .em 23px · strong 11px · small muted
          Row(children: [
            Em(bitti ? '✅' : '🎯', size: 23),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(challenge.name, style: Ref.bodyText(13, weight: FontWeight.w700)),
                if (challenge.description != null)
                  Text(challenge.description!, style: Ref.bodyText(10, color: Ref.muted)),
              ]),
            ),
            if (!bitti && challenge.isRepeatable) const RefPill('TEKRARLANABİLİR'),
          ]),
          RequirementSummary(requirements: challenge.requirements),
          Container(height: 1, color: Ref.cardPanelBorder),
          Row(children: [
            const Em('🎁', size: 13),
            const SizedBox(width: 6),
            Expanded(
              child: Text('Ödül: ${challenge.rewardSummary}',
                  style: Ref.bodyText(11, color: Ref.gold, weight: FontWeight.w800)),
            ),
            if (challenge.completedCount > 0)
              Text('${challenge.completedCount} kez yapıldı', style: Ref.tiny(Ref.muted)),
          ]),
          if (!bitti) RefSecondaryButton('GÖREVE BAŞLA', trailing: RefGlyph.arrowRight, onTap: ac),
        ],
      ),
    );
  }
}
