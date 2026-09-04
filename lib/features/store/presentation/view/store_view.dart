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
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_breakpoints.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/screen_header.dart';
import '../../../../shared/widgets/stat_chip.dart';
import '../widgets/pack_box.dart';
import '../../../../core/theme/app_typography.dart';

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

    return AppShell(
      currentRoute: AppRoutes.store,
      child: SafeArea(
        bottom: false,
        child: ResponsiveBuilder(
          builder: (context, boyut) {
            final kenar = AppBreakpoints.pagePadding(boyut);
            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    kenar,
                    boyut.usesSidebar ? 32 : 16,
                    kenar,
                    0,
                  ),
                  child: ScreenHeader(
                    title: 'Mağaza',
                    subtitle:
                        'Paketten çıkan kart tamamen sunucuda belirlenir',
                    actions: [StatChip.coins(vm.coins)],
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(child: _icerik(context, vm)),
              ],
            );
          },
        ),
      ),
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

    return ResponsiveBuilder(
      builder: (context, boyut) {
        final kenar = AppBreakpoints.pagePadding(boyut);
        final genis = boyut.usesSidebar;

        return ListView(
          padding: EdgeInsets.fromLTRB(
            kenar,
            4,
            kenar,
            // Telefonda alt gezinme çubuğunun altına kaymasın
            genis ? 32 : 110,
          ),
          children: [
            if (genis)
              // MASAÜSTÜ: üç sütun. Paketler yan yana durunca hangisinin
              // daha iyi olduğu karşılaştırılabiliyor; alt alta uzun bir
              // listede oyuncu ikisini aynı anda göremiyordu.
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate:
                    const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 380,
                  mainAxisExtent: 420,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                ),
                itemCount: vm.packs.length,
                itemBuilder: (context, i) => _PaketKarti(
                  viewModel: vm,
                  pack: vm.packs[i],
                  dikey: true,
                ),
              )
            else
              for (final paket in vm.packs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _PaketKarti(viewModel: vm, pack: paket),
                ),

            const SizedBox(height: 6),
            NoticeBar.info(
              'Rastgeleliği veritabanı üretiyor ve seçimi modülo sapması '
              'olmadan yapıyor. Uygulama sonuca karışamaz; yukarıdaki '
              'oranlar gösterim değil, gerçekten uygulanan değerler.',
              title: 'Çekiliş nasıl yapılıyor?',
            ),
          ],
        );
      },
    );
  }
}

// ====================================================================
// PAKET KARTI
// ====================================================================
/// Mağazadaki bir paket.
///
/// Telefonda YATAY: solda kutu, sağda bilgiler. Dar ekranda dikey bir
/// kart listesi çok az paket gösteriyor, oyuncu karşılaştırma yapmak
/// için sürekli kaydırmak zorunda kalıyordu.
///
/// Masaüstünde DİKEY ([dikey] = true): kutu üstte, bilgiler altta.
/// Üç sütunlu ızgarada bu oran daha dengeli duruyor.
class _PaketKarti extends StatelessWidget {
  final StoreViewModel viewModel;
  final PackType pack;
  final bool dikey;

  const _PaketKarti({
    required this.viewModel,
    required this.pack,
    this.dikey = false,
  });

  /// Bu paket vitrinde öne çıkarılan mı?
  /// Karar [StoreViewModel.featuredSlug] içinde, veriden türetiliyor.
  bool get _oneCikan => viewModel.featuredSlug == pack.slug;

  @override
  Widget build(BuildContext context) {
    final tema = CardTierTheme.of(pack.signatureTier);
    final aciliyor = viewModel.openingPackSlug == pack.slug;
    final parasiYeter = viewModel.canAfford(pack);

    return Container(
      padding: EdgeInsets.all(dikey ? 22 : 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(dikey ? 22 : 20),
        border: Border.all(
          color: _oneCikan ? tema.frameGradient[1] : AppColors.surfaceLight,
        ),
      ),
      child: Stack(
        children: [
          // Kutunun arkasındaki renk hüzmesi
          Positioned(
            left: dikey ? null : -30,
            top: dikey ? -70 : -30,
            child: Container(
              width: dikey ? 260 : 150,
              height: dikey ? 200 : 150,
              decoration: BoxDecoration(
                shape: dikey ? BoxShape.rectangle : BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    tema.glowColor.withValues(alpha: 0.22),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          if (dikey)
            _dikeyGovde(context, tema, aciliyor, parasiYeter)
          else
            _yatayGovde(context, tema, aciliyor, parasiYeter),

          if (_oneCikan)
            Positioned(
              right: 0,
              top: 0,
              child: _OneCikanRozeti(color: tema.frameGradient[1]),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // TELEFON: solda kutu, sağda bilgiler
  // ------------------------------------------------------------------
  Widget _yatayGovde(
    BuildContext context,
    CardTierTheme tema,
    bool aciliyor,
    bool parasiYeter,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        PackBox(pack: pack, width: 84),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                pack.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.display(
                  size: 21,
                  weight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _altBilgi(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyXS,
              ),
              const SizedBox(height: 8),
              _oranlar(compact: true),
              const SizedBox(height: 10),
              _satinAlButonu(context, aciliyor, parasiYeter),
            ],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // MASAÜSTÜ: kutu üstte, bilgiler altta
  // ------------------------------------------------------------------
  Widget _dikeyGovde(
    BuildContext context,
    CardTierTheme tema,
    bool aciliyor,
    bool parasiYeter,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: PackBox(pack: pack, width: 122),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          pack.name,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.display(
            size: 25,
            weight: FontWeight.w900,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _altBilgi(),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.bodyS,
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ÇIKMA İHTİMALLERİ', style: AppTypography.label),
              const SizedBox(height: 7),
              _oranlar(compact: false),
            ],
          ),
        ),
        const Spacer(),
        _satinAlButonu(context, aciliyor, parasiYeter),
      ],
    );
  }

  /// "5 kart · En az 1 Altın garantili"
  String _altBilgi() {
    final parcalar = <String>['${pack.cardCount} kart'];
    if (pack.hasGuaranteedFormation) {
      parcalar.add('Tam kadro garantili (1-4-4-2)');
    } else if (pack.description != null && pack.description!.isNotEmpty) {
      parcalar.add(pack.description!);
    }
    return parcalar.join(' \u00b7 ');
  }

  Widget _oranlar({required bool compact}) {
    // Ağırlığı sıfır olanlar gösterilmiyor: "%0" bir bilgi değil,
    // gürültü. Kadro paketinde bronz hiç çıkmıyorsa satır da olmamalı.
    final gorunenler = pack.odds.where((o) => o.weight > 0).toList();
    if (gorunenler.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: compact ? 10 : 12,
      runSpacing: compact ? 4 : 6,
      children: [
        for (final o in gorunenler) OddsChip(odds: o, compact: compact),
      ],
    );
  }

  Widget _satinAlButonu(
    BuildContext context,
    bool aciliyor,
    bool parasiYeter,
  ) {
    if (aciliyor) {
      return SizedBox(
        height: dikey ? 46 : 40,
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.accent,
            ),
          ),
        ),
      );
    }

    final etkin = parasiYeter && pack.isPurchasable;

    return Material(
      color: etkin ? AppColors.accent : AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(dikey ? 14 : 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(dikey ? 14 : 12),
        onTap: etkin ? () => _satinAl(context, viewModel) : null,
        child: SizedBox(
          height: dikey ? 46 : 40,
          child: Center(
            child: etkin
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 17,
                        height: 17,
                        decoration: const BoxDecoration(
                          color: AppColors.background,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        pack.isFree ? 'ÜCRETSİZ' : _binlik(pack.priceCoins),
                        style: AppTypography.display(
                          size: dikey ? 19 : 17,
                          weight: FontWeight.w900,
                          color: AppColors.background,
                        ),
                      ),
                    ],
                  )
                : Text(
                    'YETERSİZ COİN',
                    style: AppTypography.display(
                      size: dikey ? 16 : 14,
                      weight: FontWeight.w800,
                      color: AppColors.textSecondary,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  static String _binlik(int sayi) {
    final metin = sayi.toString();
    final tampon = StringBuffer();
    for (var i = 0; i < metin.length; i++) {
      if (i > 0 && (metin.length - i) % 3 == 0) tampon.write('.');
      tampon.write(metin[i]);
    }
    return tampon.toString();
  }

  /// Paketi açar. Hata olursa oyuncuya gösterir.
  ///
  /// Sessizce başarısız olmak en kötüsü: coin gitti mi gitmedi mi
  /// belli olmuyordu. Sunucu "yetersiz coin" ya da "paket bulunamadi"
  /// derse mesajı olduğu gibi gösteriyoruz.
  Future<void> _satinAl(BuildContext context, StoreViewModel vm) async {
    final basarili = await vm.openPack(pack);

    if (basarili || !context.mounted) return;

    final mesaj = vm.errorMessage;
    if (mesaj != null) {
      AppSnackBar.showError(context, mesaj);
      vm.clearError();
    }
  }
}

/// "ÖNE ÇIKAN" rozeti
class _OneCikanRozeti extends StatelessWidget {
  final Color color;

  const _OneCikanRozeti({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'ÖNE ÇIKAN',
        style: AppTypography.body(
          size: 9.5,
          weight: FontWeight.w900,
          color: AppColors.background,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

