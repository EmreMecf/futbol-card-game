import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/router/app_routes.dart';
import '../viewmodel/sbc_list_view_model.dart';
import '../widgets/requirement_checklist.dart';

/// Kadro kurma gorevleri listesi.
class SbcListView extends StatelessWidget {
  const SbcListView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SbcListViewModel>(
      create: (_) => getIt<SbcListViewModel>()..load(),
      child: const _SbcListBody(),
    );
  }
}

class _SbcListBody extends StatelessWidget {
  const _SbcListBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SbcListViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Görevler'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh),
            onPressed: vm.load,
          ),
        ],
      ),
      body: SafeArea(child: _icerik(context, vm)),
    );
  }

  Widget _icerik(BuildContext context, SbcListViewModel vm) {
    if (vm.isLoading && vm.challenges.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (vm.challenges.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.assignment_outlined,
                  size: 48, color: AppColors.textSecondary),
              const SizedBox(height: 16),
              Text(
                vm.errorMessage ?? 'Şu an aktif görev yok.',
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

    return RefreshIndicator(
      onRefresh: vm.load,
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // ---- ACIKLAMA ----
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(Icons.local_fire_department,
                    color: AppColors.warning, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Kullanmadığın kartları eritip daha değerli ödüllere '
                    'çevir. Eritilen kartlar KALICI olarak silinir.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          for (final grup in vm.grouped.entries) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10, top: 6),
              child: Text(
                grup.key.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            for (final gorev in grup.value) _GorevKarti(challenge: gorev),
          ],
        ],
      ),
    );
  }
}

class _GorevKarti extends StatelessWidget {
  final SbcChallenge challenge;

  const _GorevKarti({required this.challenge});

  @override
  Widget build(BuildContext context) {
    final tamamlandi = challenge.isCompleted;

    return Opacity(
      opacity: tamamlandi ? 0.55 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: tamamlandi
                ? AppColors.success.withValues(alpha: 0.4)
                : AppColors.surfaceLight,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: tamamlandi
                ? null
                : () => context.push(
                      AppRoutes.sbcBuilderWithId(challenge.id),
                      extra: challenge,
                    ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          challenge.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (tamamlandi)
                        const Icon(Icons.check_circle,
                            color: AppColors.success, size: 20)
                      else if (challenge.isRepeatable)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Text(
                            'Tekrarlanabilir',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),

                  if (challenge.description != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      challenge.description!,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),
                  RequirementSummary(requirements: challenge.requirements),

                  const SizedBox(height: 12),
                  const Divider(height: 1, color: AppColors.surfaceLight),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      const Icon(Icons.card_giftcard,
                          size: 15, color: AppColors.accent),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          challenge.rewardSummary,
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (challenge.completedCount > 0)
                        Text(
                          '${challenge.completedCount} kez yapıldı',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      if (!tamamlandi)
                        const Icon(Icons.chevron_right,
                            color: AppColors.textSecondary, size: 20),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
