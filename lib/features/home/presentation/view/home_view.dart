import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/auth/session_manager.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../auth/presentation/viewmodel/auth_view_model.dart';

/// Ana menü.
class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  @override
  void initState() {
    super.initState();
    // Coin, MMR ve koruma hakkı maç sonrası değişmiş olabilir;
    // ayrıca devam eden maç varsa oraya dönebilmek için tazeliyoruz.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthViewModel>().refreshProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();
    final session = context.watch<SessionManager>();
    final kullanici = session.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FUTBOL KART'),
        actions: [
          IconButton(
            tooltip: 'Çıkış yap',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authViewModel.signOut();
              if (context.mounted) context.go(AppRoutes.login);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---- OYUNCU ÖZETİ ----
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.surfaceLight,
                          child: Icon(Icons.person,
                              color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                kullanici?.username ?? 'Oyuncu',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                '${kullanici?.wins ?? 0}G '
                                '${kullanici?.losses ?? 0}M '
                                '${kullanici?.draws ?? 0}B',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _istatistik(Icons.monetization_on,
                            '${kullanici?.coins ?? 0}', 'Coin'),
                        _istatistik(Icons.leaderboard,
                            '${kullanici?.mmr ?? 0}', 'Puan'),
                        _istatistik(Icons.shield_outlined,
                            '${session.protectionSlots}', 'Koruma'),
                      ],
                    ),
                  ],
                ),
              ),

              // ---- DEVAM EDEN MAÇ ----
              if (authViewModel.activeMatchId != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sports_soccer,
                          color: AppColors.warning, size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Devam eden bir maçın var',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push(
                          AppRoutes.matchWithId(authViewModel.activeMatchId!),
                        ),
                        child: const Text('Maça dön'),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(),

              AppButton(
                label: 'MAÇ ARA',
                icon: Icons.search,
                onPressed: () => context.push(AppRoutes.matchmaking),
              ),
              const SizedBox(height: 12),
              AppOutlinedButton(
                label: 'Mağaza',
                icon: Icons.storefront_outlined,
                onPressed: () => context.push(AppRoutes.store),
              ),
              const SizedBox(height: 12),
              AppOutlinedButton(
                label: 'Görevler',
                icon: Icons.assignment_outlined,
                onPressed: () => context.push(AppRoutes.sbc),
              ),
              const SizedBox(height: 12),
              AppOutlinedButton(
                label: 'Kadrom',
                icon: Icons.groups_2_outlined,
                onPressed: () => context.push(AppRoutes.deck),
              ),
              const SizedBox(height: 12),
              AppOutlinedButton(
                label: 'Koleksiyonum',
                icon: Icons.style_outlined,
                onPressed: () => context.push(AppRoutes.collection),
              ),
              const SizedBox(height: 12),
              AppOutlinedButton(
                label: 'Profil',
                icon: Icons.person_outline,
                onPressed: () => context.push(AppRoutes.profile),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _istatistik(IconData ikon, String deger, String etiket) {
    return Expanded(
      child: Column(
        children: [
          Icon(ikon, size: 17, color: AppColors.textSecondary),
          const SizedBox(height: 4),
          Text(
            deger,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          Text(
            etiket,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}
