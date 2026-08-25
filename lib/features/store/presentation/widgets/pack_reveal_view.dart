import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/premium_card/premium_card.dart';
import '../../../../shared/widgets/walkout/walkout.dart';
import '../../domain/reveal_style.dart';
import '../viewmodel/pack_opening_view_model.dart';

/// Paket açılış ekranı — kartlar tek tek, KADEMELİ olarak açılır.
///
/// ===================================================================
/// AKIŞ
/// ===================================================================
///   1. Kartlar TERSTEN sıralanır (kötüden iyiye) — en iyi kart sona
///      kalır ve gerilim sona doğru artar.
///   2. Her kart için [PackOpeningViewModel] bir kademe belirler:
///        Bronz/Gümüş -> hızlı flip
///        Altın       -> parlamalı flip
///        Diamond/Legend (ve paketin en iyisi) -> WALKOUT
///   3. Walkout sahnesi paket başına bir kez oynar.
///
/// ===================================================================
/// NEDEN AYRI BİR ViewModel?
/// ===================================================================
/// "Hangi animasyon oynayacak?" kararı ile "animasyon nasıl çizilecek"
/// işi bilinçli olarak ayrıldı. Karar saf mantık olduğu için widget
/// kurmadan test edilebiliyor; animasyonu test etmek zordur ama asıl
/// hata yapılacak yer zaten karar tarafıdır (yanlış kartta walkout,
/// iki kez oynayan sahne, atlanan kart...).
class PackRevealView extends StatelessWidget {
  final PackOpenResult result;
  final VoidCallback onClose;

  const PackRevealView({
    super.key,
    required this.result,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PackOpeningViewModel>(
      // Paket sonucu değiştiğinde ViewModel de yenilensin
      key: ValueKey(result.packSlug + result.cards.length.toString()),
      create: (_) => PackOpeningViewModel(result),
      child: _PackRevealBody(onClose: onClose),
    );
  }
}

class _PackRevealBody extends StatelessWidget {
  final VoidCallback onClose;

  const _PackRevealBody({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PackOpeningViewModel>();

    if (vm.isFinished) {
      return _OzetEkrani(result: vm.result, onClose: onClose);
    }

    final kart = vm.currentCard!;
    final kademe = vm.styleFor(kart);

    // ---- WALKOUT ----
    // Kendi tam ekran sahnesi var; üst çerçeve (sayaç, "hepsini göster")
    // gösterilmez. Sahnenin karanlığını bir arayüz bandıyla bölmek
    // etkiyi tamamen yok ederdi.
    if (kademe.isWalkout) {
      vm.markWalkoutPlayed();
      return WalkoutScreen(
        key: ValueKey('walkout-${kart.userCardId}'),
        card: kart,
        onContinue: vm.next,
      );
    }

    // ---- BASİT / ALTIN ----
    return _FlipEkrani(viewModel: vm, card: kart, style: kademe);
  }
}

// ====================================================================
// BASİT / ALTIN AÇILIŞ EKRANI
// ====================================================================
class _FlipEkrani extends StatelessWidget {
  final PackOpeningViewModel viewModel;
  final InventoryCard card;
  final RevealStyle style;

  const _FlipEkrani({
    required this.viewModel,
    required this.card,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final tema = CardTierTheme.of(card.tier);
    final nadir = card.tier.rank >= CardTier.diamond.rank;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: GestureDetector(
          onTap: viewModel.next,
          behavior: HitTestBehavior.opaque,
          child: Column(
            children: [
              // ---- ÜST BANT ----
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      viewModel.progressText,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: viewModel.revealAll,
                      child: const Text('Hepsini göster'),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Walkout hakkı bitmiş ama yine de nadir bir kart
                      if (nadir)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 7),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                  colors: tema.frameGradient),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              card.tier == CardTier.legend
                                  ? 'BİR TANE DAHA LEGEND!'
                                  : 'BİR TANE DAHA ${card.tier.label.toUpperCase()}!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),

                      // ValueKey: her yeni kartta flip baştan oynasın
                      CardFlipReveal(
                        key: ValueKey(card.userCardId),
                        card: card,
                        style: style,
                        width: 210,
                      ),
                    ],
                  ),
                ),
              ),

              const Padding(
                padding: EdgeInsets.only(bottom: 28),
                child: Text(
                  'Devam etmek için dokun',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ====================================================================
// ÖZET
// ====================================================================
class _OzetEkrani extends StatelessWidget {
  final PackOpenResult result;
  final VoidCallback onClose;

  const _OzetEkrani({required this.result, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Column(
                children: [
                  Icon(
                    result.hasRareCard
                        ? Icons.auto_awesome
                        : Icons.card_giftcard,
                    size: 40,
                    color: result.hasRareCard
                        ? AppColors.tierLegend
                        : AppColors.accent,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    result.packName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${result.cards.length} kart kazandın · '
                    'kalan ${result.coinsLeft} coin',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 130,
                  childAspectRatio: 0.66,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 12,
                ),
                itemCount: result.cards.length,
                itemBuilder: (context, index) {
                  final kart = result.cards[index];
                  return LayoutBuilder(
                    builder: (context, kisitlar) {
                      return PremiumPlayerCard.fromInventory(
                        kart,
                        key: ValueKey(kart.userCardId),
                        width: kisitlar.maxWidth,
                        interactive: false,
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: AppButton(
                label: 'TAMAM',
                icon: Icons.check,
                onPressed: onClose,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
