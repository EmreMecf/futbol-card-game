part of 'web_screens.dart';

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
        wBox(296, 100, 900, 168, Text('KADROM'.tr, style: wTitle(58))),
        wBox(
          935,
          114,
          1106,
          166,
          Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFF1C0D4C), borderRadius: BorderRadius.circular(26)),
            child: Text('{averagePower} GÜÇ'.trArgs({'averagePower': vm.averagePower}), style: wTitle(32)),
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
            title: 'KART DETAYI'.tr,
            titleSize: 35,
            icon: wImage('nav_cards', fit: BoxFit.contain),
            child: sel == null
                ? Center(child: WButton('KART SEÇ'.tr, onTap: () => widget.onPick(_slot)))
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
            title: 'KADRO BİLGİSİ'.tr,
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
                        _orb('${vm.averagePower}', 'GÜÇ'.tr, const Color(0xFFFF5A7A)),
                        _orb('${vm.totalSelected}/${GameRules.squadSize}', 'KADRO'.tr, const Color(0xFF4FA8F5)),
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
                        vm.saveMessage ?? 'Kartı seçmek için yuvaya dokun, yer değiştirmek için sürükle'.tr,
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
        wBox(1136, 815, 1398, 898, WButton('OTOMATİK DİZ'.tr, tone: V21ButtonTone.green, fontSize: 31, icon: Icons.shuffle_rounded, onTap: vm.autoFillBest)),
        wBox(
          1414,
          815,
          1656,
          898,
          WButton(
            'KAYDET'.tr,
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
        row(Icons.fitness_center_rounded, 'Güç'.tr, card.power),
        row(Icons.directions_run_rounded, 'Hız'.tr, a?.pace ?? card.power),
        row(Icons.sports_soccer_rounded, 'Şut'.tr, a?.shooting ?? card.power),
        row(Icons.shield_outlined, 'Defans'.tr, a?.defending ?? card.power),
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
