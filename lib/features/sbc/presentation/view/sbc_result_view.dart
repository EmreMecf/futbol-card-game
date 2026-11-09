import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/theme/ref_tokens.dart';
import '../../../../core/utils/turkish_text.dart';
import '../../../../shared/widgets/ref/ref_ui.dart';
import '../../../../shared/widgets/ref_card/ref_player_card.dart';

/// Görev tamamlandı — referans .winpanel / paket özeti dili:
/// caps "GÖREV TAMAMLANDI", görev adı, eritilen kart + altın ödülü,
/// kazanılan kartlar (ortak ızgara kartı), .cta TAMAM.
class SbcResultView extends StatelessWidget {
  final SbcSubmitResult result;
  final VoidCallback onClose;

  const SbcResultView({super.key, required this.result, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final kartlar = result.rewardCards;
    return Scaffold(
      backgroundColor: Ref.phoneBg,
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: LayoutBuilder(builder: (context, k) {
              final sutun = k.maxWidth < 520 ? 3 : 5;
              return ListView(
                padding: Ref.pagePadding,
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        RefHero(
                          child: Column(children: [
                            Text('GÖREV TAMAMLANDI', style: Ref.caps(Ref.accent)),
                            const SizedBox(height: 10),
                            const Em('✅', size: 64),
                            const SizedBox(height: 8),
                            Text(result.challengeName.toUpperTr(),
                                textAlign: TextAlign.center, style: Ref.heading(30, height: 1)),
                            const SizedBox(height: 14),
                            RefStatRow([
                              RefStat('${result.burnedCount}', 'ERİTİLEN KART', valueSize: 22),
                              RefStat(result.rewardCoins > 0 ? '+${result.rewardCoins}' : '—', 'ALTIN', valueSize: 22),
                              RefStat('${kartlar.length}', 'ÖDÜL KARTI', valueSize: 22),
                            ]),
                          ]),
                        ),
                        if (kartlar.isNotEmpty) ...[
                          const SizedBox(height: Ref.pageGap),
                          RefSectionHead('Kazandığın kartlar (${kartlar.length})'.toUpperTr()),
                          const SizedBox(height: Ref.pageGap),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: sutun,
                              crossAxisSpacing: 7,
                              mainAxisSpacing: 7,
                              childAspectRatio: RefCardLayout.grid.aspectRatio,
                            ),
                            itemCount: kartlar.length,
                            itemBuilder: (context, i) {
                              final kk = kartlar[i];
                              return LayoutBuilder(
                                builder: (context, c) => RefPlayerCard(
                                  key: ValueKey(kk.userCardId),
                                  name: kk.fullName,
                                  position: kk.position,
                                  tier: kk.tier,
                                  power: kk.power,
                                  seed: kk.cardId,
                                  kitSeed: kk.club ?? kk.nationality,
                                  imageUrl: kk.imageUrl,
                                  width: c.maxWidth,
                                ),
                              );
                            },
                          ),
                        ],
                      ]),
                    ),
                  ),
                ],
              );
            }),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: RefCta('TAMAM', fontSize: 21, onTap: onClose),
            ),
          ),
        ]),
      ),
    );
  }
}
