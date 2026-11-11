import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/ref_tokens.dart';
import '../../../../core/utils/turkish_text.dart';
import '../../../../shared/widgets/ref/ref_ui.dart';
import '../../domain/chest_repository.dart';
import 'chest_widgets.dart';

/// Maç sonu: "SANDIK KAZANDIN" (Ekonomi V2, FAZ 1, tasarım §7).
///
/// Sandık maç bittiği AN sunucuda verilir (tetikleyici); bu panel yalnız
/// o maçın sandığını sorar. Enerji yoksa açıklayıcı not gösterir. Ekonomi
/// kapalıysa ya da maçta sandık yoksa (kısa maç) yer kaplamaz.
class MatchChestPanel extends StatefulWidget {
  final String matchId;

  /// Test ve önizleme için doğrudan veri
  final SourceChest? preview;

  const MatchChestPanel({super.key, required this.matchId, this.preview});

  @override
  State<MatchChestPanel> createState() => _MatchChestPanelState();
}

class _MatchChestPanelState extends State<MatchChestPanel> {
  SourceChest? _veri;

  @override
  void initState() {
    super.initState();
    _veri = widget.preview;
    if (_veri == null && getIt.isRegistered<ChestRepository>()) _yukle();
  }

  Future<void> _yukle() async {
    final sonuc = await getIt<ChestRepository>().fetchMatchChest(widget.matchId);
    if (!mounted) return;
    setState(() => _veri = sonuc.dataOrNull);
  }

  @override
  Widget build(BuildContext context) {
    final v = _veri;
    if (v == null) return const SizedBox.shrink();

    if (v.skippedNoEnergy) {
      return Padding(
        padding: const EdgeInsets.only(top: Ref.pageGap),
        child: RefCardPanel(children: [
          Row(children: [
            const Icon(Icons.bolt_rounded, size: 20, color: Color(0xFFFFB648)),
            const SizedBox(width: 8),
            Expanded(child: Text('Ödül enerjin bitmişti', style: Ref.bodyText(13, weight: FontWeight.w800))),
          ]),
          const ChestHint('Maç ödüllerin (altın, puan, koruma hakkı) geçerli. Sandık için enerji dolunca oyna.'),
        ]),
      );
    }

    final c = v.chest;
    final kopya = v.winCopyName;
    if (c == null) return kopya == null ? const SizedBox.shrink() : _KopyaSatiri(kopya);
    final renk = chestColor(c.chestType);
    final yer = switch (c.location) {
      // 037 (R1): enerji yoktu ama sandık yine verildi
      'instant' when v.noEnergy => 'Ödül enerjin yoktu: Bronz sandık (hemen açılır)',
      'instant' => 'Hemen açılabilir',
      'slot' => '${c.slotNo}. yuvaya kondu',
      _ => c.status == ChestStatus.compensated
          ? 'Kutu doluydu: ${(c.result?['compensation_coins'] as num?)?.toInt() ?? 0} altın telafi'
          : 'Yuvalar dolu: posta kutusunda bekliyor',
    };

    final sandik = Padding(
      padding: const EdgeInsets.only(top: Ref.pageGap),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          gradient: Ref.cardPanelGradient,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: renk.withValues(alpha: 0.7)),
        ),
        child: Row(children: [
          ChestIcon(type: c.chestType, size: 58, glow: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('SANDIK KAZANDIN', style: Ref.caps(Ref.gold)),
              const SizedBox(height: 2),
              Text('${c.typeName.toUpperTr()} SANDIK', style: Ref.heading(20, color: renk)),
              Text(yer, style: Ref.bodyText(11, color: Ref.muted)),
            ]),
          ),
          if (c.status != ChestStatus.compensated)
            RefNeutralButton(label: 'SANDIKLAR', onTap: () => context.push(AppRoutes.chests)),
        ]),
      ),
    );
    if (kopya == null) return sandik;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [sandik, _KopyaSatiri(kopya)]);
  }
}

/// 037 (R3): galibiyette kadrodaki bir futbolcuya +1 gelişim kopyası
class _KopyaSatiri extends StatelessWidget {
  final String ad;
  const _KopyaSatiri(this.ad);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: RefCardPanel(children: [
          Row(children: [
            const Icon(Icons.trending_up_rounded, size: 20, color: Ref.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text('+1 GELİŞİM KOPYASI: $ad',
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: Ref.bodyText(13, weight: FontWeight.w800)),
            ),
            RefNeutralButton(label: 'GELİŞİM', onTap: () => context.push(AppRoutes.progress)),
          ]),
        ]),
      );
}
