import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/theme/ref_tokens.dart';
import '../../../../shared/widgets/ref/ref_ui.dart';

/// 042: ÖĞRETİCİ İPUCU — öğretici maçında başlığın altında, adıma ve
/// aşamaya göre tek kısa açıklama.
///
///   Adım 1: mevki seçimi   Adım 2: gizli seçim   Adım 3: taktik
///
/// Metinler sunucu kurallarıyla aynı sayıları kullanır (taktik bonusları
/// 021, maliyetler sürüm 7: pres 3, kontra 2, duvar 2 enerji).
class TutorialHint extends StatelessWidget {
  final MatchState state;
  const TutorialHint({super.key, required this.state});

  /// (başlık, açıklama) — test edilebilsin diye ayrı
  static (String, String) textFor(MatchState s) {
    final adim = s.tutorialStep ?? 1;
    final mevki = s.phase == 'position';
    if (mevki) {
      if (s.amILead) {
        return adim == 1
            ? ('MEVKİ SEÇ', 'Bu turun mevkisini sen belirliyorsun. En güçlü kartının olduğu mevkiyi seç: '
                'iki oyuncu da o mevkiden kart oynayacak.')
            : ('MEVKİ SEÇ', 'Turu kazanan bir sonraki turun mevkisini seçer. Rakibinin zayıf olduğu yeri düşün.');
      }
      return ('RAKİP SEÇİYOR', 'Bu turun mevkisini rakip seçiyor. Turu kazanırsan mevkiyi sen seçersin.');
    }
    if (s.iHavePlayed) {
      return ('KARTIN GİZLİ', 'Rakip seçince iki kart birlikte açılır. Güçlü kart turu kazanır; '
          'beraberlikte kartlar ortada kalır, sonraki turu kazanan hepsini alır.');
    }
    return switch (adim) {
      1 => ('KART SEÇ', 'O mevkiden bir kart seç ve oyna. Kısa maç: 6 kart toplayan kazanır.'),
      2 => ('GİZLİ SEÇİM', 'Rakip de şu an kartını seçiyor ama birbirinizinkini göremiyorsunuz. '
          'En güçlü kartını her tur harcama: bazen zayıf kartla turu bırakmak iyidir.'),
      _ => ('TAKTİK', 'Kartla birlikte taktik seçebilirsin. Pres +9 (3 enerji) ama kontraya yenilir. '
          'Kontra presi yakalarsa +13 (2 enerji). Duvar savunurken +6 (2 enerji), prese kırılır. '
          'Enerji her tur +1 artar.'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (baslik, aciklama) = textFor(state);
    return RefCardPanel(
      children: [
        Row(
          children: [
            const Em('🎓', size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'ÖĞRETİCİ ${state.tutorialStep ?? 1}/3 · $baslik',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Ref.caps(Ref.gold),
              ),
            ),
          ],
        ),
        Text(aciklama, style: Ref.bodyText(12, color: Ref.text, height: 1.4)),
      ],
    );
  }
}
