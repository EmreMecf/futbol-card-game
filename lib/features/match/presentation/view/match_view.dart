import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../shared/widgets/error_snackbar.dart';
import '../../../../shared/widgets/premium_card/premium_card.dart';
import '../viewmodel/match_view_model.dart';
import '../widgets/match_result_view.dart';
import '../widgets/match_table.dart';
import '../widgets/turn_timer.dart';

/// Maç ekranı — gerçek zamanlı oynanış.
class MatchView extends StatelessWidget {
  final String matchId;

  const MatchView({super.key, required this.matchId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MatchViewModel>(
      create: (_) =>
          getIt<MatchViewModel>(param1: matchId)..initialize(),
      child: const _MatchBody(),
    );
  }
}

class _MatchBody extends StatefulWidget {
  const _MatchBody();

  @override
  State<_MatchBody> createState() => _MatchBodyState();
}

class _MatchBodyState extends State<_MatchBody> {
  String? _gosterilenHata;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MatchViewModel>();

    // Hata mesajını SnackBar ile göster (aynı hatayı iki kez gösterme)
    final hata = vm.errorMessage;
    if (hata != null && hata != _gosterilenHata) {
      _gosterilenHata = hata;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        AppSnackBar.showError(context, hata);
        vm.clearError();
        _gosterilenHata = null;
      });
    }

    // Rakibin süresi dolduysa maçı hükmen talep et
    if (vm.canClaimTimeout) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) vm.claimTimeout();
      });
    }

    if (vm.isLoading && vm.matchState == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (vm.matchState == null) {
      return _HataEkrani(viewModel: vm);
    }

    // Maç bittiyse sonuç ekranı
    if (vm.isOver) {
      return MatchResultView(
        result: vm.result,
        onClose: () => context.go(AppRoutes.home),
      );
    }

    return _oyunEkrani(context, vm);
  }

  Widget _oyunEkrani(BuildContext context, MatchViewModel vm) {
    final durum = vm.matchState!;

    return PopScope(
      // Maçtan kaçış yok: geri tuşu teslim olma onayı sorar
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _teslimOnayi(context, vm);
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // ---- ÜST: rakip ve skor ----
              _UstBant(viewModel: vm),

              // ---- SAYAÇ ----
              TurnTimer(
                remaining: vm.remainingTime,
                isMyTurn: vm.isMyTurn,
                isUrgent: vm.isTimeRunningOut,
              ),

              // ---- MASA ----
              Expanded(
                child: MatchTable(
                  myMove: vm.myTableMove,
                  opponentMove: vm.opponentTableMove,
                  potCount: durum.potCount,
                  roundNumber: durum.roundNumber,
                  lastRound: vm.lastResolvedRound,
                  myUserId: vm.myUserId,
                ),
              ),

              // ---- DURUM MESAJI ----
              _DurumMesaji(viewModel: vm),

              // ---- ELİM ----
              _Elim(viewModel: vm),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _teslimOnayi(BuildContext context, MatchViewModel vm) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Teslim olmak istiyor musun?'),
        content: const Text(
          'Teslim olursan maçı kaybetmiş sayılırsın ve korumaya '
          'almadığın 3 kartın kalıcı olarak rakibe geçer.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Teslim ol',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (onay == true) await vm.surrender();
  }
}

// ====================================================================
// ÜST BANT: rakip bilgisi ve skor
// ====================================================================
class _UstBant extends StatelessWidget {
  final MatchViewModel viewModel;

  const _UstBant({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final durum = viewModel.matchState!;
    final rakip = durum.opponent;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      color: AppColors.surface,
      child: Row(
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.surfaceLight,
            child: Icon(Icons.person, size: 20, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rakip?.username ?? 'Rakip',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${durum.opponentCardsLeft} kart · ${rakip?.mmr ?? 0} puan',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),

          // ---- SKOR ----
          _skorKutusu('${durum.myScore}', AppColors.success, 'Sen'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('-', style: TextStyle(color: AppColors.textSecondary)),
          ),
          _skorKutusu('${durum.opponentScore}', AppColors.danger, 'Rakip'),
        ],
      ),
    );
  }

  Widget _skorKutusu(String deger, Color renk, String etiket) {
    return Column(
      children: [
        Text(
          deger,
          style: TextStyle(
            color: renk,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        Text(
          etiket,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

// ====================================================================
// DURUM MESAJI: sıra kimde, hangi pozisyon zorunlu
// ====================================================================
class _DurumMesaji extends StatelessWidget {
  final MatchViewModel viewModel;

  const _DurumMesaji({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final (metin, renk, ikon) = _mesaj();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: renk.withValues(alpha: 0.12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(ikon, size: 16, color: renk),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              metin,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: renk,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  (String, Color, IconData) _mesaj() {
    if (!viewModel.isMyTurn) {
      return ('Rakibin hamlesi bekleniyor...', AppColors.textSecondary,
          Icons.hourglass_empty);
    }

    if (viewModel.mustPass) {
      return (
        'Bu pozisyonda kartın yok. Turu kaybedeceksin.',
        AppColors.danger,
        Icons.block,
      );
    }

    final zorunlu = viewModel.requiredPosition;
    if (zorunlu != null) {
      return (
        '${zorunlu.label} pozisyonunda bir kart oyna',
        AppColors.warning,
        Icons.arrow_downward,
      );
    }

    return (
      'Turu sen açıyorsun — istediğin pozisyonu seç',
      AppColors.success,
      Icons.play_arrow,
    );
  }
}

// ====================================================================
// ELİM
// ====================================================================
class _Elim extends StatelessWidget {
  final MatchViewModel viewModel;

  const _Elim({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final oynanmamis =
        viewModel.hand.where((k) => !k.isPlayed).toList();

    if (viewModel.mustPass) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton.icon(
          onPressed: viewModel.isSubmittingMove ? null : viewModel.pass,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
          icon: const Icon(Icons.skip_next),
          label: const Text('PAS GEÇ (turu kaybet)'),
        ),
      );
    }

    return SizedBox(
      height: 168,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: oynanmamis.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final kart = oynanmamis[index];

          // Zorunlu pozisyon varsa, uymayan kartlar soluk ve tıklanamaz
          final zorunlu = viewModel.requiredPosition;
          final oynanabilir =
              zorunlu == null || kart.position == zorunlu;
          final aktif = viewModel.isMyTurn &&
              oynanabilir &&
              !viewModel.isSubmittingMove;

          return Opacity(
            opacity: oynanabilir ? 1.0 : 0.35,
            child: PremiumPlayerCard.fromHand(
              kart,
              key: ValueKey(kart.userCardId),
              width: 100,
              // Elde az kart var; sınırlı sayıda kart için etkileşim açık
              // bırakmak oynanışı çok daha canlı yapıyor.
              interactive: aktif,
              onTap: aktif ? () => viewModel.playCard(kart) : null,
            ),
          );
        },
      ),
    );
  }
}

// ====================================================================
// HATA
// ====================================================================
class _HataEkrani extends StatelessWidget {
  final MatchViewModel viewModel;

  const _HataEkrani({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Maç')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: AppColors.danger),
              const SizedBox(height: 16),
              Text(
                viewModel.errorMessage ?? 'Maç yüklenemedi.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: viewModel.refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Tekrar dene'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.go(AppRoutes.home),
                child: const Text('Ana sayfaya dön'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
