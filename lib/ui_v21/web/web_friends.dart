part of 'web_screens.dart';

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
    final host = r?['host_name']?.toString() ?? (code == null ? me : 'Bağlanıyor...'.tr);
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
                  Text('ARKADAŞLAR / '.tr, style: wTitle(52)),
                  Text('ÖZEL ODA'.tr, style: wTitle(52, color: V21Colors.goldTop)),
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
                  Text('ÖDÜLSÜZ  •  KART KAYBI YOK'.tr, style: wTitle(35, color: V21Colors.goldTop)),
                ],
              ),
            ),
          ),
        ),
        wBox(472, 298, 854, 668, _player('ODA SAHİBİ'.tr, Icons.workspace_premium_rounded, host, 'oda-$host', const Color(0xFFFFC832), r?['host_ready'] == true, isHost)),
        wBox(1048, 298, 1430, 668, _player('DAVETLİ'.tr, Icons.groups_rounded, guest ?? 'Bekleniyor...'.tr, guest == null ? null : 'oda-$guest', const Color(0xFF4FA8F5), r?['guest_ready'] == true, !isHost)),
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
                      Text('DAVET KODU'.tr, style: wBody(23, color: const Color(0xFFD9CCF7))),
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
                                decoration: InputDecoration(hintText: 'Kodu buraya yaz'.tr, border: InputBorder.none, isDense: true),
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(
                  child: code == null
                      ? WButton('DAVET OLUŞTUR'.tr, fontSize: 32, icon: Icons.add_link_rounded, onTap: busy ? null : onCreate)
                      : WButton('DAVET KODUNU KOPYALA'.tr, fontSize: 30, icon: Icons.copy_rounded, onTap: onCopy),
                ),
                const SizedBox(width: 30),
                Expanded(
                  child: code == null
                      ? WButton('ODA KODUYLA KATIL'.tr, tone: V21ButtonTone.blue, fontSize: 30, icon: Icons.login_rounded, onTap: busy ? null : onJoin)
                      : WButton('LİNKİ PAYLAŞ'.tr, tone: V21ButtonTone.blue, fontSize: 34, icon: Icons.share_rounded, onTap: onShare),
                ),
              ],
            ),
          ),
        ),
        wBox(310, 832, 662, 916, WButton('KADROMU SEÇ'.tr, tone: V21ButtonTone.purple, fontSize: 36, icon: Icons.style_rounded, onTap: () => context.push(AppRoutes.deck))),
        wBox(
          708,
          826,
          1212,
          920,
          WButton(
            myReady ? 'RAKİP BEKLENİYOR'.tr : 'HAZIRIM'.tr,
            tone: V21ButtonTone.green,
            fontSize: myReady ? 42 : 62,
            icon: Icons.check_rounded,
            busy: busy,
            onTap: waiting && !myReady && (isHost || guest != null) ? onReady : null,
          ),
        ),
        wBox(1264, 832, 1630, 916, WButton('ODAYI TERK ET'.tr, tone: V21ButtonTone.red, fontSize: 36, icon: Icons.logout_rounded, onTap: onLeave)),
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
                        Text(ready ? 'HAZIR'.tr : 'Hazır değil'.tr, style: wBody(23, color: ready ? const Color(0xFF6BF07A) : V21Colors.goldTop)),
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
                    angle: tag == 'DAVETLİ'.tr ? 0.02 : -0.04,
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
