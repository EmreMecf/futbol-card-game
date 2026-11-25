part of 'web_screens.dart';

// ====================================================================
// KARTLARIM
// ====================================================================
class WebCollection extends StatefulWidget {
  final CollectionViewModel vm;
  final void Function(InventoryCard) onDetail;
  const WebCollection({super.key, required this.vm, required this.onDetail});

  @override
  State<WebCollection> createState() => _WebCollectionState();
}

class _WebCollectionState extends State<WebCollection> {
  String? _id;

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final cards = vm.filteredCards;
    final sel = cards.where((c) => c.userCardId == _id).firstOrNull ?? cards.firstOrNull;
    const tiers = [CardTier.bronze, CardTier.silver, CardTier.gold, CardTier.diamond, CardTier.legend];
    const pos = <(CardPosition, Color)>[
      (CardPosition.goalkeeper, Color(0xFFFFC832)),
      (CardPosition.defender, Color(0xFF5FB4FF)),
      (CardPosition.midfielder, Color(0xFF4FE07A)),
      (CardPosition.forward, Color(0xFFFF6B7D)),
    ];
    return WebShell(
      route: AppRoutes.collection,
      children: [
        wBox(258, 100, 1010, 165, Text('KARTLARIM / KOLEKSİYON'.tr, maxLines: 1, style: wTitle(56))),
        wBox(
          1020,
          110,
          1180,
          154,
          Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFF1C0D4C), borderRadius: BorderRadius.circular(22)),
            child: Text('${vm.uniqueOwned}${vm.catalogSize == null ? '' : ' / ${vm.catalogSize}'}', style: wTitle(28)),
          ),
        ),
        wBox(
          258,
          176,
          350,
          224,
          WButton('TÜMÜ'.tr, fontSize: 25, onTap: vm.clearCategoryFilters),
        ),
        for (final (i, t) in tiers.indexed)
          wBox(
            367.0 + i * 55,
            180,
            407.0 + i * 55,
            220,
            Semantics(
              button: true,
              selected: vm.tierFilter == t,
              label: V21Rarity.of(t).name,
              child: V21Tap(
                onTap: () => vm.setTierFilter(vm.tierFilter == t ? null : t),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: wTierColor(t),
                    border: Border.all(color: vm.tierFilter == t ? Colors.white : const Color(0xFF2A1567), width: 4),
                  ),
                ),
              ),
            ),
          ),
        for (final (i, p) in pos.indexed)
          wBox(
            668.0 + i * 85,
            180,
            745.0 + i * 85,
            220,
            V21Tap(
              onTap: () => vm.setPositionFilter(vm.positionFilter == p.$1 ? null : p.$1),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: vm.positionFilter == p.$1 ? p.$2.withValues(alpha: 0.35) : const Color(0xFF2A1567),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: p.$2, width: 3),
                ),
                child: Text(p.$1.code, style: wTitle(25, color: p.$2)),
              ),
            ),
          ),
        wBox(
          1026,
          178,
          1184,
          222,
          PopupMenuButton<CollectionSort>(
            onSelected: vm.setSort,
            itemBuilder: (_) => [for (final s in CollectionSort.values) PopupMenuItem(value: s, child: Text(s.label))],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF2A1567),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF5B45A8), width: 2),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(vm.sort.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: wBody(16))),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
        wBox(
          258,
          240,
          1192,
          932,
          vm.isLoading && cards.isEmpty
              ? const Center(child: CircularProgressIndicator(color: V21Colors.goldTop))
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(6, 8, 6, 12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 18,
                    childAspectRatio: 165 / 205,
                  ),
                  itemCount: cards.length,
                  itemBuilder: (context, i) => WCard.of(
                    cards[i],
                    selected: cards[i].userCardId == sel?.userCardId,
                    onTap: () => setState(() => _id = cards[i].userCardId),
                  ),
                ),
        ),
        if (sel != null) wBox(1205, 112, 1662, 912, _CardDetail(card: sel, onDetail: () => widget.onDetail(sel))),
      ],
    );
  }
}

class _CardDetail extends StatelessWidget {
  final InventoryCard card;
  final VoidCallback onDetail;
  const _CardDetail({required this.card, required this.onDetail});

  @override
  Widget build(BuildContext context) {
    final a = card.attributes;
    Widget stat(IconData i, String l, int v) => Container(
      height: 44,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: wInset, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(i, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          SizedBox(width: 62, child: Text(l, style: wBody(21))),
          Expanded(child: WBar(value: v / 100, height: 15)),
          SizedBox(width: 54, child: Text('$v', textAlign: TextAlign.right, style: wTitle(26))),
        ],
      ),
    );
    Widget info(String l, Widget v) => Expanded(
      child: Row(
        children: [
          Expanded(child: Text(l, style: wBody(21, color: const Color(0xFFD9CCF7)))),
          v,
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: wPanelBorder, width: 3),
        gradient: const LinearGradient(colors: [Color(0xFF4A28A8), wPanelBottom], begin: Alignment.topCenter, end: Alignment.bottomCenter),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 222,
            child: V21Tap(
              onTap: onDetail,
              child: Row(
                children: [
                  SizedBox(
                    width: 176,
                    child: WCard.of(card),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FittedBox(fit: BoxFit.scaleDown, child: Text(card.fullName, maxLines: 1, style: wTitle(38))),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
                          decoration: BoxDecoration(color: const Color(0xFF5A2FB4), borderRadius: BorderRadius.circular(20), border: Border.all(color: wTierColor(card.tier), width: 2)),
                          child: WTierLabel(tier: card.tier, size: 23),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 78,
                              height: 78,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF241446), border: Border.all(color: Colors.white, width: 4)),
                              child: Text('${card.power}', style: wTitle(40)),
                            ),
                            const SizedBox(width: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(color: const Color(0xFF5A2FB4), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white54, width: 2)),
                              child: Text(card.position.code, style: wTitle(30)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 168,
            child: WPanel(
              title: 'KART BİLGİSİ'.tr,
              headerHeight: 46,
              titleSize: 27,
              icon: const Icon(Icons.fact_check_rounded, color: Colors.white, size: 34),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Column(
                  children: [
                    info('Pozisyon'.tr, Text(card.position.code, style: wTitle(23))),
                    info('Nadirlik'.tr, Text(V21Format.upper(V21Rarity.of(card.tier).name), style: wTitle(23, color: wTierColor(card.tier)))),
                    info('Takım'.tr, Text(V21Format.upper(card.club ?? '-'), maxLines: 1, style: wTitle(23, color: wTierColor(card.tier)))),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: WPanel(
              title: 'ÖZELLİKLER'.tr,
              headerHeight: 46,
              titleSize: 27,
              icon: const Icon(Icons.upgrade_rounded, color: Colors.white, size: 36),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                child: Column(
                  children: [
                    stat(Icons.sports_soccer_rounded, 'Şut'.tr, a?.shooting ?? card.power),
                    stat(Icons.directions_run_rounded, 'Hız'.tr, a?.pace ?? card.power),
                    stat(Icons.shield_rounded, 'Fizik'.tr, a?.physical ?? card.power),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 84,
            child: WButton('GELİŞTİR'.tr, fontSize: 40, onTap: () => context.push(AppRoutes.progress)),
          ),
        ],
      ),
    );
  }
}
