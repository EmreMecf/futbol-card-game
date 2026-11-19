import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/auth/session_manager.dart';
import '../../core/di/injection.dart';
import '../../core/router/app_routes.dart';
import '../../features/auth/presentation/viewmodel/auth_view_model.dart';
import '../../features/chests/presentation/viewmodel/chests_view_model.dart';
import '../../features/chests/domain/chest_texts.dart';
import '../../ui_v21/screens/deck/v21_emergency_banner.dart';
import '../../features/collection/presentation/viewmodel/collection_view_model.dart';
import '../../features/daily/data/daily_service.dart';
import '../../features/deck/presentation/viewmodel/deck_view_model.dart';
import '../../features/matchmaking/presentation/viewmodel/matchmaking_view_model.dart';
import '../../features/progress/presentation/viewmodel/progress_view_model.dart';
import '../../features/season/presentation/viewmodel/season_view_model.dart';
import '../../features/store/presentation/viewmodel/store_view_model.dart';
import '../../shared/widgets/error_snackbar.dart';
import '../ui_v21.dart';
import 'web_kit.dart';

// ====================================================================
// ANA SAYFA
// ====================================================================
class WebHome extends StatelessWidget {
  const WebHome({super.key});

  @override
  Widget build(BuildContext context) {
    final chests = wWatch<ChestsViewModel>(context);
    final season = wWatch<SeasonViewModel>(context);
    final active = wWatch<AuthViewModel>(context)?.activeMatchId;
    final daily = (season?.missions?.missions ?? const <Mission>[]).where((m) => m.period == 'daily').take(3).toList();
    return WebShell(
      route: AppRoutes.home,
      children: [
        wBox(268, 103, 1138, 692, wImage('home_hero', fit: BoxFit.fill)),
        wBox(
          430,
          532,
          980,
          670,
          WButton(
            active == null ? 'MAÇA BAŞLA' : 'MAÇA DÖN',
            tone: active == null ? V21ButtonTone.gold : V21ButtonTone.green,
            fontSize: 58,
            onTap: () => active == null ? context.go(AppRoutes.matchmaking) : context.push(AppRoutes.matchWithId(active)),
          ),
        ),
        wBox(282, 697, 1136, 915, const _DeckStrip()),
        wBox(
          1147,
          130,
          1660,
          366,
          WPanel(
            title: 'SANDIKLAR',
            icon: wImage('chest_small', fit: BoxFit.contain),
            trailing: const _DailyChip(),
            child: _ChestSlots(vm: chests),
          ),
        ),
        wBox(
          1147,
          392,
          1660,
          666,
          WPanel(
            title: 'GÜNLÜK GÖREVLER',
            icon: const Icon(Icons.track_changes_rounded, color: Color(0xFFFF6B6B), size: 40),
            trailing: V21Tap(
              onTap: () => context.go(AppRoutes.season),
              child: Text('Tümünü Gör  ›', style: wBody(20, color: const Color(0xFFD9CCF7))),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                children: [
                  for (final m in daily) Expanded(child: _MissionRow(m: m)),
                  if (daily.isEmpty)
                    Expanded(child: Center(child: Text('Görevler yükleniyor', style: wBody(20)))),
                ],
              ),
            ),
          ),
        ),
        wBox(
          1150,
          695,
          1660,
          912,
          Semantics(
            button: true,
            label: 'Sezon ödülleri',
            child: V21Tap(onTap: () => context.go(AppRoutes.season), child: wImage('season_banner', fit: BoxFit.fill)),
          ),
        ),
      ],
    );
  }
}

class _MissionRow extends StatelessWidget {
  final Mission m;
  const _MissionRow({required this.m});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: wInset, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(m.completed ? Icons.check_circle_rounded : Icons.event_note_rounded, color: const Color(0xFFD9CCF7), size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: wBody(19)),
                const SizedBox(height: 6),
                WBar(value: m.target == 0 ? 0 : m.progress / m.target, height: 13),
              ],
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(width: 50, child: Text('${m.progress}/${m.target}', maxLines: 1, style: wBody(18))),
          Container(
            width: 104,
            padding: const EdgeInsets.symmetric(vertical: 7),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFF3A2388), borderRadius: BorderRadius.circular(20)),
            child: Text('+${m.xp} XP', maxLines: 1, style: wBody(18, color: V21Colors.goldTop, weight: FontWeight.w900)),
          ),
        ],
      ),
    ),
  );
}

/// Günlük ücretsiz sandık: alınmadıysa Sandıklar başlığında görünür
class _DailyChip extends StatefulWidget {
  const _DailyChip();

  @override
  State<_DailyChip> createState() => _DailyChipState();
}

class _DailyChipState extends State<_DailyChip> {
  DailyStatus? _d;
  bool _busy = false;

  DailyLoopService? get _s => getIt.isRegistered<DailyLoopService>() ? getIt<DailyLoopService>() : null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await _s?.status();
    if (mounted) setState(() => _d = d);
  }

  Future<void> _claim() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _s?.claim();
      chestInventoryChanged.value++;
      if (mounted) AppSnackBar.showInfo(context, 'Günlük sandığın eklendi.');
    } catch (_) {
      if (mounted) AppSnackBar.showInfo(context, 'Sandık alınamadı. Tekrar dene.');
    }
    if (mounted) setState(() => _busy = false);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    if (d == null || !d.enabled || d.claimedToday) return const SizedBox.shrink();
    return SizedBox(
      width: 210,
      height: 46,
      child: WButton('GÜNLÜK SANDIK AL', tone: V21ButtonTone.green, fontSize: 20, busy: _busy, onTap: _claim),
    );
  }
}

/// Dört sandık yuvası (ana sayfa ve mağaza)
class _ChestSlots extends StatelessWidget {
  final ChestsViewModel? vm;
  const _ChestSlots({required this.vm});

  static Color accent(String t) => switch (t) {
    ChestTypes.legend => const Color(0xFFD48CF5),
    ChestTypes.gold => const Color(0xFFFFC832),
    ChestTypes.silver => const Color(0xFFE8EEF6),
    _ => const Color(0xFFFFAB76),
  };

  @override
  Widget build(BuildContext context) {
    final env = vm?.inventory;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      child: Row(
        children: [
          for (var n = 1; n <= 4; n++) ...[
            if (n > 1) const SizedBox(width: 10),
            Expanded(child: _slot(context, env?.slot(n))),
          ],
        ],
      ),
    );
  }

  Widget _slot(BuildContext context, Chest? c) {
    final v = vm;
    final footer = c == null
        ? ''
        : c.isUnlocking
        ? V21Format.countdown(v?.remaining(c) ?? Duration.zero)
        : (c.isReady ? 'AÇ!' : V21Format.shortDuration(c.unlockSeconds));
    final color = c == null ? const Color(0xFF6B58A8) : (c.isUnlocking ? const Color(0xFF3DD15A) : accent(c.chestType));
    return V21Tap(
      onTap: () => context.go(AppRoutes.chests),
      child: Column(
        children: [
          SizedBox(
            height: 24,
            child: FittedBox(
              child: Text(
                c == null ? ' ' : (c.isUnlocking ? 'AÇILIYOR' : V21Format.upper(c.typeName)),
                style: wBody(18, weight: FontWeight.w900),
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2B1868),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color, width: 3),
              ),
              child: c == null
                  ? const Center(child: Icon(Icons.add_rounded, size: 44, color: Color(0xFF7D69BC)))
                  : Column(
                      children: [
                        Expanded(child: Padding(padding: const EdgeInsets.all(4), child: wImage('chest_slot', fit: BoxFit.contain))),
                        FittedBox(child: Text(footer, style: wTitle(25))),
                        const SizedBox(height: 4),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeckStrip extends StatelessWidget {
  const _DeckStrip();

  @override
  Widget build(BuildContext context) {
    if (!getIt.isRegistered<DeckViewModel>()) return const SizedBox.shrink();
    return ChangeNotifierProvider<DeckViewModel>(
      create: (_) => getIt<DeckViewModel>()..load(),
      child: Builder(
        builder: (context) {
          final cards = [...context.watch<DeckViewModel>().selectedCards]..sort((a, b) => b.power.compareTo(a.power));
          return WebDeckRow(cards: cards.take(5).toList(), label: 'KADROM', onTap: () => context.go(AppRoutes.deck));
        },
      ),
    );
  }
}

/// Kadronun en güçlü beş kartı
class WebDeckRow extends StatelessWidget {
  final List<InventoryCard> cards;
  final String label;
  final String? sub;
  final VoidCallback onTap;
  const WebDeckRow({super.key, required this.cards, required this.label, required this.onTap, this.sub});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: wPanelBorder, width: 2),
      gradient: const LinearGradient(colors: [wPanelTop, wPanelBottom], begin: Alignment.topCenter, end: Alignment.bottomCenter),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 98,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 62, height: 54, child: Image(image: AssetImage('assets/v21/web/nav_cards.webp'))),
              FittedBox(child: Text(label, style: wTitle(30))),
              if (sub != null) FittedBox(child: Text(sub!, style: wBody(21))),
            ],
          ),
        ),
        const SizedBox(width: 10),
        for (var i = 0; i < 5; i++) ...[
          if (i > 0) const SizedBox(width: 18),
          Expanded(
            child: i < cards.length ? WCard.of(cards[i], onTap: onTap) : const WHiddenCard(),
          ),
        ],
      ],
    ),
  );
}

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
        wBox(258, 100, 1010, 165, Text('KARTLARIM / KOLEKSİYON', maxLines: 1, style: wTitle(56))),
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
          WButton('TÜMÜ', fontSize: 25, onTap: vm.clearCategoryFilters),
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
              title: 'KART BİLGİSİ',
              headerHeight: 46,
              titleSize: 27,
              icon: const Icon(Icons.fact_check_rounded, color: Colors.white, size: 34),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Column(
                  children: [
                    info('Pozisyon', Text(card.position.code, style: wTitle(23))),
                    info('Nadirlik', Text(V21Format.upper(V21Rarity.of(card.tier).name), style: wTitle(23, color: wTierColor(card.tier)))),
                    info('Takım', Text(V21Format.upper(card.club ?? '-'), maxLines: 1, style: wTitle(23, color: wTierColor(card.tier)))),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: WPanel(
              title: 'ÖZELLİKLER',
              headerHeight: 46,
              titleSize: 27,
              icon: const Icon(Icons.upgrade_rounded, color: Colors.white, size: 36),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                child: Column(
                  children: [
                    stat(Icons.sports_soccer_rounded, 'Şut', a?.shooting ?? card.power),
                    stat(Icons.directions_run_rounded, 'Hız', a?.pace ?? card.power),
                    stat(Icons.shield_rounded, 'Fizik', a?.physical ?? card.power),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 84,
            child: WButton('GELİŞTİR', fontSize: 40, onTap: () => context.push(AppRoutes.progress)),
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// KADROM
// ====================================================================
class WebDeck extends StatefulWidget {
  final DeckViewModel vm;
  final ValueChanged<int> onPick;
  final VoidCallback onSave;
  final void Function(int from, int to) onDrop;
  const WebDeck({super.key, required this.vm, required this.onPick, required this.onSave, required this.onDrop});

  @override
  State<WebDeck> createState() => _WebDeckState();
}

class _WebDeckState extends State<WebDeck> {
  int _slot = 9;

  static const _centers = <int, Offset>{
    9: Offset(593, 280), 10: Offset(808, 280),
    5: Offset(405, 466), 6: Offset(604, 466), 7: Offset(802, 466), 8: Offset(1000, 466),
    1: Offset(408, 657), 2: Offset(606, 657), 3: Offset(802, 657), 4: Offset(1000, 657),
    0: Offset(697, 825),
  };

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final sel = vm.cardAt(_slot);
    return WebShell(
      route: AppRoutes.deck,
      children: [
        wBox(296, 100, 900, 168, Text('KADROM', style: wTitle(58))),
        wBox(
          935,
          114,
          1106,
          166,
          Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFF1C0D4C), borderRadius: BorderRadius.circular(26)),
            child: Text('${vm.averagePower} GÜÇ', style: wTitle(32)),
          ),
        ),
        wBox(
          278,
          182,
          1110,
          914,
          Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF1B0E3A), width: 4)),
            clipBehavior: Clip.antiAlias,
            child: const CustomPaint(painter: _PitchPainter()),
          ),
        ),
        for (final e in _centers.entries)
          wBox(
            e.value.dx - 66,
            e.value.dy - 86,
            e.value.dx + 66,
            e.value.dy + 86,
            _slotTile(e.key),
          ),
        wBox(
          1130,
          118,
          1656,
          502,
          WPanel(
            title: 'KART DETAYI',
            titleSize: 35,
            icon: wImage('nav_cards', fit: BoxFit.contain),
            child: sel == null
                ? Center(child: WButton('KART SEÇ', onTap: () => widget.onPick(_slot)))
                : Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        SizedBox(width: 188, child: WCard.of(sel, onTap: () => widget.onPick(_slot))),
                        const SizedBox(width: 18),
                        Expanded(child: _DeckCardInfo(card: sel, onChange: () => widget.onPick(_slot))),
                      ],
                    ),
                  ),
          ),
        ),
        wBox(
          1130,
          520,
          1656,
          798,
          WPanel(
            title: 'KADRO BİLGİSİ',
            titleSize: 35,
            icon: const Icon(Icons.assignment_rounded, color: Colors.white, size: 40),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _orb('${vm.averagePower}', 'GÜÇ', const Color(0xFFFF5A7A)),
                        _orb('${vm.chemistry.total}', 'KİMYA', const Color(0xFF3DD15A)),
                        _orb('${vm.totalSelected}/${GameRules.squadSize}', 'KADRO', const Color(0xFF4FA8F5)),
                      ],
                    ),
                  ),
                  if (!vm.isComplete)
                    EmergencySquadBanner(onClaimed: vm.load)
                  else
                    Container(
                      height: 46,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(color: wInset, borderRadius: BorderRadius.circular(12)),
                      child: Text(
                        vm.saveMessage ?? 'Aynı kulüp / lig / uyruk = daha çok kimya',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: wBody(21),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        wBox(1136, 815, 1398, 898, WButton('OTOMATİK DİZ', tone: V21ButtonTone.green, fontSize: 31, icon: Icons.shuffle_rounded, onTap: vm.autoFillBest)),
        wBox(
          1414,
          815,
          1656,
          898,
          WButton(
            'KAYDET',
            fontSize: 31,
            icon: Icons.check_rounded,
            busy: vm.isSaving,
            onTap: vm.hasUnsavedChanges || !vm.isComplete || vm.duplicateMessage != null ? widget.onSave : null,
          ),
        ),
      ],
    );
  }

  Widget _orb(String v, String l, Color c) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 92,
        height: 92,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [Color.lerp(c, Colors.white, 0.3)!, c]),
        ),
        child: FittedBox(child: Padding(padding: const EdgeInsets.all(8), child: Text(v, style: wTitle(42)))),
      ),
      const SizedBox(height: 8),
      Text(l, style: wBody(21, weight: FontWeight.w800)),
    ],
  );

  Widget _slotTile(int slot) {
    final c = vm0(slot);
    final tile = c == null
        ? V21Tap(
            onTap: () => widget.onPick(slot),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0x66241446),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white70, width: 3),
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 54),
            ),
          )
        : WCard.of(
            c,
            selected: slot == _slot,
            onTap: () {
              if (slot == _slot) {
                widget.onPick(slot);
              } else {
                setState(() => _slot = slot);
              }
            },
          );
    return DragTarget<int>(
      onWillAcceptWithDetails: (d) => V21SquadPitch.accepts(d.data, slot),
      onAcceptWithDetails: (d) => widget.onDrop(d.data, slot),
      builder: (context, _, _) => c == null
          ? tile
          : Draggable<int>(
              data: slot,
              feedback: Material(color: Colors.transparent, child: SizedBox(width: 132, height: 172, child: WCard.of(c))),
              childWhenDragging: Opacity(opacity: 0.3, child: tile),
              child: tile,
            ),
    );
  }

  InventoryCard? vm0(int s) => widget.vm.cardAt(s);
}

class _DeckCardInfo extends StatelessWidget {
  final InventoryCard card;
  final VoidCallback onChange;
  const _DeckCardInfo({required this.card, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final a = card.attributes;
    Widget row(IconData i, String l, int v) => Expanded(
      child: Row(
        children: [
          Icon(i, color: Colors.white, size: 26),
          const SizedBox(width: 8),
          SizedBox(width: 74, child: Text(l, maxLines: 1, style: wBody(19))),
          Expanded(child: WBar(value: v / 100, height: 13)),
          SizedBox(width: 50, child: Text('$v', textAlign: TextAlign.right, style: wTitle(25))),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(card.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: wTitle(31))),
            V21Tap(onTap: onChange, child: const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 32)),
          ],
        ),
        const SizedBox(height: 6),
        Text('${card.position.code}  ${card.position.label}', style: wBody(20)),
        const SizedBox(height: 4),
        WTierLabel(tier: card.tier, size: 19),
        const SizedBox(height: 8),
        row(Icons.fitness_center_rounded, 'Güç', card.power),
        row(Icons.directions_run_rounded, 'Hız', a?.pace ?? card.power),
        row(Icons.sports_soccer_rounded, 'Şut', a?.shooting ?? card.power),
        row(Icons.shield_outlined, 'Defans', a?.defending ?? card.power),
      ],
    );
  }
}

class _PitchPainter extends CustomPainter {
  const _PitchPainter();

  @override
  void paint(Canvas c, Size s) {
    for (var i = 0; i < 14; i++) {
      c.drawRect(
        Rect.fromLTWH(0, s.height * i / 14, s.width, s.height / 14 + 1),
        Paint()..color = i.isEven ? const Color(0xFF3FC24B) : const Color(0xFF36B342),
      );
    }
    final p = Paint()
      ..color = const Color(0xCCE9FFE6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    final my = s.height * 0.445;
    c.drawLine(Offset(0, my), Offset(s.width, my), p);
    c.drawCircle(Offset(s.width / 2, my), 94, p);
    c.drawRect(Rect.fromCenter(center: Offset(s.width / 2, s.height - 58), width: 356, height: 116), p);
  }

  @override
  bool shouldRepaint(_PitchPainter old) => false;
}

// ====================================================================
// SANDIKLAR
// ====================================================================
class WebChests extends StatefulWidget {
  final ChestsViewModel vm;
  final ChestInventory env;

  /// Yuvadaki sandığın eylemi (aç, sayaç başlat, seçenekler); yoksa null
  final VoidCallback? Function(Chest c) actionOf;
  final void Function(Chest c) onOpen;
  const WebChests({super.key, required this.vm, required this.env, required this.actionOf, required this.onOpen});

  @override
  State<WebChests> createState() => _WebChestsState();
}

class _WebChestsState extends State<WebChests> {
  String? _id;

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final env = widget.env;
    final e = env.energy;
    final sel = env.slots.where((c) => c.id == _id).firstOrNull ?? env.slots.firstOrNull;
    final loose = [...env.instant, ...env.mailbox];
    return WebShell(
      route: AppRoutes.chests,
      extra: WebExtraNav.chests,
      children: [
        wBox(292, 118, 368, 190, wImage('chest_small', fit: BoxFit.contain)),
        wBox(392, 116, 1100, 190, Text('SANDIKLAR', style: wTitle(60))),
        wBox(
          288,
          212,
          1112,
          320,
          Container(
            padding: const EdgeInsets.fromLTRB(30, 12, 30, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(colors: [Color(0xFFFF9A2E), Color(0xFFE5394B)]),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('SANDIK HAKKI', style: wTitle(32)),
                          const SizedBox(width: 36),
                          for (var i = 0; i < e.max; i++)
                            Container(
                              width: 39,
                              height: 30,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: i < e.energy ? const Color(0xFFFFD45A) : const Color(0xFF6A1F3A),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF3A1230), width: 3),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Her ${e.refillMinutes} dk\'da 1 hak yenilenir', style: wBody(23, color: const Color(0xFFFFE6DC))),
                    ],
                  ),
                ),
                Text('${e.energy}/${e.max}', style: wTitle(58)),
              ],
            ),
          ),
        ),
        wBox(297, 335, 700, 392, Text('YUVALAR', style: wTitle(44))),
        wBox(800, 345, 1100, 385, Align(alignment: Alignment.centerRight, child: Text('Aynı anda 1 sandık açılır', style: wBody(24, color: const Color(0xFFB9A4F0))))),
        wBox(
          284,
          396,
          1116,
          702,
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFF2A1567), borderRadius: BorderRadius.circular(20)),
            child: Row(
              children: [
                for (var n = 1; n <= 4; n++) ...[
                  if (n > 1) const SizedBox(width: 12),
                  Expanded(child: _slot(env.slot(n), sel)),
                ],
              ],
            ),
          ),
        ),
        wBox(
          290,
          738,
          1110,
          900,
          loose.isEmpty
              ? WPanel(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Yuvalar doluyken kazandığın sandıklar burada ${env.mailboxDays} gün bekler.',
                        textAlign: TextAlign.center,
                        style: wBody(24, color: const Color(0xFFD9CCF7)),
                      ),
                    ),
                  ),
                )
              : _looseChest(loose.first, env),
        ),
        wBox(
          1136,
          128,
          1656,
          910,
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF8A5BE8), width: 3),
              gradient: const LinearGradient(colors: [wPanelTop, wPanelBottom], begin: Alignment.topCenter, end: Alignment.bottomCenter),
            ),
            clipBehavior: Clip.antiAlias,
            child: _detail(sel, vm),
          ),
        ),
      ],
    );
  }

  Widget _looseChest(Chest c, ChestInventory env) {
    final mailbox = c.isInMailbox;
    return WPanel(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Row(
          children: [
            SizedBox(width: 150, child: wImage('chest_bronze', fit: BoxFit.contain)),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${V21Format.upper(c.typeName)} SANDIK', style: wTitle(38, color: const Color(0xFFFFC77A))),
                  const SizedBox(height: 6),
                  Text(mailbox ? 'Posta kutusunda' : 'Maç ödülü · hazır', style: wBody(26)),
                ],
              ),
            ),
            SizedBox(
              width: 210,
              height: 84,
              child: WButton(
                mailbox ? 'TAŞI' : 'AÇ!',
                tone: V21ButtonTone.green,
                fontSize: 42,
                busy: widget.vm.busyChestId == c.id,
                onTap: mailbox ? (env.hasFreeSlot ? () => widget.vm.claimMailbox(c) : null) : () => widget.onOpen(c),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slot(Chest? c, Chest? sel) {
    if (c == null) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF6B58A8), width: 3),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_rounded, color: Color(0xFF7D69BC), size: 70),
            Text('BOŞ YUVA', style: wBody(24, color: const Color(0xFF8E7FBE))),
          ],
        ),
      );
    }
    final on = c.id == sel?.id;
    final vm = widget.vm;
    return V21Tap(
      onTap: () => setState(() => _id = c.id),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF3A2088),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: on ? const Color(0xFF6BF07A) : const Color(0xFF55399F), width: 4),
        ),
        child: Column(
          children: [
            Expanded(child: Padding(padding: const EdgeInsets.all(10), child: wImage('chest_slot', fit: BoxFit.contain))),
            FittedBox(child: Text('${V21Format.upper(c.typeName)} SANDIK', style: wTitle(28, color: const Color(0xFFFFD98A)))),
            const SizedBox(height: 8),
            Container(
              height: 46,
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.isUnlocking || c.isReady ? const Color(0xFF16A838) : const Color(0xFF241446),
                borderRadius: BorderRadius.circular(22),
              ),
              child: FittedBox(
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (c.isUnlocking) const Icon(Icons.timer_rounded, color: Colors.white, size: 28),
                      if (c.isSealed) const Icon(Icons.lock_rounded, color: V21Colors.goldTop, size: 28),
                      const SizedBox(width: 6),
                      Text(
                        c.isReady ? 'AÇ!' : (c.isUnlocking ? V21Format.countdown(vm.remaining(c) ?? Duration.zero) : V21Format.shortDuration(c.unlockSeconds)),
                        style: wTitle(28),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detail(Chest? c, ChestsViewModel vm) {
    final action = c == null ? null : widget.actionOf(c);
    final label = c == null
        ? 'SANDIK YOK'
        : c.isReady
        ? 'AÇ!'
        : c.isUnlocking
        ? '${V21Format.countdown(vm.remaining(c) ?? Duration.zero)} SONRA AÇILACAK'
        : 'SAYACI BAŞLAT';
    Widget reward(String asset, String l) => Expanded(
      child: Column(
        children: [
          Expanded(child: wImage(asset, fit: BoxFit.contain)),
          const SizedBox(height: 4),
          FittedBox(child: Text(l, style: wBody(20))),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 258, child: wImage('chest_hero', fit: BoxFit.cover)),
        const SizedBox(height: 8),
        FittedBox(fit: BoxFit.scaleDown, child: Text(c == null ? 'SANDIK' : '${V21Format.upper(c.typeName)} SANDIK', style: wTitle(50))),
        const SizedBox(height: 6),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFD9CCF7), borderRadius: BorderRadius.circular(18)),
            child: Text(
              c == null ? 'BOŞ' : (c.isUnlocking ? 'AÇILIYOR' : (c.isReady ? 'HAZIR' : 'SIRADA')),
              style: V21Type.title(25, color: const Color(0xFF2A1567)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: Text('İçinden oyuncu kartları, altın ve çeşitli ödüller çıkar.', textAlign: TextAlign.center, style: wBody(23)),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: WPanel(
              title: 'OLASI ÖDÜLLER',
              headerHeight: 46,
              titleSize: 27,
              icon: const Icon(Icons.card_giftcard_rounded, color: V21Colors.goldTop, size: 34),
              trailing: V21Tap(
                onTap: () => context.push(AppRoutes.chestOdds),
                child: Text('Oranlar ›', style: wBody(19, color: const Color(0xFFD9CCF7))),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    reward('reward_cards', 'Oyuncu Kartları'),
                    reward('reward_coins', 'Altın'),
                    reward('reward_xp', 'Gelişim'),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(26, 14, 26, 22),
          child: SizedBox(
            height: 86,
            child: WButton(
              label,
              tone: V21ButtonTone.green,
              fontSize: 38,
              icon: c != null && c.isUnlocking ? Icons.timer_rounded : null,
              busy: c != null && vm.busyChestId == c.id,
              onTap: action,
            ),
          ),
        ),
      ],
    );
  }
}

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
              child: const V21CardBack(width: 104, semanticsLabel: 'Kart paketi'),
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
        wBox(296, 100, 900, 170, Text('MAĞAZA', style: wTitle(60))),
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
              Text(offer?.name ?? 'Teklif yok', maxLines: 1, style: wTitle(52)),
              Text(offer == null ? 'Yeni teklif yakında' : '${offer.cardCount} kart · %${offer.discountPct} indirim', style: wBody(25, color: const Color(0xFFFFE6DC))),
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
              offer.boughtToday ? 'ALINDI' : V21Format.thousands(offer.discountedPrice),
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
                      title: 'SANDIKLAR',
                      icon: wImage('chest_small', fit: BoxFit.contain),
                      child: _ChestSlots(vm: context.watch<ChestsViewModel>()),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        wBox(292, 436, 1000, 498, Text('KART PAKETLERİ', style: wTitle(46))),
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
                Text('ÇIKMA İHTİMALİ', style: wBody(22, color: const Color(0xFFD9CCF7), weight: FontWeight.w800)),
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
            label: 'Paketler, seçili sekme',
            excludeSemantics: true,
            child: IgnorePointer(child: WButton('PAKETLER', fontSize: 38, onTap: () {})),
          ),
        ),
        wBox(796, 840, 1126, 924, WButton('TEKLİFLER', tone: V21ButtonTone.blue, fontSize: 38, onTap: () => context.push(AppRoutes.sbc))),
        wBox(1158, 840, 1488, 924, WButton('KOZMETİK', tone: V21ButtonTone.blue, fontSize: 38, onTap: () => context.push(AppRoutes.inventory))),
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
                FittedBox(fit: BoxFit.scaleDown, child: Text(V21Format.upper(p.name.replaceAll(' Paketi', '').replaceAll(' Paket', '')), maxLines: 1, style: wTitle(32))),
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
              child: Text('${V21Format.thousands(missing)} altın eksik', style: wBody(18, color: const Color(0xFFFF9BC0))),
            ),
        ],
      ),
    );
  }
}

// ====================================================================
// GELİŞİM
// ====================================================================
class WebProgress extends StatefulWidget {
  final ProgressViewModel vm;
  final ProgressOverview overview;
  const WebProgress({super.key, required this.vm, required this.overview});

  @override
  State<WebProgress> createState() => _WebProgressState();
}

class _WebProgressState extends State<WebProgress> {
  String? _id;
  CardPosition? _role;
  bool _asc = false;

  static const _tiers = ['bronze', 'silver', 'gold', 'diamond', 'legend'];
  static const _colors = {
    'bronze': Color(0xFFFFAB76),
    'silver': Color(0xFFE8EEF6),
    'gold': Color(0xFFFFE07A),
    'diamond': Color(0xFF7FF3FF),
    'legend': Color(0xFFE3A9FA),
  };

  /// Seviye gücü eğrisi (040)
  static int _bonus(int level) => level >= 10 ? 3 : (level >= 7 ? 2 : (level >= 4 ? 1 : 0));

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final o = widget.overview;
    final all = vm.visibleItems.where((i) => _role == null || i.position == _role).toList()
      ..sort((a, b) => _asc ? a.level.compareTo(b.level) : b.level.compareTo(a.level));
    final sel = all.where((i) => i.cardId == _id).firstOrNull ?? all.firstOrNull;
    return WebShell(
      route: AppRoutes.progress,
      extra: WebExtraNav.progress,
      children: [
        wBox(292, 100, 350, 160, const Icon(Icons.keyboard_double_arrow_up_rounded, color: Color(0xFFFFC94F), size: 62)),
        wBox(370, 96, 900, 166, Text('GELİŞİM', style: wTitle(58))),
        wBox(262, 180, 930, 484, _main(sel, o, vm)),
        wBox(
          945,
          182,
          1256,
          466,
          WPanel(
            title: 'JOKER PARÇALAR',
            titleSize: 31,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Container(
                decoration: BoxDecoration(color: wInset, borderRadius: BorderRadius.circular(14)),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  runAlignment: WrapAlignment.center,
                  spacing: 18,
                  runSpacing: 22,
                  children: [
                    for (final t in _tiers)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          V21HexIcon(color: _colors[t]!, size: 56),
                          const SizedBox(width: 8),
                          Text('${o.jokers[t] ?? 0}', style: wTitle(36)),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        wBox(1270, 180, 1654, 466, _after(sel)),
        wBox(
          262,
          498,
          1654,
          928,
          WPanel(
            title: 'GELİŞİM MATERYALLERİ',
            icon: wImage('nav_cards', fit: BoxFit.contain),
            headerHeight: 64,
            trailing: Row(
              children: [
                _menu<bool>(vm.onlyReady ? 'Atlayabilir' : 'Tümü', const {'Tümü': false, 'Atlayabilir': true}, vm.setOnlyReady),
                const SizedBox(width: 18),
                _menu<CardPosition?>(
                  'Rol: ${_role?.code ?? 'Tümü'}',
                  <String, CardPosition?>{'Tümü': null, for (final p in CardPosition.values) p.code: p},
                  (v) => setState(() => _role = v),
                ),
                const SizedBox(width: 18),
                _menu<bool>(
                  'Sıralama: Seviye (${_asc ? 'Artan' : 'Azalan'})',
                  const {'Azalan': false, 'Artan': true},
                  (v) => setState(() => _asc = v),
                ),
              ],
            ),
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(52, 12, 18, 14),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                crossAxisSpacing: 26,
                mainAxisSpacing: 18,
                childAspectRatio: 142 / 160,
              ),
              itemCount: all.length,
              itemBuilder: (context, i) {
                final it = all[i];
                return WCard(
                  name: it.fullName,
                  tier: it.tier,
                  power: it.power,
                  position: it.position.code,
                  selected: it.cardId == sel?.cardId,
                  onTap: () => setState(() => _id = it.cardId),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _menu<T>(String label, Map<String, T> options, ValueChanged<T> onPick) => PopupMenuButton<T>(
    onSelected: onPick,
    itemBuilder: (_) => [for (final e in options.entries) PopupMenuItem<T>(value: e.value, child: Text(e.key))],
    child: Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1567),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF7B60C8), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: wBody(20)),
          const SizedBox(width: 12),
          const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
        ],
      ),
    ),
  );

  Widget _main(PlayerProgressItem? i, ProgressOverview o, ProgressViewModel vm) {
    if (i == null) {
      return WPanel(child: Center(child: Text('Şu an gelişecek futbolcu yok.', style: wBody(26))));
    }
    final next = i.next;
    final ready = i.canLevelUp(o.coins);
    final joker = i.canLevelWithJokers(o.coins) && i.copies > 0;
    final need = next?.copies ?? 0;
    return WPanel(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 8, 12, 8),
        child: Row(
          children: [
            SizedBox(
              width: 226,
              child: WCard(name: i.fullName, tier: i.tier, power: i.power, position: i.position.code),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text('SEVİYE ${i.level}', style: wTitle(58)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (var n = 1; n <= o.maxLevel; n++)
                        Expanded(
                          child: Container(
                            height: 30,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: n <= i.level ? const Color(0xFF4BE05A) : const Color(0xFF241446),
                              border: Border.all(color: const Color(0xFF1B0E3A), width: 3),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text('Kopya', style: wBody(27)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: WBar(
                          value: need == 0 ? 1 : i.copies / need,
                          height: 26,
                          colors: const [Color(0xFF56C7FF), Color(0xFF7DE4FF)],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(i.isMax ? 'MAKS' : '${i.copies}/$need', style: wBody(27)),
                    ],
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 104,
                    child: WButton(
                      i.isMax ? 'EN YÜKSEK SEVİYE' : (ready || !joker ? 'SEVİYE ATLA' : 'JOKERLE ATLA'),
                      tone: ready || i.isMax ? V21ButtonTone.green : V21ButtonTone.blue,
                      fontSize: 54,
                      busy: vm.busyCardId == i.cardId,
                      semantics: next == null ? null : 'Seviye atla, ${next.coins} altın',
                      onTap: ready ? () => vm.levelUp(i) : (joker ? () => vm.levelUp(i, useJokers: true) : null),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _after(PlayerProgressItem? i) {
    final next = i?.next;
    Widget row(IconData? ic, String l, String a, String b) => Expanded(
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: wInset, borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            if (ic != null) ...[Icon(ic, color: const Color(0xFFD9CCF7), size: 26), const SizedBox(width: 10)],
            Expanded(child: Text(l, maxLines: 1, style: wBody(23))),
            Text(a, style: wTitle(27)),
            const SizedBox(width: 18),
            Text('>', style: wBody(24, color: const Color(0xFFB9A4F0))),
            const SizedBox(width: 18),
            SizedBox(width: 62, child: Text(b, textAlign: TextAlign.right, maxLines: 1, style: wTitle(29, color: const Color(0xFF6BF07A)))),
          ],
        ),
      ),
    );
    return WPanel(
      title: 'YÜKSELTME SONRASI',
      titleSize: 29,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: i == null || next == null
            ? Center(child: Text('En yüksek seviye', style: wBody(24)))
            : Column(
                children: [
                  row(null, 'Seviye', '${i.level}', '${i.level + 1}'),
                  row(null, 'Genel Reyting', '${i.power + _bonus(i.level)}', '${i.power + _bonus(i.level + 1)}'),
                  row(Icons.style_rounded, 'Gereken Kopya', '${i.copies}', '${next.copies}'),
                  row(Icons.monetization_on_rounded, 'Altın Bedeli', '-', V21Format.thousands(next.coins)),
                ],
              ),
      ),
    );
  }
}

// ====================================================================
// MAÇA HAZIRLAN
// ====================================================================
class WebReady extends StatelessWidget {
  final MatchmakingViewModel vm;
  final VoidCallback onFind;

  /// Arama sürerken ortada gösterilen panel
  final Widget? search;
  const WebReady({super.key, required this.vm, required this.onFind, this.search});

  @override
  Widget build(BuildContext context) {
    final v = vm.validation;
    final valid = v?.isValid ?? false;
    final cards = [...vm.deckCards]..sort((a, b) => b.power.compareTo(a.power));
    Widget check(bool ok, String t) => Expanded(
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded, color: ok ? const Color(0xFF3DD15A) : const Color(0xFFFF6B7D), size: 34),
          const SizedBox(width: 12),
          Expanded(child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: wBody(23))),
        ],
      ),
    );
    Widget rule(IconData i, Color c, String t) => Expanded(
      child: Row(
        children: [
          Icon(i, color: c, size: 40),
          const SizedBox(width: 18),
          Expanded(child: Text(t, maxLines: 2, style: wBody(23))),
        ],
      ),
    );
    return WebShell(
      route: AppRoutes.home,
      children: [
        wBox(268, 100, 1168, 941, wImage('ready_bg', fit: BoxFit.fill)),
        if (search != null)
          wBox(
            380,
            300,
            1056,
            920,
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: const Color(0xEE241066), borderRadius: BorderRadius.circular(24), border: Border.all(color: wPanelBorder, width: 3)),
              child: SingleChildScrollView(child: search),
            ),
          )
        else ...[
          wBox(
            310,
            466,
            1132,
            652,
            WebDeckRow(
              cards: cards.take(5).toList(),
              label: 'KADROM',
              sub: '(${vm.deckCards.length} KART)',
              onTap: () => context.go(AppRoutes.deck),
            ),
          ),
          wBox(378, 672, 1070, 806, WButton('RAKİP BUL', fontSize: 72, icon: Icons.sports_mma_rounded, onTap: vm.selectedDeck == null ? null : onFind)),
          wBox(318, 826, 722, 914, WButton('ARKADAŞINLA OYNA', tone: V21ButtonTone.blue, fontSize: 36, icon: Icons.group_rounded, onTap: () => context.push(AppRoutes.friends))),
          wBox(
            746,
            826,
            1146,
            914,
            WButton(
              'BOTLA ANTRENMAN',
              tone: V21ButtonTone.green,
              fontSize: 36,
              icon: Icons.smart_toy_rounded,
              onTap: vm.trainingEnabled && vm.canSearch ? vm.startTraining : null,
            ),
          ),
        ],
        wBox(
          1180,
          142,
          1656,
          416,
          WPanel(
            title: 'KADRO DURUMU',
            icon: Icon(valid ? Icons.check_circle_rounded : Icons.error_rounded, color: valid ? const Color(0xFF3DD15A) : const Color(0xFFFF6B7D), size: 44),
            titleSize: 34,
            headerHeight: 66,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 8, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        check(vm.deckCards.length >= GameRules.squadSize, '${vm.deckCards.length}/${GameRules.squadSize} kart seçildi'),
                        check(vm.selectedDeck != null, 'Aktif kadro seçili'),
                        check(valid, valid ? 'Kadron geçerli' : (v?.displayMessage ?? 'Kadro kontrol ediliyor')),
                      ],
                    ),
                  ),
                  SizedBox(width: 190, child: wImage('deck_ok', fit: BoxFit.contain)),
                ],
              ),
            ),
          ),
        ),
        wBox(
          1180,
          442,
          1656,
          806,
          WPanel(
            title: 'DERECELİ MAÇ KURALLARI',
            icon: const Icon(Icons.emoji_events_rounded, color: V21Colors.goldTop, size: 46),
            titleSize: 34,
            headerHeight: 70,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(26, 8, 18, 10),
              child: Column(
                children: [
                  rule(Icons.emoji_events_rounded, V21Colors.goldTop, 'Rakipler benzer lig seviyesinden eşleşir.'),
                  rule(Icons.style_rounded, const Color(0xFFC9B6F5), '${GameRules.squadSize} kartlık kadronla oynarsın.'),
                  rule(Icons.bolt_rounded, V21Colors.goldTop, 'Her dereceli maç 1 sandık hakkı harcar.'),
                  rule(Icons.star_rounded, V21Colors.goldTop, 'Kazandıkça lig puanı kazanır, üst lige yükselirsin.'),
                ],
              ),
            ),
          ),
        ),
        if (vm.tutorial?.shouldOffer ?? false)
          wBox(1180, 826, 1656, 914, WButton('ÖĞRETİCİYİ BAŞLAT', tone: V21ButtonTone.purple, fontSize: 34, onTap: vm.startTutorial)),
      ],
    );
  }
}

// ====================================================================
// ARKADAŞLAR / ÖZEL ODA
// ====================================================================
class WebFriends extends StatelessWidget {
  final String? code;
  final Map<String, dynamic>? room;
  final String? error;
  final bool busy;
  final TextEditingController codeController;
  final VoidCallback onCreate;
  final VoidCallback onJoin;
  final VoidCallback onReady;
  final VoidCallback onLeave;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  const WebFriends({
    super.key,
    required this.code,
    required this.room,
    required this.error,
    required this.busy,
    required this.codeController,
    required this.onCreate,
    required this.onJoin,
    required this.onReady,
    required this.onLeave,
    required this.onCopy,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final me = wWatch<SessionManager>(context)?.user?.username ?? '';
    final r = room;
    final isHost = r == null || r['is_host'] == true;
    final host = r?['host_name']?.toString() ?? (code == null ? me : 'Bağlanıyor...');
    final guest = r?['guest_name']?.toString();
    final myReady = r != null && (isHost ? r['host_ready'] == true : r['guest_ready'] == true);
    final waiting = r?['status'] == 'waiting';
    return WebShell(
      route: AppRoutes.home,
      children: [
        wBox(265, 92, 1672, 941, wImage('friends_bg', fit: BoxFit.fill)),
        wBox(
          592,
          116,
          1310,
          200,
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFD9C8FF), width: 3),
              gradient: const LinearGradient(colors: [Color(0xFF5A32BE), Color(0xFF341A86)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                children: [
                  const Icon(Icons.groups_rounded, color: Color(0xFFD9CCF7), size: 66),
                  const SizedBox(width: 20),
                  Text('ARKADAŞLAR / ', style: wTitle(52)),
                  Text('ÖZEL ODA', style: wTitle(52, color: V21Colors.goldTop)),
                ],
              ),
            ),
          ),
        ),
        wBox(
          680,
          212,
          1222,
          268,
          Container(
            decoration: BoxDecoration(color: const Color(0xFF2A1567), borderRadius: BorderRadius.circular(28), border: Border.all(color: wPanelBorder, width: 2)),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                children: [
                  SizedBox(width: 72, height: 50, child: wImage('no_reward', fit: BoxFit.contain)),
                  const SizedBox(width: 12),
                  Text('ÖDÜLSÜZ  •  KART KAYBI YOK', style: wTitle(35, color: V21Colors.goldTop)),
                ],
              ),
            ),
          ),
        ),
        wBox(472, 298, 854, 668, _player('ODA SAHİBİ', Icons.workspace_premium_rounded, host, 'oda-$host', const Color(0xFFFFC832), r?['host_ready'] == true, isHost)),
        wBox(1048, 298, 1430, 668, _player('DAVETLİ', Icons.groups_rounded, guest ?? 'Bekleniyor...', guest == null ? null : 'oda-$guest', const Color(0xFF4FA8F5), r?['guest_ready'] == true, !isHost)),
        wBox(890, 470, 1020, 570, Center(child: Text('VS', style: wTitle(92, color: V21Colors.goldTop)))),
        wBox(
          380,
          688,
          1538,
          808,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xF0341A86), borderRadius: BorderRadius.circular(18), border: Border.all(color: wPanelBorder, width: 2)),
            child: Row(
              children: [
                SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('DAVET KODU', style: wBody(23, color: const Color(0xFFD9CCF7))),
                      const SizedBox(height: 4),
                      Container(
                        height: 54,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: const Color(0xFF1C0D4C), borderRadius: BorderRadius.circular(14)),
                        child: code != null
                            ? FittedBox(fit: BoxFit.scaleDown, child: SelectableText(code!, style: wTitle(30)))
                            : TextField(
                                controller: codeController,
                                style: wBody(22),
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(hintText: 'Kodu buraya yaz', border: InputBorder.none, isDense: true),
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(
                  child: code == null
                      ? WButton('DAVET OLUŞTUR', fontSize: 32, icon: Icons.add_link_rounded, onTap: busy ? null : onCreate)
                      : WButton('DAVET KODUNU KOPYALA', fontSize: 30, icon: Icons.copy_rounded, onTap: onCopy),
                ),
                const SizedBox(width: 30),
                Expanded(
                  child: code == null
                      ? WButton('ODA KODUYLA KATIL', tone: V21ButtonTone.blue, fontSize: 30, icon: Icons.login_rounded, onTap: busy ? null : onJoin)
                      : WButton('LİNKİ PAYLAŞ', tone: V21ButtonTone.blue, fontSize: 34, icon: Icons.share_rounded, onTap: onShare),
                ),
              ],
            ),
          ),
        ),
        wBox(310, 832, 662, 916, WButton('KADROMU SEÇ', tone: V21ButtonTone.purple, fontSize: 36, icon: Icons.style_rounded, onTap: () => context.push(AppRoutes.deck))),
        wBox(
          708,
          826,
          1212,
          920,
          WButton(
            myReady ? 'RAKİP BEKLENİYOR' : 'HAZIRIM',
            tone: V21ButtonTone.green,
            fontSize: myReady ? 42 : 62,
            icon: Icons.check_rounded,
            busy: busy,
            onTap: waiting && !myReady && (isHost || guest != null) ? onReady : null,
          ),
        ),
        wBox(1264, 832, 1630, 916, WButton('ODAYI TERK ET', tone: V21ButtonTone.red, fontSize: 36, icon: Icons.logout_rounded, onTap: onLeave)),
        if (error != null)
          wBox(
            472,
            270,
            1430,
            298,
            Center(child: Text(error!, maxLines: 1, overflow: TextOverflow.ellipsis, style: wBody(22, color: const Color(0xFFFFC27A), weight: FontWeight.w900))),
          ),
      ],
    );
  }

  Widget _player(String tag, IconData icon, String name, String? seed, Color color, bool ready, bool mine) => Stack(
    clipBehavior: Clip.none,
    children: [
      Positioned.fill(
        child: Container(
          padding: const EdgeInsets.fromLTRB(26, 18, 26, 12),
          decoration: BoxDecoration(
            color: const Color(0xFF341A86),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color, width: 5),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  seed == null
                      ? const SizedBox(width: 84, height: 84, child: Icon(Icons.person_search_rounded, size: 60, color: Color(0xFFD9CCF7)))
                      : V21PlayerAvatar(seed: seed, size: 84, semanticsLabel: name),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: wTitle(34)),
                        Text(ready ? 'HAZIR' : 'Hazır değil', style: wBody(23, color: ready ? const Color(0xFF6BF07A) : V21Colors.goldTop)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                // Rakibin kadrosu maç başlayana kadar gizli kalır
                child: AspectRatio(
                  aspectRatio: 0.8,
                  child: Transform.rotate(
                    angle: tag == 'DAVETLİ' ? 0.02 : -0.04,
                    child: mine ? const _MyBestCard() : const WHiddenCard(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      Positioned(
        top: -18,
        left: 96,
        right: 96,
        height: 40,
        child: Container(
          decoration: BoxDecoration(color: const Color(0xFF341A86), borderRadius: BorderRadius.circular(20), border: Border.all(color: color, width: 3)),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              children: [Icon(icon, color: color, size: 26), const SizedBox(width: 8), Text(tag, style: wTitle(24))],
            ),
          ),
        ),
      ),
    ],
  );
}

/// Aktif kadronun en güçlü kartı
class _MyBestCard extends StatelessWidget {
  const _MyBestCard();

  @override
  Widget build(BuildContext context) {
    if (!getIt.isRegistered<DeckViewModel>()) return const WHiddenCard();
    return ChangeNotifierProvider<DeckViewModel>(
      create: (_) => getIt<DeckViewModel>()..load(),
      child: Builder(
        builder: (context) {
          final cards = [...context.watch<DeckViewModel>().selectedCards]..sort((a, b) => b.power.compareTo(a.power));
          return cards.isEmpty ? const WHiddenCard() : WCard.of(cards.first);
        },
      ),
    );
  }
}
