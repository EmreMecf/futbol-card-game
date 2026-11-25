part of 'web_screens.dart';

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
        wBox(370, 96, 900, 166, Text('GELİŞİM'.tr, style: wTitle(58))),
        wBox(262, 180, 930, 484, _main(sel, o, vm)),
        wBox(
          945,
          182,
          1256,
          466,
          WPanel(
            title: 'JOKER PARÇALAR'.tr,
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
                          V21ItemArt(category: 'joker', tier: t, size: 60),
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
            title: 'GELİŞİM MATERYALLERİ'.tr,
            icon: wImage('nav_cards', fit: BoxFit.contain),
            headerHeight: 64,
            trailing: Row(
              children: [
                _menu<bool>(vm.onlyReady ? 'Atlayabilir'.tr : 'Tümü'.tr, const {'Tümü': false, 'Atlayabilir': true}, vm.setOnlyReady),
                const SizedBox(width: 18),
                _menu<CardPosition?>(
                  'Rol: {p}'.trArgs({'p': _role?.code ?? 'Tümü'.tr}),
                  <String, CardPosition?>{'Tümü': null, for (final p in CardPosition.values) p.code: p},
                  (v) => setState(() => _role = v),
                ),
                const SizedBox(width: 18),
                _menu<bool>(
                  'Sıralama: Seviye ({p})'.trArgs({'p': _asc ? 'Artan'.tr : 'Azalan'.tr}),
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
                  artKey: it.slug,
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
    itemBuilder: (_) => [for (final e in options.entries) PopupMenuItem<T>(value: e.value, child: Text(e.key.tr))],
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
      return WPanel(child: Center(child: Text('Şu an gelişecek futbolcu yok.'.tr, style: wBody(26))));
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
              child: WCard(name: i.fullName, artKey: i.slug, tier: i.tier, power: i.power, position: i.position.code),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text('SEVİYE {level}'.trArgs({'level': i.level}), style: wTitle(58)),
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
                      Text('Kopya'.tr, style: wBody(27)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: WBar(
                          value: need == 0 ? 1 : i.copies / need,
                          height: 26,
                          colors: const [Color(0xFF56C7FF), Color(0xFF7DE4FF)],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(i.isMax ? 'MAKS'.tr : '${i.copies}/$need', style: wBody(27)),
                    ],
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 104,
                    child: WButton(
                      i.isMax ? 'EN YÜKSEK SEVİYE'.tr : (ready || !joker ? 'SEVİYE ATLA'.tr : 'JOKERLE ATLA'.tr),
                      tone: ready || i.isMax ? V21ButtonTone.green : V21ButtonTone.blue,
                      fontSize: 54,
                      busy: vm.busyCardId == i.cardId,
                      semantics: next == null ? null : 'Seviye atla, {coins} altın'.trArgs({'coins': next.coins}),
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
      title: 'YÜKSELTME SONRASI'.tr,
      titleSize: 29,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: i == null || next == null
            ? Center(child: Text('En yüksek seviye'.tr, style: wBody(24)))
            : Column(
                children: [
                  row(null, 'Seviye'.tr, '${i.level}', '${i.level + 1}'),
                  row(null, 'Genel Reyting'.tr, '${i.power + _bonus(i.level)}', '${i.power + _bonus(i.level + 1)}'),
                  row(Icons.style_rounded, 'Gereken Kopya'.tr, '${i.copies}', '${next.copies}'),
                  row(Icons.monetization_on_rounded, 'Altın Bedeli'.tr, '-', V21Format.thousands(next.coins)),
                ],
              ),
      ),
    );
  }
}
