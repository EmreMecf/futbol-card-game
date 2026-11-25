import 'dart:async';

import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/app_language.dart';
import '../../core/router/app_routes.dart';
import '../../features/social/friend_challenge.dart';
import '../foundation/v21_colors.dart';
import '../foundation/v21_typography.dart';
import 'v21_game_button.dart';

/// DOSTLUK MAÇI DAVET KUTUCUĞU (058)
///
/// Bir arkadaş oyuncuyu maça çağırınca ekranın üstünden kayarak gelir.
/// Sistem bildirimi değildir; oyun açıkken hangi ekrandaysa (maç, rakip
/// arama ve özel oda hariç) orada görünür.
///
///   [A]  ahmet                               ⏱ 54
///        seni dostluk maçına çağırıyor!
///        ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░  (geri sayım)
///        [ REDDET ]          [ KABUL ET ]
///
/// Yukarı kaydırınca gizlenir (davet açık kalır, çağırana süre dolunca
/// "yanıt vermedi" gider). KABUL: oyuncu aynı odaya katılır ve odaya geçer.
/// Kısa bilgi mesajları ("X davetini reddetti") da aynı yerde görünür.
class V21FriendChallengeBanner extends StatefulWidget {
  final FriendChallengeController controller;
  final GoRouter router;

  const V21FriendChallengeBanner({super.key, required this.controller, required this.router});

  /// Bu ekranlarda kutucuk gösterilmez (oyuncu meşgul)
  static bool hiddenOn(String path) =>
      path.startsWith(AppRoutes.match) ||
      path.startsWith(AppRoutes.matchmaking) ||
      path.startsWith(AppRoutes.friendInvite) ||
      path.startsWith(AppRoutes.friends) ||
      path == AppRoutes.splash ||
      path.startsWith(AppRoutes.login) ||
      path.startsWith(AppRoutes.register);

  /// Bilgi mesajları ("X davetini reddetti") yalnız maçta ve rakip
  /// ararken gizlenir; çağıran odada beklerken yanıtı görebilsin.
  static bool messageHiddenOn(String path) =>
      path.startsWith(AppRoutes.match) || path.startsWith(AppRoutes.matchmaking);

  @override
  State<V21FriendChallengeBanner> createState() => _V21FriendChallengeBannerState();
}

class _V21FriendChallengeBannerState extends State<V21FriendChallengeBanner> {
  StreamSubscription<String>? _mesajAboneligi;
  String? _mesaj;
  Timer? _mesajSayaci;
  Timer? _saniye;
  String? _sonGosterilen;

  FriendChallengeController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_degisti);
    widget.router.routerDelegate.addListener(_degisti);
    _mesajAboneligi = _c.messages.listen(_mesajGoster);
    _c.start();
    // Geri sayım yazısı saniyede bir yenilenir
    _saniye = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_c.current != null && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _c.removeListener(_degisti);
    widget.router.routerDelegate.removeListener(_degisti);
    _mesajAboneligi?.cancel();
    _mesajSayaci?.cancel();
    _saniye?.cancel();
    super.dispose();
  }

  void _degisti() {
    if (!mounted) return;
    final c = _c.current;
    if (c != null && c.id != _sonGosterilen && !_gizli) {
      _sonGosterilen = c.id;
      unawaited(HapticFeedback.mediumImpact());
    }
    setState(() {});
  }

  void _mesajGoster(String m) {
    if (!mounted) return;
    _mesajSayaci?.cancel();
    setState(() => _mesaj = m);
    _mesajSayaci = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _mesaj = null);
    });
  }

  String get _yol {
    try {
      return widget.router.routerDelegate.currentConfiguration.uri.path;
    } catch (_) {
      return '';
    }
  }

  bool get _gizli => V21FriendChallengeBanner.hiddenOn(_yol);

  Future<void> _kabul() async {
    final kod = await _c.accept();
    if (kod != null && mounted) widget.router.go(AppRoutes.friendInviteWithCode(kod));
  }

  @override
  Widget build(BuildContext context) {
    final c = _gizli ? null : _c.current;
    final mesaj = V21FriendChallengeBanner.messageHiddenOn(_yol) ? null : _mesaj;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, a) => SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, -1.4), end: Offset.zero).animate(a),
                  child: FadeTransition(opacity: a, child: child),
                ),
                child: c != null
                    ? _Davet(
                        key: ValueKey('davet-${c.id}'),
                        challenge: c,
                        now: _c.now(),
                        busy: _c.busy,
                        onAccept: _kabul,
                        onDecline: _c.decline,
                        onDismiss: _c.dismiss,
                      )
                    : mesaj != null
                        ? _Bilgi(key: ValueKey('bilgi-$mesaj'), text: mesaj)
                        : const SizedBox.shrink(key: ValueKey('bos')),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Davet extends StatelessWidget {
  final FriendChallenge challenge;
  final DateTime now;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onDismiss;

  const _Davet({
    super.key,
    required this.challenge,
    required this.now,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final kalan = challenge.remaining(now);
    // Yukarı yuvarlanır: 44,9 sn "45" görünür
    final saniye = (kalan.inMilliseconds / 1000).ceil();
    final oran = (kalan.inMilliseconds / FriendChallenge.lifetime.inMilliseconds).clamp(0.0, 1.0);
    final ad = challenge.fromName;
    return GestureDetector(
      // Yukarı kaydır: gizle
      onVerticalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) < -150) onDismiss();
      },
      child: Semantics(
        container: true,
        liveRegion: true,
        label: '{name} seni dostluk maçına çağırıyor. {s} saniye kaldı.'.trArgs({'name': ad, 's': saniye}),
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            key: const Key('dostluk-daveti'),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF5B2DC0), Color(0xFF2E1475)],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: V21Colors.goldTop, width: 2.5),
              boxShadow: const [
                BoxShadow(color: Color(0x99000000), blurRadius: 18, offset: Offset(0, 8)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _Rozet(harf: ad.isEmpty ? '?' : ad.characters.first),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ad,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: V21Type.title(18, color: Colors.white),
                          ),
                          Text(
                            'seni dostluk maçına çağırıyor!'.tr,
                            maxLines: 2,
                            style: V21Type.label(12.5, weight: FontWeight.w800, color: V21Colors.goldTop),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_rounded, size: 18, color: Colors.white70),
                        const SizedBox(width: 3),
                        Text('$saniye', style: V21Type.title(16, color: Colors.white)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    height: 7,
                    color: const Color(0x55000000),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: oran,
                      child: Container(color: oran > 0.25 ? V21Colors.success : V21Colors.danger),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: V21GameButton(
                        key: const Key('davet-reddet'),
                        label: 'REDDET'.tr,
                        tone: V21ButtonTone.red,
                        size: V21ButtonSize.small,
                        onPressed: busy ? null : onDecline,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: V21GameButton(
                        key: const Key('davet-kabul'),
                        label: 'KABUL ET'.tr,
                        tone: V21ButtonTone.green,
                        size: V21ButtonSize.small,
                        onPressed: busy ? null : onAccept,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Rozet extends StatelessWidget {
  final String harf;
  const _Rozet({required this.harf});

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(colors: [V21Colors.goldTop, V21Colors.goldBottom]),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: [
            Center(child: Text(V21UpperInitial.of(harf), style: V21Type.title(20, color: const Color(0xFF3A1E00)))),
            const Positioned(
              right: -7,
              bottom: -7,
              child: Icon(Icons.sports_soccer_rounded, size: 20, color: Colors.white),
            ),
          ],
        ),
      );
}

/// Baş harf (Türkçede i → İ)
class V21UpperInitial {
  static String of(String s) => isEnglish ? s.toUpperCase() : (s == 'i' ? 'İ' : (s == 'ı' ? 'I' : s.toUpperCase()));
}

class _Bilgi extends StatelessWidget {
  final String text;
  const _Bilgi({super.key, required this.text});

  @override
  Widget build(BuildContext context) => Material(
        type: MaterialType.transparency,
        child: Container(
          key: const Key('dostluk-bilgi'),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xF02E1475),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF7B60C8), width: 1.5),
          ),
          child: Row(
            children: [
              const Icon(Icons.sports_soccer_rounded, color: V21Colors.goldTop, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(text, style: V21Type.label(13, weight: FontWeight.w800, color: Colors.white))),
            ],
          ),
        ),
      );
}
