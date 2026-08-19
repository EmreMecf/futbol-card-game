import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../shared/widgets/error_snackbar.dart';
import '../../../../shared/widgets/premium_card/premium_card.dart';
import '../viewmodel/collection_view_model.dart';
import '../widgets/card_detail_sheet.dart';
import '../widgets/collection_filter_bar.dart';

/// Koleksiyon ekrani: oyuncunun sahip oldugu tum kartlar.
class CollectionView extends StatelessWidget {
  const CollectionView({super.key});

  @override
  Widget build(BuildContext context) {
    // ViewModel'i BU EKRANA bagliyoruz. Ekran kapaninca otomatik
    // temizlenir; uygulama boyunca bellekte kalmaz.
    return ChangeNotifierProvider<CollectionViewModel>(
      create: (_) => getIt<CollectionViewModel>()..load(),
      child: const _CollectionBody(),
    );
  }
}

class _CollectionBody extends StatelessWidget {
  const _CollectionBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CollectionViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Koleksiyonum'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh),
            onPressed: () => vm.load(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ---- OZET BANT ----
            _OzetBant(viewModel: vm),

            const SizedBox(height: 12),

            // ---- FILTRELER ----
            CollectionFilterBar(viewModel: vm),

            const SizedBox(height: 12),

            // ---- KART IZGARASI ----
            Expanded(child: _icerik(context, vm)),
          ],
        ),
      ),
    );
  }

  Widget _icerik(BuildContext context, CollectionViewModel vm) {
    if (vm.isLoading && vm.allCards.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (vm.hasError && vm.allCards.isEmpty) {
      return _HataDurumu(viewModel: vm);
    }

    if (vm.allCards.isEmpty) {
      return _BosKoleksiyon(viewModel: vm);
    }

    final kartlar = vm.filteredCards;

    if (kartlar.isEmpty) {
      return _SonucYok(viewModel: vm);
    }

    return RefreshIndicator(
      onRefresh: () => vm.load(showLoading: false),
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        // FIFA kart orani 0.70; izgara hucresine biraz nefes payi
        // birakmak icin 0.66 kullaniyoruz.
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 150,
          childAspectRatio: 0.66,
          crossAxisSpacing: 12,
          mainAxisSpacing: 14,
        ),
        itemCount: kartlar.length,
        itemBuilder: (context, index) {
          final kart = kartlar[index];

          return LayoutBuilder(
            builder: (context, kisitlar) {
              return PremiumPlayerCard.fromInventory(
                kart,
                // Kartin kendi anahtari: liste siralaninca Flutter
                // dogru widget'i dogru yerde tutar.
                key: ValueKey(kart.userCardId),
                width: kisitlar.maxWidth,
                // PERFORMANS: Listede egilme ve holografik animasyon
                // KAPALI. 100+ kart ayni anda animasyon calistirsaydi
                // arayuz takilirdi. Tum efektler karta dokununca
                // acilan detay penceresinde acik.
                interactive: false,
                onTap: () => CardDetailSheet.show(context, kart),
              );
            },
          );
        },
      ),
    );
  }
}

// ====================================================================
// OZET BANT
// ====================================================================
class _OzetBant extends StatelessWidget {
  final CollectionViewModel viewModel;

  const _OzetBant({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final enIyi = viewModel.bestCard;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _kutu('Toplam', '${viewModel.totalCards}', Icons.style_outlined),
          _ayirac(),
          _kutu(
            'En iyi',
            enIyi == null ? '-' : '${enIyi.power}',
            Icons.star_outline,
          ),
          _ayirac(),
          _kutu(
            'Kadro',
            viewModel.canBuildSquad ? 'Hazir' : 'Eksik',
            viewModel.canBuildSquad
                ? Icons.check_circle_outline
                : Icons.error_outline,
            renk: viewModel.canBuildSquad
                ? AppColors.success
                : AppColors.warning,
          ),
        ],
      ),
    );
  }

  Widget _kutu(String etiket, String deger, IconData ikon, {Color? renk}) {
    return Expanded(
      child: Column(
        children: [
          Icon(ikon, size: 18, color: renk ?? AppColors.textSecondary),
          const SizedBox(height: 4),
          Text(
            deger,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: renk ?? AppColors.textPrimary,
            ),
          ),
          Text(
            etiket,
            style: const TextStyle(
              fontSize: 10.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ayirac() => Container(
        width: 1,
        height: 34,
        color: AppColors.surfaceLight,
      );
}

// ====================================================================
// BOS / HATA / SONUC YOK DURUMLARI
// ====================================================================

class _BosKoleksiyon extends StatelessWidget {
  final CollectionViewModel viewModel;

  const _BosKoleksiyon({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.style_outlined,
                size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            const Text(
              'Koleksiyonun bos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Magazadan paket acarak kart kazanabilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            _TestButonu(viewModel: viewModel),
          ],
        ),
      ),
    );
  }
}

class _SonucYok extends StatelessWidget {
  final CollectionViewModel viewModel;

  const _SonucYok({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          const Text(
            'Bu filtreye uyan kart yok',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: viewModel.clearFilters,
            icon: const Icon(Icons.filter_alt_off, size: 18),
            label: const Text('Filtreleri temizle'),
          ),
        ],
      ),
    );
  }
}

class _HataDurumu extends StatelessWidget {
  final CollectionViewModel viewModel;

  const _HataDurumu({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: AppColors.danger),
            const SizedBox(height: 16),
            Text(
              viewModel.errorMessage ?? 'Kartlar yuklenemedi.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => viewModel.load(),
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }
}

/// SADECE GELISTIRME: Katalogdaki 100 karti hesaba ekler.
///
/// Uretimde bu uc nokta 404 doner, buton da hata mesaji gosterir.
/// Kart tasarimlarini ve filtreleri test etmek icin var.
class _TestButonu extends StatelessWidget {
  final CollectionViewModel viewModel;

  const _TestButonu({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: viewModel.isBusy
          ? null
          : () async {
              final basarili = await viewModel.devGrantAllCards();
              if (!context.mounted) return;

              if (basarili) {
                AppSnackBar.showSuccess(
                  context,
                  'Katalogdaki tum kartlar eklendi.',
                );
              } else if (viewModel.errorMessage != null) {
                AppSnackBar.showError(context, viewModel.errorMessage!);
                viewModel.clearError();
              }
            },
      icon: const Icon(Icons.science_outlined, size: 18),
      label: const Text('TEST: Tum kartlari ekle'),
    );
  }
}
