part of 'web_screens.dart';

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
              label: 'KADROM'.tr,
              sub: '({length} KART)'.trArgs({'length': vm.deckCards.length}),
              onTap: () => context.go(AppRoutes.deck),
            ),
          ),
          wBox(378, 672, 1070, 806, WButton('RAKİP BUL'.tr, fontSize: 72, icon: Icons.sports_mma_rounded, onTap: vm.selectedDeck == null ? null : onFind)),
          wBox(318, 826, 722, 914, WButton('ARKADAŞINLA OYNA'.tr, tone: V21ButtonTone.blue, fontSize: 36, icon: Icons.group_rounded, onTap: () => context.push(AppRoutes.friends))),
          wBox(
            746,
            826,
            1146,
            914,
            WButton(
              'BOTLA ANTRENMAN'.tr,
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
            title: 'KADRO DURUMU'.tr,
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
                        check(vm.deckCards.length >= GameRules.squadSize, '{length}/{squadSize} kart seçildi'.trArgs({'length': vm.deckCards.length, 'squadSize': GameRules.squadSize})),
                        check(vm.selectedDeck != null, 'Aktif kadro seçili'.tr),
                        check(valid, valid ? 'Kadron geçerli'.tr : (v?.displayMessage ?? 'Kadro kontrol ediliyor'.tr)),
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
            title: 'DERECELİ MAÇ KURALLARI'.tr,
            icon: const Icon(Icons.emoji_events_rounded, color: V21Colors.goldTop, size: 46),
            titleSize: 34,
            headerHeight: 70,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(26, 8, 18, 10),
              child: Column(
                children: [
                  rule(Icons.emoji_events_rounded, V21Colors.goldTop, 'Rakipler benzer lig seviyesinden eşleşir.'.tr),
                  rule(Icons.style_rounded, const Color(0xFFC9B6F5), '{squadSize} kartlık kadronla oynarsın.'.trArgs({'squadSize': GameRules.squadSize})),
                  rule(Icons.bolt_rounded, V21Colors.goldTop, 'Her dereceli maç 1 sandık hakkı harcar.'.tr),
                  rule(Icons.star_rounded, V21Colors.goldTop, 'Kazandıkça lig puanı kazanır, üst lige yükselirsin.'.tr),
                ],
              ),
            ),
          ),
        ),
        if (vm.tutorial?.shouldOffer ?? false)
          wBox(1180, 826, 1656, 914, WButton('ÖĞRETİCİYİ BAŞLAT'.tr, tone: V21ButtonTone.purple, fontSize: 34, onTap: vm.startTutorial)),
      ],
    );
  }
}
