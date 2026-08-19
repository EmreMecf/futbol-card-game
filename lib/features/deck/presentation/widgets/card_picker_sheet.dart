import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/premium_card/premium_card.dart';
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

    return Container(
      height: ekranYuksekligi * 0.72,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // ---- BAŞLIK ----
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      position.shortLabel,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${position.label} seç',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  Text(
                    '${cards.length} kart',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            if (current != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 16),
                    label: Text(
                      'Şu an: ${current!.fullName} (${current!.power})',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 8),

            // ---- KARTLAR ----
            Expanded(
              child: cards.isEmpty
                  ? _bosDurum()
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 130,
                        childAspectRatio: 0.66,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _siraliKartlar.length,
                      itemBuilder: (context, index) {
                        final kart = _siraliKartlar[index];
                        final kimya = chemistryPreview?.call(kart);

                        return LayoutBuilder(
                          builder: (context, kisitlar) {
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                PremiumPlayerCard.fromInventory(
                                  kart,
                                  key: ValueKey(kart.userCardId),
                                  width: kisitlar.maxWidth,
                                  // Listede animasyon kapalı (performans)
                                  interactive: false,
                                  onTap: () => Navigator.pop(context, kart),
                                ),
                                if (kimya != null)
                                  Positioned(
                                    top: -4,
                                    left: -4,
                                    child: _KimyaRozeti(chemistry: kimya),
                                  ),
                              ],
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bosDurum() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.style_outlined,
                size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              '${position.label} pozisyonunda uygun kartın yok',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Mağazadan paket açarak yeni kartlar kazanabilirsin.\n'
              'Devam eden bir maçta kilitli kartlar burada görünmez.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
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
      child: Text(
        '+$chemistry',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 10,
        ),
      ),
    );
  }
}
