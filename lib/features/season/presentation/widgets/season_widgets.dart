import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/theme/ref_tokens.dart';
import '../../../../shared/widgets/ref/ref_ui.dart';
import '../../../chests/presentation/widgets/chest_widgets.dart';
import '../../../items/presentation/view/inventory_view.dart';
import '../viewmodel/season_view_model.dart';

/// Ödülün simgesi: altın, sandık çizimi ya da item simgesi
class SeasonRewardIcon extends StatelessWidget {
  final SeasonReward reward;
  final double size;
  const SeasonRewardIcon(this.reward, {super.key, this.size = 22});

  @override
  Widget build(BuildContext context) {
    if (reward.isChest) return ChestIcon(type: reward.chestType ?? 'silver', size: size + 4);
    final (ikon, renk) = reward.isCoins ? (Icons.monetization_on_rounded, Ref.gold) : itemIcon(reward.category ?? '');
    return SizedBox(width: size + 4, height: size + 4, child: Icon(ikon, size: size, color: renk));
  }
}

/// "2 gün 5 sa", "5 sa 12 dk"
String seasonRemaining(Duration d) {
  if (d.isNegative) return 'Bitti';
  if (d.inDays > 0) return '${d.inDays} gün ${d.inHours % 24} sa';
  if (d.inHours > 0) return '${d.inHours} sa ${d.inMinutes % 60} dk';
  return '${d.inMinutes} dk';
}

/// Tek görev satırı: ad, ilerleme çubuğu, XP
class MissionRow extends StatelessWidget {
  final Mission mission;
  final bool compact;
  const MissionRow(this.mission, {super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final m = mission;
    final bitti = m.completed;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Icon(bitti ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 16, color: bitti ? Ref.accent : Ref.muted),
        const SizedBox(width: 7),
        Expanded(
          child: Text(m.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Ref.bodyText(compact ? 11 : 12,
                  weight: FontWeight.w700, color: bitti ? Ref.muted : Ref.text)),
        ),
        const SizedBox(width: 6),
        Text('${m.progress}/${m.target}', style: Ref.tiny(Ref.muted)),
        const SizedBox(width: 8),
        Text('+${trThousands(m.xp)} XP', style: Ref.bodyText(10, color: bitti ? Ref.muted : Ref.gold, weight: FontWeight.w800)),
      ]),
      const SizedBox(height: 5),
      RefBar(m.ratio, height: 5),
    ]);
  }
}

/// Kademe satırındaki ödül hücresi (ücretsiz ya da premium yol)
class SeasonRewardCell extends StatelessWidget {
  final SeasonReward reward;
  final bool reached;
  final bool claimed;
  final bool locked;
  final bool busy;
  final VoidCallback? onClaim;

  const SeasonRewardCell({
    super.key,
    required this.reward,
    required this.reached,
    required this.claimed,
    this.locked = false,
    this.busy = false,
    this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final alinabilir = onClaim != null && !busy;
    final String durum;
    final Color durumRenk;
    if (claimed) {
      durum = 'ALINDI';
      durumRenk = Ref.muted;
    } else if (busy) {
      durum = 'ALINIYOR…';
      durumRenk = Ref.accent;
    } else if (alinabilir) {
      durum = 'DOKUN, AL';
      durumRenk = Ref.accent;
    } else if (locked) {
      durum = 'KİLİTLİ';
      durumRenk = Ref.muted;
    } else {
      durum = reached ? '' : 'ULAŞILMADI';
      durumRenk = Ref.muted;
    }
    final soluk = claimed || (!reached && !alinabilir);

    return Semantics(
      button: alinabilir,
      label: '${rewardLabel(reward)}${durum.isEmpty ? '' : ', $durum'}',
      child: GestureDetector(
        onTap: alinabilir ? onClaim : null,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            gradient: Ref.cardPanelGradient,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
                color: alinabilir ? Ref.accent : Ref.cardPanelBorder.withValues(alpha: soluk ? 0.5 : 1),
                width: alinabilir ? 1.4 : 1),
          ),
          child: Opacity(
            opacity: soluk ? 0.55 : 1,
            child: Row(children: [
              Stack(clipBehavior: Clip.none, children: [
                SeasonRewardIcon(reward, size: 20),
                if (claimed)
                  const Positioned(
                      right: -3, bottom: -3, child: Icon(Icons.check_circle_rounded, size: 13, color: Ref.accent)),
                if (locked && !claimed)
                  const Positioned(right: -3, bottom: -3, child: Icon(Icons.lock_rounded, size: 12, color: Ref.muted)),
              ]),
              const SizedBox(width: 6),
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(rewardLabel(reward),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Ref.bodyText(10.5, weight: FontWeight.w800, height: 1.15)),
                  if (durum.isNotEmpty)
                    Text(durum, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ref.tiny(durumRenk)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
