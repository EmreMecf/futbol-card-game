import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../core/di/injection.dart';
import '../../../core/router/app_routes.dart';
import '../../../features/collection/presentation/viewmodel/collection_view_model.dart';
import '../rewards/v21_card_sheets.dart';
import '../../../features/progress/domain/progress_repository.dart';
import '../../ui_v21.dart';
import '../home/v21_home_nav.dart';

/// V2.1 KOLEKSİYON — "KARTLARIM" (referans `assets/v21/screens/collection.png`).
///
///   KARTLARIM                 ( ● 12 / 100 )   ← farklı kart / katalog
///   ▀▀▀▀░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░    ← katalog ilerlemesi → Gelişim
///   [TÜMÜ] (●)(●)(●)(●)(●)                    ← nadirlik
///   [ GK ] [ DEF ] [ MID ] [ FWD ]             ← mevki
///   [ ara...        ] [♥ 3] [⇅]                ← arama, favoriler, sıralama (eski ekrandan)
///   kart ızgarası (2 sütun)                     → kart ayrıntısı
///
/// VERİ: `CollectionViewModel` (mevcut) → `/api/cards/inventory` ve
/// katalog boyutu için `/api/cards/catalog`. Filtreleme ve sıralama
/// ViewModel'de, bellekte (sunucu isteği yok). Katalog alınamazsa sayaç
/// yalnız sahip olunan kart sayısını gösterir, çubuk çizilmez.
class V21CollectionScreen extends StatelessWidget {
  const V21CollectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CollectionViewModel>(
      create: (_) => getIt<CollectionViewModel>()
        ..load()
        ..loadCatalogSize(),
      child: Theme(
        data: V21Theme.data(context),
        child: V21ScreenLayout(
          background: V21Background.page,
          body: (context, sc) => _Body(scale: sc.s),
          bottomNavigation: (context, sc) => V21HomeNav(currentRoute: AppRoutes.collection, scale: sc.s),
        ),
      ),
    );
  }
}

/// Referans nadirlik daireleri (soldan sağa)
const _tierChips = <(CardTier, Color, String)>[
  (CardTier.bronze, Color(0xFFFFAB76), 'Bronz'),
  (CardTier.silver, Color(0xFFE8EEF6), 'Gümüş'),
  (CardTier.gold, Color(0xFFFFE07A), 'Altın'),
  (CardTier.diamond, Color(0xFF7FF3FF), 'Elmas'),
  (CardTier.legend, Color(0xFFE3A9FA), 'Efsane'),
];

/// Referans mevki hapları
const _positionPills = <(CardPosition, Color)>[
  (CardPosition.goalkeeper, Color(0xFFFFC832)),
  (CardPosition.defender, Color(0xFF5FB4FF)),
  (CardPosition.midfielder, Color(0xFF3DD15A)),
  (CardPosition.forward, Color(0xFFFF5A6E)),
];

class _Body extends StatefulWidget {
  final double scale;
  const _Body({required this.scale});

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// "FİLTRELERİ TEMİZLE": arama kutusu da boşalır
  void _clearAll(CollectionViewModel vm) {
    _search.clear();
    vm.clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.scale;
    final vm = context.watch<CollectionViewModel>();
    final side = 16 * k;

    final header = Padding(
      padding: EdgeInsets.fromLTRB(side, 15 * k, 8 * k, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          V21PageTitle(
            title: 'KARTLARIM',
            scale: k,
            trailing: _CountPill(vm: vm, scale: k),
          ),
          SizedBox(height: 11 * k),
          _CatalogBar(vm: vm, scale: k),
          SizedBox(height: 10 * k),
          _TierRow(vm: vm, scale: k),
          SizedBox(height: 10 * k),
          _PositionRow(vm: vm, scale: k),
          SizedBox(height: 10 * k),
          _ToolRow(vm: vm, controller: _search, scale: k),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        SizedBox(height: 12 * k),
        Expanded(
          child: _Content(vm: vm, scale: k, onClearAll: () => _clearAll(vm)),
        ),
      ],
    );
  }
}

class _CountPill extends StatelessWidget {
  final CollectionViewModel vm;
  final double scale;
  const _CountPill({required this.vm, required this.scale});

  @override
  Widget build(BuildContext context) {
    final owned = vm.uniqueOwned;
    final total = vm.catalogSize;
    final loading = vm.isLoading && vm.allCards.isEmpty;
    return V21ResourcePill(
      icon: V21OrbIcon(size: 24 * scale),
      value: loading ? null : owned,
      text: loading ? null : (total == null ? '$owned' : '$owned / $total'),
      semanticsName: 'kart',
      semanticsLabel: loading
          ? 'Kartlar yükleniyor'
          : (total == null ? '$owned farklı kart' : '$total kartın $owned tanesi toplandı'),
      scale: scale,
      width: 120,
    );
  }
}

class _CatalogBar extends StatelessWidget {
  final CollectionViewModel vm;
  final double scale;
  const _CatalogBar({required this.vm, required this.scale});

  @override
  Widget build(BuildContext context) {
    final p = vm.catalogProgress;
    final bar = V21ProgressBar(
      value: p ?? 0,
      height: 14 * scale,
      trackColor: const Color(0xFF201046),
      fillColors: const [Color(0xFFE4B3FF), Color(0xFF9B4BFF)],
      semanticsLabel: 'Koleksiyon ilerlemesi',
    );
    // Referans: bu alan Gelişim ekranına götürür (hotspot "Gelişim")
    final canProgress = getIt.isRegistered<ProgressRepository>();
    return Padding(
      padding: EdgeInsets.only(right: 8 * scale),
      child: Semantics(
        button: canProgress,
        label: canProgress ? 'Gelişim: futbolcu seviyeleri' : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: canProgress ? () => context.push(AppRoutes.progress) : null,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 4 * scale),
            child: bar,
          ),
        ),
      ),
    );
  }
}

class _TierRow extends StatelessWidget {
  final CollectionViewModel vm;
  final double scale;
  const _TierRow({required this.vm, required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final counts = vm.tierCounts;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          V21FilterPill(
            label: 'TÜMÜ',
            selected: !vm.hasCategoryFilter,
            onTap: vm.clearCategoryFilters,
            semanticsLabel: 'Tüm kartlar',
            scale: k,
            width: 70,
            height: 42,
          ),
          for (final (tier, color, name) in _tierChips) ...[
            SizedBox(width: 8 * k),
            V21RarityChip(
              color: color,
              selected: vm.tierFilter == tier,
              onTap: () => vm.setTierFilter(tier),
              semanticsLabel: '$name kartlar, ${counts[tier] ?? 0} kart',
              scale: k,
            ),
          ],
        ],
      ),
    );
  }
}

class _PositionRow extends StatelessWidget {
  final CollectionViewModel vm;
  final double scale;
  const _PositionRow({required this.vm, required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final counts = vm.positionCounts;
    return Padding(
      padding: EdgeInsets.only(right: 8 * k),
      child: Row(
        children: [
          for (var i = 0; i < _positionPills.length; i++) ...[
            if (i > 0) SizedBox(width: 9 * k),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final (pos, color) = _positionPills[i];
                  return V21FilterPill(
                    label: pos.code,
                    color: color,
                    selected: vm.positionFilter == pos,
                    onTap: () => vm.setPositionFilter(pos),
                    semanticsLabel: '${pos.label}, ${counts[pos] ?? 0} kart',
                    scale: k,
                    width: c.maxWidth / k,
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Content extends StatelessWidget {
  final CollectionViewModel vm;
  final double scale;
  final VoidCallback onClearAll;
  const _Content({required this.vm, required this.scale, required this.onClearAll});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    if (vm.isLoading && vm.allCards.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: V21Colors.goldTop));
    }
    if (vm.allCards.isEmpty) {
      final error = vm.hasError;
      return _Message(
        scale: k,
        icon: error ? Icons.cloud_off_rounded : Icons.style_rounded,
        title: error ? 'BAĞLANTI SORUNU' : 'HENÜZ KART YOK',
        text: error
            ? (vm.errorMessage ?? 'Kartlar yüklenemedi.')
            : 'Henüz kartın yok. Mağazadan paket açarak koleksiyonuna başla.',
        action: error ? 'TEKRAR DENE' : 'MAĞAZAYA GİT',
        onAction: error ? () => vm.load() : () => context.go(AppRoutes.store),
      );
    }
    final cards = vm.filteredCards;
    if (cards.isEmpty) {
      return _Message(
        scale: k,
        icon: Icons.filter_alt_off_rounded,
        title: 'KART BULUNAMADI',
        text: 'Bu filtrede kart yok.',
        action: 'FİLTRELERİ TEMİZLE',
        onAction: onClearAll,
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final side = 22 * k;
        final gap = 18 * k;
        // Telefonda 2 sütun (referans); genişledikçe sütun artar, kart büyümez
        final columns = ((c.maxWidth - side * 2 + gap) / (168 * k + gap)).floor().clamp(2, 6);
        final cardW = (c.maxWidth - side * 2 - gap * (columns - 1)) / columns;
        return RefreshIndicator(
          color: V21Colors.goldTop,
          backgroundColor: V21Colors.panel,
          onRefresh: () => vm.load(showLoading: false),
          child: GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(side, 4 * k, side, 24 * k),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: gap,
              mainAxisSpacing: 20 * k,
              childAspectRatio: V21PlayerCard.baseWidth / V21PlayerCard.baseHeight,
            ),
            itemCount: cards.length,
            itemBuilder: (context, i) {
              final card = cards[i];
              return V21PlayerCard(
                key: ValueKey(card.userCardId),
                name: card.fullName,
                position: card.position,
                tier: card.tier,
                power: card.power,
                seed: card.cardId,
                kitSeed: card.club ?? card.nationality,
                imageUrl: card.imageUrl,
                locked: card.isLocked,
                favorite: vm.isFavorite(card),
                width: cardW,
                onTap: () => _openDetail(context, card),
              );
            },
          ),
        );
      },
    );
  }

  void _openDetail(BuildContext context, InventoryCard card) {
    final favorite = vm.isFavorite(card);
    V21CardDetailSheet.show(context, card, isFavorite: favorite, onToggleFavorite: () => vm.toggleFavorite(card)).then((
      _,
    ) {
      // Gelişim ekranında seviye değişmiş olabilir
      if (getIt.isRegistered<ProgressRepository>()) vm.load(showLoading: false);
    });
  }
}

class _Message extends StatelessWidget {
  final double scale;
  final IconData icon;
  final String title;
  final String text;
  final String action;
  final VoidCallback onAction;
  const _Message({
    required this.scale,
    required this.icon,
    required this.title,
    required this.text,
    required this.action,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) => ListView(
    padding: EdgeInsets.all(22 * scale),
    children: [
      V21EmptyState(icon: icon, title: title, message: text, actionLabel: action, onAction: onAction, scale: scale),
    ],
  );
}

/// Arama + favoriler + sıralama (referansta yok; eski ekranın gerçek
/// özellikleri V2.1 görünümüyle korunur)
class _ToolRow extends StatelessWidget {
  final CollectionViewModel vm;
  final TextEditingController controller;
  final double scale;
  const _ToolRow({required this.vm, required this.controller, required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final sorted = vm.sort != CollectionSort.powerDesc;
    return Padding(
      padding: EdgeInsets.only(right: 8 * k),
      child: Row(
        children: [
          Expanded(
            child: V21SearchField(
              controller: controller,
              hint: 'Futbolcu, kulüp, ülke ara',
              onChanged: vm.setSearch,
              scale: k,
            ),
          ),
          SizedBox(width: 8 * k),
          V21IconPill(
            icon: Icons.favorite_rounded,
            iconColor: V21Colors.danger,
            badge: '${vm.favoriteCount}',
            selected: vm.favoritesOnly,
            onTap: () => vm.setFavoritesOnly(!vm.favoritesOnly),
            semanticsLabel: vm.favoritesOnly
                ? 'Yalnız favoriler gösteriliyor (${vm.favoriteCount}). Tümünü göstermek için dokun'
                : 'Yalnız favorileri göster (${vm.favoriteCount})',
            scale: k,
          ),
          SizedBox(width: 8 * k),
          V21IconPill(
            icon: Icons.swap_vert_rounded,
            selected: sorted,
            onTap: () => _showSortSheet(context, vm, k),
            semanticsLabel: 'Sıralama: ${vm.sort.label}',
            scale: k,
          ),
        ],
      ),
    );
  }
}

Future<void> _showSortSheet(BuildContext context, CollectionViewModel vm, double k) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: EdgeInsets.all(12 * k),
        child: V21GamePanel(
          scale: k,
          padding: EdgeInsets.fromLTRB(14 * k, 14 * k, 14 * k, 8 * k),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('SIRALA', style: V21Type.title(24 * k, shadows: V21Type.inkShadow(k))),
              SizedBox(height: 8 * k),
              for (final s in CollectionSort.values)
                Semantics(
                  button: true,
                  selected: vm.sort == s,
                  label: s.label,
                  excludeSemantics: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10 * k),
                    onTap: () {
                      vm.setSort(s);
                      Navigator.of(sheet).pop();
                    },
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 11 * k, horizontal: 4 * k),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              s.label,
                              style: V21Type.label(
                                15 * k,
                                weight: FontWeight.w800,
                                color: vm.sort == s ? V21Colors.goldTop : V21Colors.text,
                              ),
                            ),
                          ),
                          if (vm.sort == s) Icon(Icons.check_rounded, size: 20 * k, color: V21Colors.goldTop),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
