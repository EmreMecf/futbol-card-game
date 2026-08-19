import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/auth/session_manager.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../shared/widgets/error_snackbar.dart';
import '../../../../shared/widgets/premium_card/card_tier_theme.dart';
import '../viewmodel/store_view_model.dart';
import '../widgets/pack_reveal_view.dart';

/// Mağaza ekranı — kart paketleri.
class StoreView extends StatelessWidget {
  const StoreView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<StoreViewModel>(
      create: (_) => getIt<StoreViewModel>()..load(),
      child: const _StoreBody(),
    );
  }
}

class _StoreBody extends StatelessWidget {
  const _StoreBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<StoreViewModel>();
    // Coin üst bantta anlık görünsün
    context.watch<SessionManager>();

    // Paket açıldıysa açılış ekranını göster
    final acilis = vm.lastOpening;
    if (acilis != null) {
      return PackRevealView(
        result: acilis,
        onClose: vm.clearOpening,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mağaza'),
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.monetization_on,
                      size: 16, color: AppColors.accent),
                  const SizedBox(width: 6),
                  Text(
                    '${vm.coins}',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(child: _icerik(context, vm)),
    );
  }

  Widget _icerik(BuildContext context, StoreViewModel vm) {
    if (vm.isLoading && vm.packs.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (vm.packs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.storefront_outlined,
                  size: 48, color: AppColors.textSecondary),
              const SizedBox(height: 16),
              Text(
                vm.errorMessage ?? 'Şu an satışta paket yok.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: vm.load,
                icon: const Icon(Icons.refresh),
                label: const Text('Tekrar dene'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        for (final paket in vm.packs)
          _PaketKarti(viewModel: vm, pack: paket),
      ],
    );
  }
}

// ====================================================================
// PAKET KARTI
// ====================================================================
class _PaketKarti extends StatelessWidget {
  final StoreViewModel viewModel;
  final PackType pack;

  const _PaketKarti({required this.viewModel, required this.pack});

  @override
  Widget build(BuildContext context) {
    // Paketin kimliğini en iyi çıkabilecek seviyenin rengi belirliyor
    final tema = CardTierTheme.of(pack.bestPossibleTier);
    final aciliyor = viewModel.openingPackSlug == pack.slug;
    final parasiYeter = viewModel.canAfford(pack);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: tema.frameGradient[1].withValues(alpha: 0.45),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // ---- ÜST ŞERİT (seviye rengi) ----
          Container(
            height: 5,
            decoration: BoxDecoration(
              gradient: tema.frame,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---- BAŞLIK ----
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pack.name,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${pack.cardCount} kart',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.monetization_on,
                              size: 15, color: AppColors.accent),
                          const SizedBox(width: 5),
                          Text(
                            '${pack.priceCoins}',
                            style: const TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (pack.description != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    pack.description!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ],

                // ---- KADRO GARANTİSİ ----
                if (pack.hasGuaranteedFormation) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified,
                            size: 14, color: AppColors.success),
                        SizedBox(width: 6),
                        Text(
                          'Tam kadro garantili (1-4-4-2)',
                          style: TextStyle(
                            color: AppColors.success,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // ---- ÇIKMA İHTİMALLERİ ----
                const SizedBox(height: 14),
                const Text(
                  'Çıkma ihtimalleri',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final oran in pack.odds)
                      _OranRozeti(odds: oran),
                  ],
                ),

                // ---- SATIN AL ----
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (!parasiYeter ||
                            viewModel.openingPackSlug != null)
                        ? null
                        : () => _paketAc(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tema.frameGradient[2],
                      minimumSize: const Size.fromHeight(46),
                    ),
                    child: aciliyor
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            parasiYeter ? 'PAKETİ AÇ' : 'YETERSİZ COIN',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _paketAc(BuildContext context) async {
    final basarili = await viewModel.openPack(pack);
    if (!context.mounted) return;

    if (!basarili && viewModel.errorMessage != null) {
      AppSnackBar.showError(context, viewModel.errorMessage!);
      viewModel.clearError();
    }
  }
}

/// Tek bir seviyenin çıkma ihtimali rozeti
class _OranRozeti extends StatelessWidget {
  final TierOdds odds;

  const _OranRozeti({required this.odds});

  @override
  Widget build(BuildContext context) {
    final tema = CardTierTheme.of(odds.tier);
    // Nadir seviyeler (Diamond, Legend) daha belirgin görünsün
    final nadir = odds.tier.rank >= CardTier.diamond.rank;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tema.frameGradient[1].withValues(alpha: nadir ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(8),
        border: nadir
            ? Border.all(
                color: tema.frameGradient[1].withValues(alpha: 0.55),
              )
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: tema.frame,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            odds.tier.label,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 11.5,
              fontWeight: nadir ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            odds.displayPercent,
            style: TextStyle(
              color: tema.frameGradient[1],
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
