import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/ref_tokens.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/error_snackbar.dart';
import '../../../../shared/widgets/ref/ref_ui.dart';
import '../../../../shared/widgets/ref_card/ref_player_card.dart';
import '../viewmodel/collection_view_model.dart';
import '../widgets/card_detail_sheet.dart';

/// KART KOLEKSİYONU — referans `collection()` ekranı.
///
///   .sectionhead  h2 "KART KOLEKSİYONU" + .pill "N KART"
///   .searchfield  "Futbolcu adı ara..."
///   .filter-row   Tümü / Forvet / Orta Saha / Defans / Kaleci / Efsane
///                 (+ nadirlik ve favori çipleri: oyunda gerçek filtreler)
///   .collect-grid 2 sütun, 9px boşluk, .collectible kartlar
///
/// Kart verisi sunucudan (/api/inventory); filtreleme bellekte.
class CollectionView extends StatelessWidget {
  const CollectionView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CollectionViewModel>(
      create: (_) => getIt<CollectionViewModel>()..load(),
      child: const AppShell(currentRoute: AppRoutes.collection, child: _Govde()),
    );
  }
}

class _Govde extends StatefulWidget {
  const _Govde();

  @override
  State<_Govde> createState() => _GovdeState();
}

class _GovdeState extends State<_Govde> {
  final _arama = TextEditingController();

  @override
  void dispose() {
    _arama.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CollectionViewModel>();

    return LayoutBuilder(builder: (context, k) {
      // Telefonda referanstaki gibi 2 sütun; genişledikçe sütun artar,
      // kart ölçüsü referanstakine yakın kalır (176-210 px).
      final icGenislik = (k.maxWidth.clamp(0.0, 1180.0)) - Ref.pagePadding.horizontal;
      final sutun = icGenislik < 520 ? 2 : (icGenislik / 200).floor().clamp(3, 6);
      final kenarBosluk = (k.maxWidth - 1180).clamp(0.0, double.infinity) / 2;

      return RefreshIndicator(
        color: Ref.accent,
        backgroundColor: Ref.panel,
        onRefresh: () => vm.load(showLoading: false),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: Ref.pagePadding.copyWith(
                left: Ref.pagePadding.left + kenarBosluk,
                right: Ref.pagePadding.right + kenarBosluk,
                bottom: 0,
              ),
              sliver: SliverList.list(children: [
                RefPageEnter(
                  child: RefSectionHead(
                    'KART KOLEKSİYONU',
                    size: 27,
                    trailing: RefPill('${vm.totalCards} KART'),
                  ),
                ),
                const SizedBox(height: Ref.pageGap),
                RefSearchField(
                  controller: _arama,
                  hint: 'Futbolcu adı ara...',
                  onChanged: vm.setSearch,
                ),
                const SizedBox(height: Ref.pageGap),
                _Filtreler(vm: vm),
                const SizedBox(height: Ref.pageGap),
              ]),
            ),
            ..._icerik(context, vm, sutun, kenarBosluk),
          ],
        ),
      );
    });
  }

  List<Widget> _icerik(BuildContext context, CollectionViewModel vm, int sutun, double kenar) {
    final dolgu = EdgeInsets.fromLTRB(
        Ref.pagePadding.left + kenar, 0, Ref.pagePadding.right + kenar, Ref.pagePadding.bottom);

    Widget tek(Widget w) => SliverPadding(padding: dolgu, sliver: SliverToBoxAdapter(child: w));

    if (vm.isLoading && vm.allCards.isEmpty) {
      return [
        tek(const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator(color: Ref.accent)),
        )),
      ];
    }
    if (vm.hasError && vm.allCards.isEmpty) {
      return [
        tek(RefCardPanel(children: [
          Text(vm.errorMessage ?? 'Kartlar yüklenemedi.', style: Ref.bodyText(12, color: Ref.text)),
          RefSecondaryButton('TEKRAR DENE', onTap: () => vm.load()),
        ])),
      ];
    }
    if (vm.allCards.isEmpty) {
      return [tek(_BosKoleksiyon(vm: vm))];
    }

    final kartlar = vm.filteredCards;
    if (kartlar.isEmpty) {
      return [
        tek(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Referans: <div class="muted">Bu filtre için kart bulunamadı.</div>
            Text('Bu filtre için kart bulunamadı.', style: Ref.bodyText(14, color: Ref.muted)),
            const SizedBox(height: 10),
            RefNeutralButton(
              label: 'FİLTRELERİ TEMİZLE',
              onTap: () {
                _arama.clear();
                vm.clearFilters();
              },
            ),
          ],
        )),
      ];
    }

    return [
      SliverPadding(
        padding: dolgu,
        sliver: SliverGrid.builder(
          // .collect-grid { grid-template-columns:repeat(2,1fr); gap:9px }
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: sutun,
            crossAxisSpacing: 9,
            mainAxisSpacing: 9,
            childAspectRatio: RefCardLayout.grid.aspectRatio,
          ),
          itemCount: kartlar.length,
          itemBuilder: (context, i) {
            final kart = kartlar[i];
            final favori = vm.isFavorite(kart);
            return LayoutBuilder(
              builder: (context, k) => RefPlayerCard(
                key: ValueKey(kart.userCardId),
                name: kart.fullName,
                position: kart.position,
                tier: kart.tier,
                power: kart.power,
                seed: kart.cardId,
                kitSeed: kart.club ?? kart.nationality,
                imageUrl: kart.imageUrl,
                width: k.maxWidth,
                isFavorite: favori,
                isLocked: kart.isLocked,
                // Listede yalnız Efsane ışığı döner (performans)
                animate: kart.tier == CardTier.legend,
                onTap: () => CardDetailSheet.show(
                  context,
                  kart,
                  isFavorite: favori,
                  onToggleFavorite: () => vm.toggleFavorite(kart),
                ),
              ),
            );
          },
        ),
      ),
    ];
  }
}

/// .filter-row { display:flex; gap:6px; flex-wrap:wrap }
class _Filtreler extends StatelessWidget {
  final CollectionViewModel vm;
  const _Filtreler({required this.vm});

  @override
  Widget build(BuildContext context) {
    final mevkiler = [
      ('Forvet', CardPosition.forward),
      ('Orta Saha', CardPosition.midfielder),
      ('Defans', CardPosition.defender),
      ('Kaleci', CardPosition.goalkeeper),
    ];
    final nadirlikler = [CardTier.bronze, CardTier.silver, CardTier.gold, CardTier.diamond];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Referanstaki satır, aynı sırayla
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            RefFilterChip('Tümü', active: !vm.hasCategoryFilter, onTap: vm.clearCategoryFilters),
            for (final (ad, m) in mevkiler)
              RefFilterChip(ad, active: vm.positionFilter == m, onTap: () => vm.setPositionFilter(m)),
            RefFilterChip('Efsane',
                active: vm.tierFilter == CardTier.legend, onTap: () => vm.setTierFilter(CardTier.legend)),
          ],
        ),
        const SizedBox(height: 6),
        // Oyundaki diğer gerçek filtreler, aynı çip stiliyle
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final t in nadirlikler)
              RefFilterChip(RefRarity.of(t).name, active: vm.tierFilter == t, onTap: () => vm.setTierFilter(t)),
            RefFilterChip('Favoriler (${vm.favoriteCount})',
                active: vm.favoritesOnly, onTap: () => vm.setFavoritesOnly(!vm.favoritesOnly)),
          ],
        ),
      ],
    );
  }
}

class _BosKoleksiyon extends StatelessWidget {
  final CollectionViewModel vm;
  const _BosKoleksiyon({required this.vm});

  @override
  Widget build(BuildContext context) => RefCardPanel(children: [
        Text('Koleksiyonun boş', style: Ref.h3()),
        Text('Mağazadan paket açarak kart kazanabilirsin.', style: Ref.bodyText(12, color: Ref.muted)),
        // SADECE GELİŞTİRME: üretimde bu uç 404 döner ve hata gösterilir
        RefNeutralButton(
          label: 'TEST: Tüm kartları ekle',
          onTap: vm.isBusy
              ? null
              : () async {
                  final ok = await vm.devGrantAllCards();
                  if (!context.mounted) return;
                  if (ok) {
                    AppSnackBar.showSuccess(context, 'Katalogdaki tüm kartlar eklendi.');
                  } else if (vm.errorMessage != null) {
                    AppSnackBar.showError(context, vm.errorMessage!);
                    vm.clearError();
                  }
                },
        ),
      ]);
}
