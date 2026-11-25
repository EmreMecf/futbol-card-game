part of 'web_screens.dart';

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
        wBox(392, 116, 1100, 190, Text('SANDIKLAR'.tr, style: wTitle(60))),
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
                          Text('SANDIK HAKKI'.tr, style: wTitle(32)),
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
                      Text('Her {refillMinutes} dk\'da 1 hak yenilenir'.trArgs({'refillMinutes': e.refillMinutes}), style: wBody(23, color: const Color(0xFFFFE6DC))),
                    ],
                  ),
                ),
                Text('${e.energy}/${e.max}', style: wTitle(58)),
              ],
            ),
          ),
        ),
        wBox(297, 335, 700, 392, Text('YUVALAR'.tr, style: wTitle(44))),
        wBox(800, 345, 1100, 385, Align(alignment: Alignment.centerRight, child: Text('Aynı anda 1 sandık açılır'.tr, style: wBody(24, color: const Color(0xFFB9A4F0))))),
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
                        'Yuvalar doluyken kazandığın sandıklar burada {mailboxDays} gün bekler.'.trArgs({'mailboxDays': env.mailboxDays}),
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
                  Text('{p} SANDIK'.trArgs({'p': V21Format.upper(c.typeName)}), style: wTitle(38, color: const Color(0xFFFFC77A))),
                  const SizedBox(height: 6),
                  Text(mailbox ? 'Posta kutusunda'.tr : 'Maç ödülü · hazır'.tr, style: wBody(26)),
                ],
              ),
            ),
            SizedBox(
              width: 210,
              height: 84,
              child: WButton(
                mailbox ? 'TAŞI'.tr : 'AÇ!'.tr,
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
            Text('BOŞ YUVA'.tr, style: wBody(24, color: const Color(0xFF8E7FBE))),
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
            FittedBox(child: Text('{p} SANDIK'.trArgs({'p': V21Format.upper(c.typeName)}), style: wTitle(28, color: const Color(0xFFFFD98A)))),
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
                        c.isReady ? 'AÇ!'.tr : (c.isUnlocking ? V21Format.countdown(vm.remaining(c) ?? Duration.zero) : V21Format.shortDuration(c.unlockSeconds)),
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
        ? 'SANDIK YOK'.tr
        : c.isReady
        ? 'AÇ!'.tr
        : c.isUnlocking
        ? '{p} SONRA AÇILACAK'.trArgs({'p': V21Format.countdown(vm.remaining(c) ?? Duration.zero)})
        : 'SAYACI BAŞLAT'.tr;
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
        FittedBox(fit: BoxFit.scaleDown, child: Text(c == null ? 'SANDIK'.tr : '{p} SANDIK'.trArgs({'p': V21Format.upper(c.typeName)}), style: wTitle(50))),
        const SizedBox(height: 6),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFD9CCF7), borderRadius: BorderRadius.circular(18)),
            child: Text(
              c == null ? 'BOŞ'.tr : (c.isUnlocking ? 'AÇILIYOR'.tr : (c.isReady ? 'HAZIR'.tr : 'SIRADA'.tr)),
              style: V21Type.title(25, color: const Color(0xFF2A1567)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: Text('İçinden oyuncu kartları, altın ve çeşitli ödüller çıkar.'.tr, textAlign: TextAlign.center, style: wBody(23)),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: WPanel(
              title: 'OLASI ÖDÜLLER'.tr,
              headerHeight: 46,
              titleSize: 27,
              icon: const Icon(Icons.card_giftcard_rounded, color: V21Colors.goldTop, size: 34),
              trailing: V21Tap(
                onTap: () => context.push(AppRoutes.chestOdds),
                child: Text('Oranlar ›'.tr, style: wBody(19, color: const Color(0xFFD9CCF7))),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    reward('reward_cards', 'Oyuncu Kartları'.tr),
                    reward('reward_coins', 'Altın'.tr),
                    reward('reward_xp', 'Gelişim'.tr),
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
