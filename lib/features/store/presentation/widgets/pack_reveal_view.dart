import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/turkish_text.dart';
import '../../../../shared/widgets/game/game_ui.dart';
import '../../../../shared/widgets/premium_card/premium_card.dart';
import '../../../../shared/widgets/walkout/walkout.dart';
import '../../domain/reveal_style.dart';
import '../viewmodel/pack_opening_view_model.dart';
import 'pack_seal_scene.dart';

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

  /// Mühürlü kutunun rengi (paketin imza seviyesi)
  final CardTier packTier;

  const PackRevealView({
    super.key,
    required this.result,
    required this.onClose,
    this.packTier = CardTier.gold,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PackOpeningViewModel>(
      // Paket sonucu değiştiğinde ViewModel de yenilensin
      key: ValueKey(result.packSlug + result.cards.length.toString()),
      create: (_) => PackOpeningViewModel(result),
      child: _PackRevealBody(onClose: onClose, packTier: packTier),
    );
  }
}

class _PackRevealBody extends StatelessWidget {
  final VoidCallback onClose;
  final CardTier packTier;

  const _PackRevealBody({required this.onClose, required this.packTier});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PackOpeningViewModel>();

    if (vm.isFinished) {
      return PackSummaryView(result: vm.result, onClose: onClose);
    }

    // ---- MÜHÜRLÜ PAKET (dokunarak açma) ----
    if (vm.isSealed) {
      return PackSealScene(
        result: vm.result,
        packTier: packTier,
        onOpened: vm.unseal,
        onSkipAll: vm.revealAll,
      );
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
                      style: AppTypography.display(
                        size: 16,
                        weight: FontWeight.w800,
                        color: AppColors.textSecondary,
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
                              // Diamond / Legend yabancı özel ad olduğu için
                              // toUpperTr değil toUpperCase (bkz. turkish_text)
                              'BİR TANE DAHA '
                              '${card.tier.displayName.toUpperCase()}!',
                              style: AppTypography.display(
                                size: 14,
                                weight: FontWeight.w900,
                                letterSpacing: 1.5,
                                color: Colors.white,
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

              Padding(
                padding: const EdgeInsets.only(bottom: 28),
                child: Text(
                  'Devam etmek için dokun',
                  style: AppTypography.bodyS,
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
// PAKET SONUCU (MD bölüm 4-G: "Paket sonucu ekranı")
// ====================================================================
/// Paketin özeti: en iyi kart öne çıkar, altında seviye dağılımı ve
/// diğer kartlar. Kartlar sunucunun sırasıyla (en iyiden kötüye) dizilir.
class PackSummaryView extends StatelessWidget {
  final PackOpenResult result;
  final VoidCallback onClose;

  const PackSummaryView({
    super.key,
    required this.result,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final enIyi = result.bestCard;
    final digerleri =
        result.cards.where((k) => k.userCardId != enIyi?.userCardId).toList();

    // Seviye dağılımı (en yüksekten)
    final dagilim = <CardTier, int>{};
    for (final k in result.cards) {
      dagilim[k.tier] = (dagilim[k.tier] ?? 0) + 1;
    }
    final seviyeler = dagilim.keys.toList()
      ..sort((a, b) => b.rank.compareTo(a.rank));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenEdge,
                          AppSpacing.xxl,
                          AppSpacing.screenEdge,
                          AppSpacing.md,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            children: [
                              Text('PAKET AÇILDI', style: AppTypography.label),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                result.packName.toUpperTr(),
                                textAlign: TextAlign.center,
                                style: AppTypography.display(
                                  size: 28,
                                  weight: FontWeight.w900,
                                  color: result.hasRareCard
                                      ? AppColors.victoryGold
                                      : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              if (enIyi != null) ...[
                                PremiumPlayerCard.fromInventory(
                                  enIyi,
                                  key: ValueKey('enIyi-${enIyi.userCardId}'),
                                  width: 168,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text('EN İYİ KART', style: AppTypography.label),
                                const SizedBox(height: AppSpacing.lg),
                              ],
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: AppSpacing.md,
                                runSpacing: AppSpacing.sm,
                                children: [
                                  for (final t in seviyeler)
                                    _SeviyeSayaci(tier: t, count: dagilim[t]!),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (digerleri.isNotEmpty)
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.screenEdge,
                            AppSpacing.sm,
                            AppSpacing.screenEdge,
                            AppSpacing.lg,
                          ),
                          sliver: SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 120,
                              childAspectRatio: 0.66,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 12,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final kart = digerleri[index];
                                return LayoutBuilder(
                                  builder: (context, kisitlar) =>
                                      PremiumPlayerCard.fromInventory(
                                    kart,
                                    key: ValueKey(kart.userCardId),
                                    width: kisitlar.maxWidth,
                                    interactive: false,
                                  ),
                                );
                              },
                              childCount: digerleri.length,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // ---- ALT BANT ----
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenEdge,
                    AppSpacing.sm,
                    AppSpacing.screenEdge,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${result.cards.length} kart koleksiyonuna eklendi · '
                        'kalan ${result.coinsLeft} coin',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyS,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      GameButton(
                        label: 'Tamam',
                        icon: Icons.check_rounded,
                        onPressed: onClose,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "3 ×  [ALTIN]" sayacı
class _SeviyeSayaci extends StatelessWidget {
  final CardTier tier;
  final int count;

  const _SeviyeSayaci({required this.tier, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$count ×',
          style: AppTypography.display(size: 16, weight: FontWeight.w900),
        ),
        const SizedBox(width: AppSpacing.xs),
        TierBadge(tier, compact: true),
      ],
    );
  }
}
