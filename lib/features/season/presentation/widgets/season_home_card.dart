import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/ref_tokens.dart';
import '../../../../shared/widgets/ref/ref_ui.dart';
import '../../domain/season_repository.dart';
import '../viewmodel/season_view_model.dart';
import 'season_widgets.dart';

/// Ana sayfa GÜNLÜK GÖREVLER (FAZ 4): bugünün görevleri + sezon kademesi.
/// Sezon servisi kayıtlı değilse ya da ekonomi kapalıysa [fallback]
/// (eski "yakında" kartı) gösterilir.
class SeasonHomeCard extends StatelessWidget {
  final Widget fallback;
  const SeasonHomeCard({super.key, required this.fallback});

  @override
  Widget build(BuildContext context) {
    if (!getIt.isRegistered<SeasonViewModel>()) return fallback;
    return ChangeNotifierProvider<SeasonViewModel>(
      create: (_) => getIt<SeasonViewModel>()..load(),
      child: _Kart(fallback: fallback),
    );
  }
}

class _Kart extends StatelessWidget {
  final Widget fallback;
  const _Kart({required this.fallback});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SeasonViewModel>();
    final s = vm.overview;
    final g = vm.missions;
    if (s == null) return vm.isLoading ? const SizedBox.shrink() : fallback;
    if (!s.enabled) return fallback;

    final gunluk = g?.period('daily') ?? const <Mission>[];
    final biten = gunluk.where((m) => m.completed).length;
    final n = s.claimableCount;
    void git() => context.push(AppRoutes.season).then((_) => vm.load());

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      RefSectionHead('GÜNLÜK GÖREVLER',
          trailing: Text('$biten/${gunluk.length} TAMAM', style: Ref.tiny(Ref.accent))),
      const SizedBox(height: Ref.pageGap),
      RefCardPanel(children: [
        for (final m in gunluk) MissionRow(m, compact: true),
        if (gunluk.isNotEmpty) const Divider(height: 4, color: Ref.cardPanelBorder),
        Row(children: [
          const Icon(Icons.military_tech_rounded, size: 18, color: Ref.gold),
          const SizedBox(width: 6),
          Expanded(
            child: Text('${s.name} · Kademe ${s.tier}/${s.maxTier}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: Ref.bodyText(12, weight: FontWeight.w800)),
          ),
          if (n > 0) RefPill('$n ÖDÜL', leading: const Icon(Icons.redeem_rounded, size: 12, color: Ref.pillText)),
        ]),
        RefBar(s.tierProgress),
        RefSecondaryButton('SEZON YOLUNA GİT', trailing: RefGlyph.arrowRight, onTap: git),
      ]),
    ]);
  }
}

/// Maç sonu: "+100 SEZON XP" (kısa maçta ya da ekonomi kapalıyken yer kaplamaz)
class MatchSeasonXpLine extends StatefulWidget {
  final String matchId;

  /// Test ve önizleme için doğrudan veri
  final MatchSeasonXp? preview;
  const MatchSeasonXpLine({super.key, required this.matchId, this.preview});

  @override
  State<MatchSeasonXpLine> createState() => _MatchSeasonXpLineState();
}

class _MatchSeasonXpLineState extends State<MatchSeasonXpLine> {
  MatchSeasonXp? _veri;

  @override
  void initState() {
    super.initState();
    _veri = widget.preview;
    if (_veri == null && getIt.isRegistered<SeasonRepository>()) _yukle();
  }

  Future<void> _yukle() async {
    final s = await getIt<SeasonRepository>().fetchMatchXp(widget.matchId);
    if (!mounted) return;
    setState(() => _veri = s.dataOrNull);
  }

  @override
  Widget build(BuildContext context) {
    final v = _veri;
    if (v == null || v.xp <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: RefCardPanel(children: [
        Row(children: [
          const Icon(Icons.military_tech_rounded, size: 20, color: Ref.gold),
          const SizedBox(width: 8),
          Expanded(child: Text('+${v.xp} SEZON XP', style: Ref.heading(18, color: Ref.gold))),
          RefNeutralButton(label: 'SEZON YOLU', onTap: () => context.push(AppRoutes.season)),
        ]),
        if (v.noEnergy)
          Text('Sandık hakkın yoktu: bu maçta XP %25 verildi.', style: Ref.bodyText(11, color: Ref.muted)),
      ]),
    );
  }
}
