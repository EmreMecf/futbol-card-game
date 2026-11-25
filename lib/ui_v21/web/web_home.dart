part of 'web_screens.dart';

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
            active == null ? 'MAÇA BAŞLA'.tr : 'MAÇA DÖN'.tr,
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
            title: 'SANDIKLAR'.tr,
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
            title: 'GÜNLÜK GÖREVLER'.tr,
            icon: const Icon(Icons.track_changes_rounded, color: Color(0xFFFF6B6B), size: 40),
            trailing: V21Tap(
              onTap: () => context.go(AppRoutes.season),
              child: Text('Tümünü Gör  ›'.tr, style: wBody(20, color: const Color(0xFFD9CCF7))),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                children: [
                  for (final m in daily) Expanded(child: _MissionRow(m: m)),
                  if (daily.isEmpty)
                    Expanded(child: Center(child: Text('Görevler yükleniyor'.tr, style: wBody(20)))),
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
            label: 'Sezon ödülleri'.tr,
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
            child: Text('+{xp} XP'.trArgs({'xp': m.xp}), maxLines: 1, style: wBody(18, color: V21Colors.goldTop, weight: FontWeight.w900)),
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
      if (mounted) AppSnackBar.showInfo(context, 'Günlük sandığın eklendi.'.tr);
    } catch (_) {
      if (mounted) AppSnackBar.showInfo(context, 'Sandık alınamadı. Tekrar dene.'.tr);
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
      child: WButton('GÜNLÜK SANDIK AL'.tr, tone: V21ButtonTone.green, fontSize: 20, busy: _busy, onTap: _claim),
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
        : (c.isReady ? 'AÇ!'.tr : V21Format.shortDuration(c.unlockSeconds));
    final color = c == null ? const Color(0xFF6B58A8) : (c.isUnlocking ? const Color(0xFF3DD15A) : accent(c.chestType));
    return V21Tap(
      onTap: () => context.go(AppRoutes.chests),
      child: Column(
        children: [
          SizedBox(
            height: 24,
            child: FittedBox(
              child: Text(
                c == null ? ' ' : (c.isUnlocking ? 'AÇILIYOR'.tr : V21Format.upper(c.typeName)),
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
          return WebDeckRow(cards: cards.take(5).toList(), label: 'KADROM'.tr, onTap: () => context.go(AppRoutes.deck));
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
