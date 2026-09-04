import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_breakpoints.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/screen_header.dart';
import '../viewmodel/profile_view_model.dart';

/// Profil — oyuncunun karnesi ve maç geçmişi.
///
/// ===================================================================
/// SADECE GERÇEK VERİ
/// ===================================================================
/// Bu ekranda rozet, başarı ya da seviye çubuğu yok. Sunucuda böyle
/// bir sistem bulunmuyor; çizmek boş kutular bırakırdı.
///
/// Gösterilenlerin hepsi veritabanında duran gerçek alanlar:
/// galibiyet, mağlubiyet, beraberlik, coin, puan, koruma hakkı,
/// kayıt tarihi ve bitmiş maçların listesi.
class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ProfileViewModel>(
      create: (_) => getIt<ProfileViewModel>()..initialize(),
      child: const _ProfileBody(),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProfileViewModel>();

    return AppShell(
      currentRoute: AppRoutes.profile,
      child: ResponsiveBuilder(
        builder: (context, boyut) {
          final kenar = AppBreakpoints.pagePadding(boyut);

          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            onRefresh: vm.refresh,
            child: SafeArea(
              bottom: false,
              child: ContentWidth(
                maxWidth: 900,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    kenar,
                    boyut.usesSidebar ? 32 : 16,
                    kenar,
                    boyut.usesSidebar ? 40 : 110,
                  ),
                  children: [
                    ScreenHeader(
                      title: 'Profil',
                      actions: [_AyarlarButonu()],
                    ),
                    const SizedBox(height: 20),
                    _Kimlik(viewModel: vm),
                    const SizedBox(height: 20),
                    _SkorKarolari(viewModel: vm),
                    const SizedBox(height: 12),
                    _OzetKarti(viewModel: vm),
                    const SizedBox(height: 22),
                    _GecmisBolumu(viewModel: vm),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AyarlarButonu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(AppRoutes.settings),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.surfaceLight),
          ),
          child: const Icon(
            Icons.settings_rounded,
            size: 19,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ====================================================================
// KİMLİK: avatar, ad, kayıt tarihi
// ====================================================================
class _Kimlik extends StatelessWidget {
  final ProfileViewModel viewModel;

  const _Kimlik({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final kullanici = viewModel.user;
    final ad = kullanici?.username ?? 'Oyuncu';
    final harf = ad.trim().isEmpty ? '?' : ad.trim()[0].toUpperCase();

    return Row(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.4),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Center(
            child: Text(
              harf,
              style: AppTypography.display(size: 36, weight: FontWeight.w900),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ad,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.display(
                  size: 26,
                  weight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _kayitMetni(kullanici?.createdAt),
                style: AppTypography.bodyS,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _kayitMetni(DateTime? tarih) {
    if (tarih == null) return 'Hoş geldin';
    // Türkçe ay adı için intl kullanılıyor; elle ay listesi tutmak
    // yerelleştirme eklendiğinde ikinci bir yer daha bırakırdı.
    final bicim = DateFormat('d MMMM yyyy', 'tr');
    return "${bicim.format(tarih.toLocal())}'dan beri oynuyor";
  }
}

// ====================================================================
// GALİBİYET / MAĞLUBİYET / BERABERLİK
// ====================================================================
class _SkorKarolari extends StatelessWidget {
  final ProfileViewModel viewModel;

  const _SkorKarolari({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final k = viewModel.user;

    return Row(
      children: [
        Expanded(
          child: _SkorKarosu(
            value: k?.wins ?? 0,
            label: 'GALİBİYET',
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SkorKarosu(
            value: k?.losses ?? 0,
            label: 'MAĞLUBİYET',
            color: AppColors.danger,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SkorKarosu(
            value: k?.draws ?? 0,
            label: 'BERABERLİK',
            color: AppColors.warning,
          ),
        ),
      ],
    );
  }
}

class _SkorKarosu extends StatelessWidget {
  final int value;
  final String label;
  final Color color;

  const _SkorKarosu({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        children: [
          Text(
            '$value',
            style: AppTypography.display(
              size: 26,
              weight: FontWeight.w900,
              height: 1.0,
              color: color,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            child: Text(
              label,
              style: AppTypography.body(
                size: 10.5,
                weight: FontWeight.w800,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// ÖZET: kazanma oranı, coin, koruma
// ====================================================================
class _OzetKarti extends StatelessWidget {
  final ProfileViewModel viewModel;

  const _OzetKarti({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final oran = viewModel.winRate;
    final oynanmis = viewModel.totalMatches > 0;

    return SurfaceCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Kazanma oranı',
                style: AppTypography.body(
                  size: 12.5,
                  weight: FontWeight.w800,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                oynanmis ? '%${(oran * 100).round()}' : '—',
                style: AppTypography.display(
                  size: 20,
                  weight: FontWeight.w900,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: oran,
              minHeight: 8,
              backgroundColor: AppColors.surfaceLight,
              valueColor: const AlwaysStoppedAnimation(AppColors.success),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MiniKutu(
                  icon: Icons.monetization_on_rounded,
                  iconColor: AppColors.accent,
                  value: _binlik(viewModel.user?.coins ?? 0),
                  label: 'Coin',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniKutu(
                  icon: Icons.shield_rounded,
                  iconColor: AppColors.tierDiamond,
                  value: '${viewModel.protectionSlots}',
                  suffix: '/${GameRules.maxProtectionSlots}',
                  label: 'Koruma',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniKutu(
                  icon: Icons.emoji_events_rounded,
                  iconColor: AppColors.accent,
                  value: _binlik(viewModel.user?.mmr ?? 0),
                  label: 'Puan',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _binlik(int sayi) {
    final metin = sayi.abs().toString();
    final tampon = StringBuffer(sayi < 0 ? '-' : '');
    for (var i = 0; i < metin.length; i++) {
      if (i > 0 && (metin.length - i) % 3 == 0) tampon.write('.');
      tampon.write(metin[i]);
    }
    return tampon.toString();
  }
}

class _MiniKutu extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String? suffix;
  final String label;

  const _MiniKutu({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        value,
                        style: AppTypography.display(
                          size: 17,
                          weight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                      if (suffix != null)
                        Text(
                          suffix!,
                          style: AppTypography.display(
                            size: 13,
                            weight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(
                    size: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// MAÇ GEÇMİŞİ
// ====================================================================
class _GecmisBolumu extends StatelessWidget {
  final ProfileViewModel viewModel;

  const _GecmisBolumu({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Son maçlar'),
        const SizedBox(height: 10),
        if (viewModel.isBusy && viewModel.history.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          )
        else if (viewModel.history.isEmpty)
          _BosGecmis(hasError: viewModel.hasError, viewModel: viewModel)
        else
          for (final mac in viewModel.history)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _GecmisSatiri(entry: mac),
            ),
      ],
    );
  }
}

class _BosGecmis extends StatelessWidget {
  final bool hasError;
  final ProfileViewModel viewModel;

  const _BosGecmis({required this.hasError, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    if (hasError) {
      return SurfaceCard(
        child: Column(
          children: [
            Text(
              viewModel.errorMessage ?? 'Geçmiş yüklenemedi.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyS,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: viewModel.loadHistory,
              child: const Text('Tekrar dene'),
            ),
          ],
        ),
      );
    }

    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 26),
      child: Column(
        children: [
          const Icon(
            Icons.sports_soccer_rounded,
            size: 32,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            'Henüz bitmiş maçın yok',
            style: AppTypography.body(size: 14, weight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'İlk maçını oynadığında burada görünecek.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyS,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.go(AppRoutes.matchmaking),
            child: const Text('RAKİP BUL'),
          ),
        ],
      ),
    );
  }
}

class _GecmisSatiri extends StatelessWidget {
  final MatchHistoryEntry entry;

  const _GecmisSatiri({required this.entry});

  @override
  Widget build(BuildContext context) {
    final renk = switch (entry.outcome) {
      MatchOutcome.win => AppColors.success,
      MatchOutcome.loss => AppColors.danger,
      MatchOutcome.draw => AppColors.warning,
    };

    return SurfaceCard(
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      child: Row(
        children: [
          // Sonuç şeridi: listeyi okumadan galibiyet/mağlubiyet
          // dağılımı görünsün
          Container(
            width: 5,
            height: 32,
            decoration: BoxDecoration(
              color: renk,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.opponentUsername,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(
                    size: 13.5,
                    weight: FontWeight.w800,
                  ),
                ),
                Text(
                  _altSatir(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyXS,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            entry.scoreText,
            style: AppTypography.display(size: 18, weight: FontWeight.w900),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 58,
            child: Text(
              entry.outcome.shortLabel,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body(
                size: 11.5,
                weight: FontWeight.w900,
                color: renk,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _altSatir() {
    final zaman = _zamanMetni(entry.finishedAt);
    final transfer = entry.transferText;
    if (transfer == null) return zaman;
    return '$zaman · $transfer';
  }

  /// "12 dakika önce", "Dün", "3 Eylül"
  static String _zamanMetni(DateTime? tarih) {
    if (tarih == null) return 'Bitti';

    final fark = DateTime.now().difference(tarih.toLocal());
    if (fark.inMinutes < 1) return 'Az önce';
    if (fark.inMinutes < 60) return '${fark.inMinutes} dakika önce';
    if (fark.inHours < 24) return '${fark.inHours} saat önce';
    if (fark.inDays == 1) return 'Dün';
    if (fark.inDays < 7) return '${fark.inDays} gün önce';

    return DateFormat('d MMMM', 'tr').format(tarih.toLocal());
  }
}
