import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/auth/session_manager.dart';
import '../../core/router/app_routes.dart';
import '../../features/match/presentation/view/match_view.dart' show handOrder;
import '../../features/match/presentation/viewmodel/match_view_model.dart';
import '../ui_v21.dart';
import 'web_kit.dart';

/// Web maç ekranı: skor, adımlar, VS kartları, el, taktikler, OYNA.
/// Kurallar ve hamleler [MatchViewModel]'de; burası yalnız yerleşimdir.
class WebArena extends StatelessWidget {
  final MatchViewModel vm;
  final HandCard? selected;
  final CardPosition? pickedPosition;
  final List<String> stepLabels;
  final int stepCurrent;
  final String status;
  final ValueChanged<HandCard> onSelect;
  final ValueChanged<CardPosition> onPickPosition;
  final VoidCallback onPlay;
  final VoidCallback onConfirmPosition;
  final VoidCallback onSurrender;
  final List<Widget> overlays;
  final Widget? tutorial;

  const WebArena({
    super.key,
    required this.vm,
    required this.selected,
    required this.pickedPosition,
    required this.stepLabels,
    required this.stepCurrent,
    required this.status,
    required this.onSelect,
    required this.onPickPosition,
    required this.onPlay,
    required this.onConfirmPosition,
    required this.onSurrender,
    this.overlays = const [],
    this.tutorial,
  });

  @override
  Widget build(BuildContext context) {
    final d = vm.matchState!;
    final me = vm.myUsername ?? Provider.of<SessionManager?>(context, listen: false)?.user?.username ?? 'Sen';
    final opp = d.opponent?.username ?? 'Rakip';
    final mine = vm.myTableMove;
    final rival = vm.opponentTableMove;
    final round = d.isTutorial && d.earlyFinishCards != null
        ? 'TUR ${d.roundNumber} · HEDEF ${d.earlyFinishCards}'
        : 'TUR ${d.roundNumber}/${GameRules.squadSize}';

    final Widget myCard = mine != null && !mine.isPass
        ? _move(mine)
        : selected != null
        ? WCard(name: selected!.fullName, tier: selected!.tier, power: selected!.effectivePower, position: selected!.position.code)
        : (vm.waitingOpponentPick ? const WHiddenCard(icon: Icons.lock_rounded) : const WHiddenCard());
    final Widget rivalCard = rival != null && !rival.isPass
        ? _move(rival)
        : (d.opponentHasPlayed ? const WHiddenCard(icon: Icons.lock_rounded) : const WHiddenCard());

    return WebShell(
      route: AppRoutes.home,
      overlays: overlays,
      children: [
        wBox(265, 92, 1672, 660, wImage('arena_bg', fit: BoxFit.fill)),
        wBox(578, 116, 862, 208, _side('SEN', me, 'avatar_me', const [Color(0xFF3AA2FF), Color(0xFF1560D8)], false)),
        wBox(1034, 116, 1324, 208, _side('RAKİP', opp, 'avatar_rival', const [Color(0xFFFF6B7D), Color(0xFFD92A4A)], true)),
        wBox(
          876,
          106,
          1022,
          214,
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF241066),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: V21Colors.goldTop, width: 4),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${d.myScore}:${d.opponentScore}', style: wTitle(58)),
                FittedBox(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text(round, style: wBody(22, weight: FontWeight.w900)))),
              ],
            ),
          ),
        ),
        wBox(
          908,
          218,
          988,
          296,
          Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [V21Colors.goldTop, V21Colors.goldBottom], begin: Alignment.topCenter, end: Alignment.bottomCenter),
              border: Border.all(color: const Color(0xFF7A3B00), width: 3),
            ),
            child: Text('${vm.remainingSeconds}', style: wTitle(42)),
          ),
        ),
        wBox(730, 290, 1170, 366, FittedBox(child: SizedBox(width: 330, child: V21StepTracker(labels: stepLabels, current: stepCurrent)))),
        wBox(636, 372, 866, 632, Transform.rotate(angle: -0.09, child: myCard)),
        wBox(900, 460, 1000, 550, Center(child: Text('VS', style: wTitle(78, color: V21Colors.goldTop)))),
        wBox(1030, 372, 1258, 622, Transform.rotate(angle: 0.08, child: rivalCard)),
        wBox(
          1040,
          624,
          1290,
          650,
          Center(child: Text(d.opponentHasPlayed ? 'Rakip seçti' : 'Rakip seçiyor...', style: wBody(20))),
        ),
        wBox(
          282,
          652,
          1656,
          930,
          Container(
            decoration: BoxDecoration(
              color: const Color(0xF0301880),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: wPanelBorder, width: 2),
            ),
          ),
        ),
        wBox(310, 658, 860, 696, Text(_heading(), maxLines: 1, overflow: TextOverflow.ellipsis, style: wTitle(32, color: V21Colors.goldTop))),
        wBox(
          780,
          664,
          1000,
          694,
          Align(alignment: Alignment.centerRight, child: Text(_hint(), maxLines: 1, style: wBody(20, color: const Color(0xFFD9CCF7)))),
        ),
        wBox(300, 700, 1006, 918, vm.isPositionPhase ? _positions(d) : _hand()),
        wBox(1026, 668, 1028, 790, const ColoredBox(color: Color(0xFF6A48C8))),
        if (vm.tacticsEnabled && !vm.isPositionPhase) ...[
          for (final (i, t) in MatchTactic.playable.indexed) wBox(1050.0 + i * 118, 672, 1168.0 + i * 118, 792, _tactic(t)),
          wBox(1428, 668, 1430, 790, const ColoredBox(color: Color(0xFF6A48C8))),
          wBox(1458, 672, 1650, 790, _energy()),
        ] else
          wBox(1050, 672, 1640, 792, Center(child: Text(status, maxLines: 3, textAlign: TextAlign.center, style: wBody(23)))),
        wBox(1066, 806, 1628, 906, _action(d)),
        wBox(
          1450,
          906,
          1640,
          930,
          Align(
            alignment: Alignment.centerRight,
            child: V21Tap(
              onTap: onSurrender,
              child: Text('Teslim ol', style: wBody(18, color: const Color(0xFFFF9BB0))),
            ),
          ),
        ),
        if (tutorial != null) wBox(282, 100, 560, 360, SingleChildScrollView(child: tutorial)),
      ],
    );
  }

  String _heading() {
    if (vm.isPositionPhase) return vm.matchState!.amILead ? 'MEVKİNİ SEÇ' : 'RAKİP MEVKİ SEÇİYOR';
    final need = vm.requiredPosition;
    return need == null ? 'KARTINI SEÇ' : '${V21Format.upper(need.label)} KARTINI SEÇ';
  }

  String _hint() {
    if (vm.isPositionPhase) return '';
    final need = vm.requiredPosition;
    final cards = vm.hand.where((c) => !c.isPlayed && (need == null || c.position == need)).length;
    return '$cards kart uygun';
  }

  Widget _move(MatchMove m) => WCard(
    name: m.fullName ?? '',
    tier: m.tier ?? CardTier.bronze,
    power: m.effectivePower ?? 0,
    position: (m.position ?? CardPosition.midfielder).code,
  );

  Widget _side(String title, String name, String avatar, List<Color> colors, bool reverse) {
    final img = ClipOval(child: SizedBox(width: 78, height: 78, child: wImage(avatar)));
    final text = Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: reverse ? CrossAxisAlignment.start : CrossAxisAlignment.start,
        children: [
          Text(title, style: wTitle(36)),
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: wBody(24)),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), gradient: LinearGradient(colors: colors, begin: Alignment.topCenter, end: Alignment.bottomCenter)),
      child: Row(children: reverse ? [const SizedBox(width: 14), text, img] : [img, const SizedBox(width: 14), text]),
    );
  }

  Widget _hand() {
    final need = vm.requiredPosition;
    final cards = handOrder(vm.hand, need);
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      itemCount: cards.length,
      separatorBuilder: (_, _) => const SizedBox(width: 18),
      itemBuilder: (context, i) {
        final c = cards[i];
        final ok = need == null || c.position == need;
        final on = vm.isMyTurn && ok && !vm.isSubmittingMove && vm.myTableMove == null;
        return SizedBox(
          width: 160,
          child: WCard(
            name: c.fullName,
            tier: c.tier,
            power: c.effectivePower,
            position: c.position.code,
            dim: !ok,
            selected: selected?.userCardId == c.userCardId,
            onTap: on ? () => onSelect(c) : null,
          ),
        );
      },
    );
  }

  Widget _positions(MatchState d) {
    final counts = vm.positionCounts;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 18, 8, 18),
      child: Row(
        children: [
          for (final (i, p) in CardPosition.values.indexed) ...[
            if (i > 0) const SizedBox(width: 14),
            Expanded(
              child: V21Tap(
                onTap: d.amILead && (counts[p] ?? 0) > 0 && !vm.isSubmittingMove ? () => onPickPosition(p) : null,
                child: Opacity(
                  opacity: d.amILead && (counts[p] ?? 0) > 0 ? 1 : 0.45,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: pickedPosition == p ? const Color(0xFF6BF07A) : wPanelBorder, width: 4),
                      gradient: LinearGradient(
                        colors: pickedPosition == p ? const [Color(0xFF3FBF5A), Color(0xFF14702C)] : const [Color(0xFF5B39C4), Color(0xFF2A1670)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(p.code, style: wTitle(50)),
                        FittedBox(child: Text(V21Format.upper(p.label), style: wTitle(26))),
                        Text('${counts[p] ?? 0} kart', style: wBody(20, color: const Color(0xFFD9CCF7))),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tactic(MatchTactic t) {
    final locked = vm.isSubmittingMove || vm.myTableMove != null;
    final on = !locked && vm.canUseTactic(t);
    final sel = vm.selectedTactic == t;
    final (label, c1, c2) = switch (t) {
      MatchTactic.highPress => ('PRES', const Color(0xFFFF7A8A), const Color(0xFFD92A4A)),
      MatchTactic.counterAttack => ('KONTRA', const Color(0xFFFFD94E), const Color(0xFFFF9A12)),
      _ => ('DUVAR', const Color(0xFF6FC4FF), const Color(0xFF1F6FE0)),
    };
    return Semantics(
      button: true,
      enabled: on,
      selected: sel,
      label: '${t.label}, ${vm.tacticCost(t)} enerji. ${t.hint}',
      excludeSemantics: true,
      child: V21Tap(
        onTap: on || sel ? () => vm.selectTactic(t) : null,
        child: Opacity(
          opacity: on || sel ? 1 : 0.45,
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [c1, c2], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                  border: Border.all(color: sel ? Colors.white : const Color(0xFF241446), width: sel ? 5 : 3),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [const Icon(Icons.bolt_rounded, color: Colors.white, size: 30), Text('${vm.tacticCost(t)}', style: wTitle(38))],
                ),
              ),
              const SizedBox(height: 6),
              Text(label, style: wTitle(26)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _energy() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('ENERJİ', style: wBody(22, color: const Color(0xFFD9CCF7))),
      const SizedBox(height: 10),
      Row(
        children: [
          for (var i = 0; i < vm.maxEnergy; i++)
            Container(
              width: 28,
              height: 32,
              margin: const EdgeInsets.only(right: 7),
              decoration: BoxDecoration(
                color: i < vm.myEnergy ? const Color(0xFF56C7FF) : const Color(0xFF3B2470),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
        ],
      ),
      const SizedBox(height: 8),
      Text('${vm.myEnergy}/${vm.maxEnergy}', style: wTitle(30, color: const Color(0xFF7DE4FF))),
    ],
  );

  Widget _action(MatchState d) {
    if (vm.isPositionPhase) {
      return d.amILead
          ? WButton('DEVAM ET', tone: V21ButtonTone.green, fontSize: 60, busy: vm.isSubmittingMove, onTap: pickedPosition == null ? null : onConfirmPosition)
          : const WButton('RAKİP MEVKİ SEÇİYOR', tone: V21ButtonTone.purple, fontSize: 44, onTap: null);
    }
    if (vm.mustPass && vm.isMyTurn) {
      return WButton('PAS GEÇ · TURU KAYBET', tone: V21ButtonTone.red, fontSize: 44, busy: vm.isSubmittingMove, onTap: vm.pass);
    }
    if (vm.waitingOpponentPick || vm.myTableMove != null) {
      return const WButton('RAKİP BEKLENİYOR', tone: V21ButtonTone.purple, fontSize: 46, onTap: null);
    }
    if (!vm.isMyTurn) return const WButton('SIRA RAKİPTE', tone: V21ButtonTone.purple, fontSize: 46, onTap: null);
    return WButton('OYNA!', tone: V21ButtonTone.green, fontSize: 72, busy: vm.isSubmittingMove, onTap: selected == null ? null : onPlay);
  }
}
