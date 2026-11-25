import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/di/injection.dart';
import '../../core/network/api_client.dart';
import '../../core/router/app_routes.dart';
import '../../ui_v21/ui_v21.dart';
import 'friend_room_api.dart';
import 'friend_room_view_model.dart';
import '../../ui_v21/web/web_kit.dart';
import '../../ui_v21/web/web_screens.dart';
import '../../core/l10n/app_language.dart';
import '../social/friend_challenge.dart';

export 'friend_room_view_model.dart' show friendRoomErrorText;

/// İki kişilik davet odası. Durum ve sunucu işleri [FriendRoomViewModel]'de;
/// bu ekran yalnız çizer ve maç başlayınca maça geçer.
class FriendRoomView extends StatefulWidget {
  const FriendRoomView({super.key, this.inviteCode, this.viewModel});
  final String? inviteCode;

  /// Testlerde hazır ViewModel verilebilir
  final FriendRoomViewModel? viewModel;

  @override
  State<FriendRoomView> createState() => _FriendRoomViewState();
}

class _FriendRoomViewState extends State<FriendRoomView> {
  late final FriendRoomViewModel _vm = widget.viewModel ??
      FriendRoomViewModel(
        () => FriendRoomApi(getIt<ApiClient>()),
        // 058: odadan çıkınca bu odadan giden bekleyen dostluk daveti geri çekilir
        onLeaveRoom: (code) => getIt<FriendChallengeController>().cancelForRoom(code),
      );
  final _codeController = TextEditingController();
  bool _gecildi = false;

  @override
  void initState() {
    super.initState();
    _vm.addListener(_degisti);
    if (widget.inviteCode != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _vm.start(widget.inviteCode);
      });
    }
  }

  @override
  void dispose() {
    _vm.removeListener(_degisti);
    if (widget.viewModel == null) _vm.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _degisti() {
    if (!mounted) return;
    final mac = _vm.startedMatchId;
    if (mac != null && !_gecildi) {
      _gecildi = true;
      context.go(AppRoutes.matchWithId(mac));
      return;
    }
    setState(() {});
  }

  Future<void> _leave() async {
    await _vm.leave();
    if (mounted) context.go(AppRoutes.friends);
  }

  Future<void> _share() async {
    final code = _vm.code;
    if (code == null) return;
    final text = 'Futbol Card Arena: benimle oyna!\n{p}\nDavet kodu: {code}'.trArgs({'p': FriendRoomApi.inviteUrl(code), 'code': code});
    await SharePlus.instance.share(ShareParams(text: text, subject: 'Futbol Card Arena daveti'.tr));
  }

  @override
  Widget build(BuildContext context) {
    final room = _vm.room;
    final status = _vm.status;
    final myReady = _vm.myReady;
    final code = _vm.code;
    final busy = _vm.busy;
    final error = _vm.error;
    if (v21IsWeb(context)) {
      return WebFriends(
        code: code,
        room: room,
        error: error,
        busy: busy,
        codeController: _codeController,
        onCreate: _vm.create,
        onJoin: () => _vm.join(_codeController.text),
        onReady: _vm.ready,
        onLeave: code == null ? () => context.go(AppRoutes.home) : _leave,
        onShare: _share,
        onCopy: () async {
          await Clipboard.setData(ClipboardData(text: code ?? ''));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Davet kodu kopyalandı'.tr)));
          }
        },
      );
    }
    return V21InnerPage(
      title: 'ARKADAŞINLA OYNA'.tr,
      route: AppRoutes.friends,
      fallbackRoute: AppRoutes.home,
      children: (context, k) {
        final govde = V21Type.label(14 * k, weight: FontWeight.w700, height: 1.35);
        Widget dugme(
          String etiket,
          VoidCallback? eylem, {
          V21ButtonTone ton = V21ButtonTone.purple,
          IconData? simge,
        }) => Padding(
          padding: EdgeInsets.only(bottom: 10 * k),
          child: V21GameButton(
            label: etiket,
            tone: ton,
            size: V21ButtonSize.medium,
            leadingIcon: simge,
            scale: k,
            status: eylem == null ? V21ButtonStatus.disabled : V21ButtonStatus.normal,
            onPressed: eylem,
          ),
        );
        return [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: V21GamePanel(
                scale: k,
                padding: EdgeInsets.all(16 * k),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.sports_soccer_rounded, size: 52 * k, color: V21Colors.goldTop),
                    SizedBox(height: 8 * k),
                    Text('ÖZEL MAÇ'.tr, textAlign: TextAlign.center, style: V21Type.title(26 * k)),
                    SizedBox(height: 6 * k),
                    Text(
                      'Arkadaşını davet et. Dereceli puanın ve kartların etkilenmez.'.tr,
                      textAlign: TextAlign.center,
                      style: V21Type.label(13 * k, weight: FontWeight.w700, color: V21Colors.textMuted, height: 1.35),
                    ),
                    SizedBox(height: 16 * k),
                    if (code == null) ...[
                      dugme('DAVET OLUŞTUR'.tr, busy ? null : _vm.create, ton: V21ButtonTone.gold, simge: Icons.add_link_rounded),
                      SizedBox(height: 6 * k),
                      TextField(
                        controller: _codeController,
                        style: govde,
                        decoration: InputDecoration(labelText: 'Davet kodu'.tr, border: const OutlineInputBorder()),
                        textCapitalization: TextCapitalization.none,
                      ),
                      SizedBox(height: 10 * k),
                      dugme(
                        'ODA KODUYLA KATIL'.tr,
                        busy ? null : () => _vm.join(_codeController.text),
                        simge: Icons.login_rounded,
                      ),
                    ] else ...[
                      SelectableText('Davet kodu: {code}'.trArgs({'code': code}), textAlign: TextAlign.center, style: govde),
                      SizedBox(height: 12 * k),
                      dugme('BAĞLANTIYI PAYLAŞ'.tr, busy ? null : _share, ton: V21ButtonTone.blue, simge: Icons.share_rounded),
                      dugme('BAĞLANTIYI KOPYALA'.tr, () async {
                        await Clipboard.setData(ClipboardData(text: FriendRoomApi.inviteUrl(code)));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Davet bağlantısı kopyalandı'.tr)),
                          );
                        }
                      }, simge: Icons.copy_rounded),
                      Divider(height: 24 * k, color: V21Colors.pillBorder),
                      Text('Oda sahibi: {p}'.trArgs({'p': room?['host_name'] ?? 'Bağlanıyor...'.tr}), style: govde),
                      Text('Rakip: {p}'.trArgs({'p': room?['guest_name'] ?? 'Bekleniyor...'.tr}), style: govde),
                      SizedBox(height: 6 * k),
                      Text('Sen: {p}'.trArgs({'p': myReady ? 'Hazırsın'.tr : 'Hazır değilsin'.tr}), style: govde),
                      SizedBox(height: 12 * k),
                      if (status == 'waiting') ...[
                        dugme(
                          myReady ? 'RAKİP BEKLENİYOR...'.tr : 'HAZIRIM'.tr,
                          _vm.canReady ? _vm.ready : null,
                          ton: V21ButtonTone.green,
                        ),
                        dugme('ODADAN ÇIK'.tr, busy ? null : _leave),
                      ] else ...[
                        Text(
                          status == 'expired'
                              ? 'Davetin süresi doldu.'.tr
                              : status == 'cancelled'
                              ? 'Oda kapatıldı.'.tr
                              : 'Oda durumu: {status}'.trArgs({'status': status}),
                          style: govde,
                        ),
                        SizedBox(height: 10 * k),
                        dugme('GERİ DÖN'.tr, _leave),
                      ],
                    ],
                    if (busy)
                      Padding(
                        padding: EdgeInsets.all(12 * k),
                        child: const Center(child: CircularProgressIndicator(color: V21Colors.goldTop)),
                      ),
                    if (error != null)
                      Padding(
                        padding: EdgeInsets.only(top: 8 * k),
                        child: Text(
                          error,
                          textAlign: TextAlign.center,
                          style: V21Type.label(13 * k, weight: FontWeight.w800, color: const Color(0xFFFFB27A)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ];
      },
    );
  }
}
