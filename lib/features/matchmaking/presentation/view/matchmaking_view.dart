import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/error_snackbar.dart';
import '../../../../shared/widgets/premium_card/premium_card.dart';
import '../viewmodel/matchmaking_view_model.dart';

/// Eşleşme ekranı: kadro seç, kartlarını korumaya al, rakip ara.
class MatchmakingView extends StatelessWidget {
  const MatchmakingView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MatchmakingViewModel>(
      create: (_) => getIt<MatchmakingViewModel>()..initialize(),
      child: const _MatchmakingBody(),
    );
  }
}

class _MatchmakingBody extends StatefulWidget {
  const _MatchmakingBody();

  @override
  State<_MatchmakingBody> createState() => _MatchmakingBodyState();
}

class _MatchmakingBodyState extends State<_MatchmakingBody> {
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MatchmakingViewModel>();

    // Rakip bulunduğunda maç ekranına geç.
    // build içinde doğrudan navigasyon yapılamaz; bir sonraki kareye
    // erteliyoruz.
    final macId = vm.foundMatchId;
    if (macId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        vm.consumeFoundMatch();
        context.pushReplacement(AppRoutes.matchWithId(macId));
      });
    }

    return PopScope(
      // Kuyrukta beklerken geri tuşuna basılırsa önce kuyruktan çık
      canPop: vm.stage != MatchmakingStage.searching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) vm.cancelSearch();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            vm.stage == MatchmakingStage.searching
                ? 'Rakip Aranıyor'
                : 'Maça Hazırlan',
          ),
        ),
        body: SafeArea(child: _icerik(context, vm)),
      ),
    );
  }

  Widget _icerik(BuildContext context, MatchmakingViewModel vm) {
    if (vm.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (vm.stage == MatchmakingStage.searching) {
      return _AramaEkrani(viewModel: vm);
    }

    return _HazirlikEkrani(viewModel: vm);
  }
}

// ====================================================================
// HAZIRLIK: kadro + koruma seçimi
// ====================================================================
class _HazirlikEkrani extends StatelessWidget {
  final MatchmakingViewModel viewModel;

  const _HazirlikEkrani({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final dogrulama = viewModel.validation;
    final gecerli = dogrulama?.isValid ?? false;

    return Column(
      children: [
        // ---- KADRO DURUMU ----
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: gecerli
                ? AppColors.success.withValues(alpha: 0.12)
                : AppColors.danger.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: (gecerli ? AppColors.success : AppColors.danger)
                  .withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Icon(
                gecerli ? Icons.check_circle : Icons.error_outline,
                color: gecerli ? AppColors.success : AppColors.danger,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  dogrulama?.displayMessage ?? 'Kadro kontrol ediliyor...',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ---- KORUMA BAŞLIĞI ----
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.shield_outlined,
                  size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Kartlarını koru  '
                  '(${viewModel.protectedCardIds.length}/${viewModel.maxProtection})',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              TextButton(
                onPressed: viewModel.autoProtectBest,
                child: const Text('En iyileri koru'),
              ),
            ],
          ),
        ),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Maçı kaybedersen, korumaya ALMADIĞIN kartlardan 3 tanesi '
            'rastgele seçilip kalıcı olarak rakibe geçer.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ),

        const SizedBox(height: 12),

        // ---- KADRO KARTLARI ----
        Expanded(
          child: viewModel.deckCards.isEmpty
              ? const Center(
                  child: Text(
                    'Kadronda kart yok.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 120,
                    childAspectRatio: 0.66,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: viewModel.deckCards.length,
                  itemBuilder: (context, index) {
                    final kart = viewModel.deckCards[index];
                    final korunuyor =
                        viewModel.isProtected(kart.userCardId);

                    return LayoutBuilder(
                      builder: (context, kisitlar) {
                        return PremiumPlayerCard(
                          key: ValueKey(kart.userCardId),
                          fullName: kart.fullName,
                          position: kart.position,
                          tier: kart.tier,
                          power: kart.power,
                          imageUrl: kart.imageUrl,
                          nationality: kart.nationality,
                          club: kart.club,
                          width: kisitlar.maxWidth,
                          isProtected: korunuyor,
                          isSelected: korunuyor,
                          // Liste modunda animasyon kapalı (performans)
                          interactive: false,
                          onTap: () {
                            if (!korunuyor && !viewModel.canProtectMore) {
                              AppSnackBar.showInfo(
                                context,
                                'Koruma hakkın doldu. Her galibiyette '
                                '1 hak kazanırsın.',
                              );
                              return;
                            }
                            viewModel.toggleProtection(kart.userCardId);
                          },
                        );
                      },
                    );
                  },
                ),
        ),

        // ---- MAÇ ARA ----
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: AppButton(
            label: 'RAKİP ARA',
            icon: Icons.search,
            onPressed: viewModel.canSearch ? viewModel.startSearch : null,
          ),
        ),
      ],
    );
  }
}

// ====================================================================
// ARAMA: kuyrukta bekleme
// ====================================================================
class _AramaEkrani extends StatelessWidget {
  final MatchmakingViewModel viewModel;

  const _AramaEkrani({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final sure = viewModel.searchDuration;
    final dakika = sure.inMinutes.toString().padLeft(2, '0');
    final saniye = (sure.inSeconds % 60).toString().padLeft(2, '0');

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 72,
            height: 72,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Rakip aranıyor...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$dakika:$saniye',
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Bekleme süresi uzadıkça puan aralığı genişler, '
            'böylece daha hızlı eşleşirsin.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield, size: 15, color: AppColors.success),
                const SizedBox(width: 7),
                Text(
                  '${viewModel.protectedCardIds.length} kart korumada',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          AppOutlinedButton(
            label: 'Aramayı iptal et',
            icon: Icons.close,
            onPressed: viewModel.cancelSearch,
          ),
        ],
      ),
    );
  }
}
