import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/theme/ref_tokens.dart';
import '../../../../core/utils/turkish_text.dart';
import '../../../../shared/widgets/ref/ref_ui.dart';
import '../../../../shared/widgets/ref_card/ref_player_card.dart';
import 'formation_pitch.dart';

/// Bir yuvaya kart seçmek için açılan pencere.
///
/// Sadece o pozisyona ait, kilitli olmayan ve kadroda bulunmayan
/// kartları gösterir — yani dokunulabilecek her kart geçerlidir.
/// Oyuncu "neden bu kartı seçemiyorum?" diye düşünmez.
class CardPickerSheet extends StatelessWidget {
  final CardPosition position;
  final List<InventoryCard> cards;

  /// Şu an bu yuvada duran kart (varsa)
  final InventoryCard? current;

  /// Bir kart bu yuvaya konursa alacağı kimya puanı.
  ///
  /// NEDEN GEREKLİ? Kimyayı görmeden kart seçmek zorunda kalmak sistemi
  /// anlaşılmaz kılardı: oyuncu "neden bu kartı seçtim de kimyam düştü?"
  /// diye sorardı. Her kartın yanında sonucu göstererek kararı
  /// bilinçli hale getiriyoruz.
  final int Function(InventoryCard)? chemistryPreview;

  const CardPickerSheet({
    super.key,
    required this.position,
    required this.cards,
    this.current,
    this.chemistryPreview,
  });

  /// Kart seçtirir. Seçilen kartı döner; iptal edilirse null.
  static Future<InventoryCard?> show(
    BuildContext context, {
    required CardPosition position,
    required List<InventoryCard> cards,
    InventoryCard? current,
    int Function(InventoryCard)? chemistryPreview,
  }) {
    return showModalBottomSheet<InventoryCard>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CardPickerSheet(
        position: position,
        cards: cards,
        current: current,
        chemistryPreview: chemistryPreview,
      ),
    );
  }

  /// Kartları KİMYAYA göre sırala (kimya yoksa güce göre).
  ///
  /// Oyuncu genelde "bu yuvaya en iyi kim gider?" diye bakıyor;
  /// en uyumlu kartların üstte olması aramayı ortadan kaldırıyor.
  List<InventoryCard> get _siraliKartlar {
    final liste = [...cards];
    final onizleme = chemistryPreview;

    if (onizleme == null) {
      liste.sort((a, b) {
        if (a.tier.rank != b.tier.rank) {
          return b.tier.rank.compareTo(a.tier.rank);
        }
        return b.power.compareTo(a.power);
      });
      return liste;
    }

    liste.sort((a, b) {
      final kimyaA = onizleme(a);
      final kimyaB = onizleme(b);

      // Kimya + güç birlikte: kimya 1 puan, güç 3 puana bedel sayılıyor
      final puanA = kimyaA * 3 + a.power;
      final puanB = kimyaB * 3 + b.power;
      return puanB.compareTo(puanA);
    });
    return liste;
  }

  @override
  Widget build(BuildContext context) {
    final ekranYuksekligi = MediaQuery.sizeOf(context).height;
    final kartlar = _siraliKartlar;

    // Referans .modal dili: #0f1a2e zemin, #786c8b çerçeve, üstte mor ışık
    return Container(
      height: ekranYuksekligi * 0.78,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.2,
          colors: [Color.alphaBlend(Ref.modalGlow, Ref.modalBg), Ref.modalBg],
          stops: const [0, 0.7],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(21)),
        border: const Border(top: BorderSide(color: Ref.modalBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(color: Ref.pillBorder, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: RefSectionHead(
                '${position.label.toUpperTr()} SEÇ',
                kicker: 'YUVA: ${position.code}',
                trailing: RefPill('${cards.length} KART'),
              ),
            ),
            if (current != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: RefNeutralButton(
                    onTap: () => Navigator.pop(context),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.close_rounded, size: 14, color: Ref.neutralText),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text('Şu an: ${current!.fullName} (${current!.power}) · değiştirme',
                            overflow: TextOverflow.ellipsis,
                            style: Ref.bodyText(11, color: Ref.neutralText, weight: FontWeight.w800)),
                      ),
                    ]),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Expanded(
              child: cards.isEmpty
                  ? _bosDurum()
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 190,
                        childAspectRatio: RefCardLayout.grid.aspectRatio,
                        crossAxisSpacing: 9,
                        mainAxisSpacing: 9,
                      ),
                      itemCount: kartlar.length,
                      itemBuilder: (context, index) {
                        final kart = kartlar[index];
                        final kimya = chemistryPreview?.call(kart);
                        return LayoutBuilder(
                          builder: (context, k) => Stack(
                            clipBehavior: Clip.none,
                            children: [
                              RefPlayerCard(
                                key: ValueKey(kart.userCardId),
                                name: kart.fullName,
                                position: kart.position,
                                tier: kart.tier,
                                power: kart.power,
                                seed: kart.cardId,
                                kitSeed: kart.club ?? kart.nationality,
                                imageUrl: kart.imageUrl,
                                width: k.maxWidth,
                                onTap: () => Navigator.pop(context, kart),
                              ),
                              if (kimya != null)
                                Positioned(top: -4, right: -4, child: _KimyaRozeti(chemistry: kimya)),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bosDurum() => Padding(
        padding: const EdgeInsets.all(14),
        child: Align(
          alignment: Alignment.topCenter,
          child: RefNote(
            'Mağazadan paket açarak yeni kartlar kazanabilirsin. Devam eden bir maçta kilitli kartlar burada görünmez.',
            title: '${position.label} mevkisinde uygun kartın yok',
          ),
        ),
      );
}

/// Kart seçim listesinde gösterilen kimya önizleme rozeti
class _KimyaRozeti extends StatelessWidget {
  final int chemistry;

  const _KimyaRozeti({required this.chemistry});

  @override
  Widget build(BuildContext context) {
    final renk = chemistry >= 5
        ? ChemistryColors.strong
        : (chemistry >= 2 ? ChemistryColors.weak : ChemistryColors.none);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: renk,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: renk.withValues(alpha: 0.5), blurRadius: 5),
        ],
      ),
      child: Text('+$chemistry', style: Ref.bodyText(10, weight: FontWeight.w900, color: const Color(0xFF0A2033))),
    );
  }
}
