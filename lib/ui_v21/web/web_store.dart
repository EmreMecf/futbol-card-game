part of 'web_screens.dart';

// ====================================================================
// MAĞAZA
// ====================================================================
/// Paket görseli: yelpaze kart sırtları
class _PackArt extends StatelessWidget {
  final Color accent;
  const _PackArt({required this.accent});

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      for (final (a, x) in const [(-0.22, -26.0), (0.22, 26.0), (0.0, 0.0)])
        Transform.translate(
          offset: Offset(x, 0),
          child: Transform.rotate(
            angle: a,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.55), blurRadius: 14)],
              ),
              child: V21CardBack(width: 104, semanticsLabel: 'Kart paketi'.tr),
            ),
          ),
        ),
    ],
  );
}

/// Günün teklifi indirim rozeti; teklif yoksa oran gösterilmez
class _OfferBadge extends StatelessWidget {
  final int? percent;
  const _OfferBadge({required this.percent});

  @override
  Widget build(BuildContext context) => Container(
    alignment: const Alignment(0, 0.42),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: const Color(0xFFC81E3C),
      border: Border.all(color: const Color(0xFF3A0A2A), width: 5),
    ),
    child: Text(percent == null ? '–' : '%$percent', style: wTitle(40)),
  );
}

class WebStore extends StatelessWidget {
  final StoreViewModel vm;
  final void Function(PackType) onBuy;
  final VoidCallback onBuyOffer;
  const WebStore({super.key, required this.vm, required this.onBuy, required this.onBuyOffer});

  static Color _art(PackType p, int i) => p.slug.contains('squad') || p.slug.contains('kadro')
      ? const Color(0xFF4FC3FF)
      : (p.slug.contains('premium') || i == 1 ? const Color(0xFFD9A2F8) : const Color(0xFFFFC832));

  @override
  Widget build(BuildContext context) {
    final offer = vm.dailyOffer;
    final packs = vm.packs.where((p) => p.isPurchasable && p.priceCoins > 0).take(3).toList();
    final featured = packs.where((p) => p.slug == vm.featuredSlug).firstOrNull ?? packs.firstOrNull;
    final odds = (featured?.odds ?? []).where((o) => o.weight > 0).toList()
      ..sort((a, b) => a.tier.rank.compareTo(b.tier.rank));
    return WebShell(
      route: AppRoutes.store,
      children: [
        wBox(296, 100, 900, 170, Text('MAĞAZA'.tr, style: wTitle(60))),
        wBox(
          292,
          180,
          1146,
          428,
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                wImage('offer_bg', fit: BoxFit.fill),
                // İndirim oranı sunucudan gelir; görseldeki rozetin üstünü kapatır
                Positioned(left: 690, top: -32, width: 124, height: 124, child: _OfferBadge(percent: offer?.discountPct)),
              ],
            ),
          ),
        ),
        wBox(
          350,
          244,
          760,
          332,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(offer?.name ?? 'Teklif yok'.tr, maxLines: 1, style: wTitle(52)),
              Text(offer == null ? 'Yeni teklif yakında'.tr : '{cardCount} kart · %{discountPct} indirim'.trArgs({'cardCount': offer.cardCount, 'discountPct': offer.discountPct}), style: wBody(25, color: const Color(0xFFFFE6DC))),
            ],
          ),
        ),
        if (offer != null)
          wBox(
            342,
            338,
            652,
            412,
            WButton(
              offer.boughtToday ? 'ALINDI'.tr : V21Format.thousands(offer.discountedPrice),
              tone: V21ButtonTone.green,
              fontSize: 38,
              leading: offer.boughtToday ? null : const V21CoinIcon(size: 42),
              busy: vm.openingPackSlug == offer.packSlug,
              onTap: vm.canBuyDailyOffer ? onBuyOffer : null,
            ),
          ),
        wBox(
          1172,
          180,
          1656,
          418,
          getIt.isRegistered<ChestsViewModel>()
              ? ChangeNotifierProvider<ChestsViewModel>(
                  create: (_) => getIt<ChestsViewModel>()..load(),
                  child: Builder(
                    builder: (context) => WPanel(
                      title: 'SANDIKLAR'.tr,
                      icon: wImage('chest_small', fit: BoxFit.contain),
                      child: _ChestSlots(vm: context.watch<ChestsViewModel>()),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        wBox(292, 436, 1000, 498, Text('KART PAKETLERİ'.tr, style: wTitle(46))),
        for (final (i, p) in packs.indexed)
          wBox(292.0 + i * 319, 502, 610.0 + i * 319, 724, _packCard(p, _art(p, i))),
        wBox(
          1258,
          448,
          1656,
          656,
          V21Tap(onTap: () => context.go(AppRoutes.season), child: ClipRRect(borderRadius: BorderRadius.circular(18), child: wImage('season_banner_small', fit: BoxFit.fill))),
        ),
        wBox(
          292,
          745,
          1244,
          812,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(color: const Color(0xFF3A2088), borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                Text('ÇIKMA İHTİMALİ'.tr, style: wBody(22, color: const Color(0xFFD9CCF7), weight: FontWeight.w800)),
                const SizedBox(width: 24),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      children: [
                        for (final o in odds) ...[
                          Container(width: 46, height: 46, decoration: BoxDecoration(shape: BoxShape.circle, color: wTierColor(o.tier), border: Border.all(color: const Color(0xFF241446), width: 4))),
                          const SizedBox(width: 12),
                          Text(o.displayPercent, style: wTitle(32)),
                          const SizedBox(width: 40),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Paketler bu sayfanın kendisi: seçili sekme, tıklanmaz
        wBox(
          432,
          840,
          762,
          924,
          Semantics(
            selected: true,
            label: 'Paketler, seçili sekme'.tr,
            excludeSemantics: true,
            child: IgnorePointer(child: WButton('PAKETLER'.tr, fontSize: 38, onTap: () {})),
          ),
        ),
        wBox(796, 840, 1126, 924, WButton('TEKLİFLER'.tr, tone: V21ButtonTone.blue, fontSize: 38, onTap: () => context.push(AppRoutes.sbc))),
        wBox(1158, 840, 1488, 924, WButton('KOZMETİK'.tr, tone: V21ButtonTone.blue, fontSize: 38, onTap: () => context.push(AppRoutes.inventory))),
      ],
    );
  }

  Widget _packCard(PackType p, Color art) {
    final missing = p.priceCoins - vm.coins;
    return WPanel(
      child: Stack(
        children: [
          Positioned(left: 4, top: 8, bottom: 8, width: 176, child: _PackArt(accent: art)),
          Positioned(
            right: 8,
            top: 14,
            width: 132,
            child: Column(
              children: [
                FittedBox(fit: BoxFit.scaleDown, child: Text(V21Format.upper(p.name.replaceAll(' Paketi'.tr, '').replaceAll(' Paket'.tr, '')), maxLines: 1, style: wTitle(32))),
                const SizedBox(height: 6),
                Text('${p.cardCount} kart', style: wBody(21, color: const Color(0xFFD9CCF7))),
                const SizedBox(height: 18),
                SizedBox(
                  height: 64,
                  child: WButton(
                    V21Format.thousands(p.priceCoins),
                    tone: missing > 0 ? V21ButtonTone.blue : V21ButtonTone.green,
                    fontSize: 30,
                    leading: const V21CoinIcon(size: 32),
                    busy: vm.openingPackSlug == p.slug,
                    onTap: vm.canAfford(p) ? () => onBuy(p) : null,
                  ),
                ),
              ],
            ),
          ),
          if (missing > 0)
            Positioned(
              right: 10,
              bottom: 8,
              child: Text('{p} altın eksik'.trArgs({'p': V21Format.thousands(missing)}), style: wBody(18, color: const Color(0xFFFF9BC0))),
            ),
        ],
      ),
    );
  }
}
