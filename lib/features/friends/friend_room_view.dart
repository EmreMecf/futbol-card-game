import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/di/injection.dart';
import '../../core/error/app_exception.dart';
import '../../core/network/api_client.dart';
import '../../core/router/app_routes.dart';
import '../../ui_v21/ui_v21.dart';
import 'friend_room_api.dart';
import '../../ui_v21/web/web_kit.dart';
import '../../ui_v21/web/web_screens.dart';

/// Sunucunun kural mesajını gösterir ('Oda dolu.' gibi); bağlantı hatası ayrıdır.
String friendRoomErrorText(Object e) => e is AppException
    ? e.message
    : 'İşlem tamamlanamadı. Bağlantını kontrol edip tekrar dene.';

/// İki kişilik davet odası. Geçerli durum her zaman sunucudan gelir.
class FriendRoomView extends StatefulWidget {
  const FriendRoomView({super.key, this.inviteCode});
  final String? inviteCode;

  @override
  State<FriendRoomView> createState() => _FriendRoomViewState();
}

class _FriendRoomViewState extends State<FriendRoomView> {
  late final FriendRoomApi _api = FriendRoomApi(getIt<ApiClient>());
  final _codeController = TextEditingController();
  Timer? _poll;
  String? _code;
  String? _error;
  Map<String, dynamic>? _room;
  bool _busy = false;
  bool _transitioning = false;
  static const _baglantiKesildi = 'Bağlantı kesildi, yeniden deneniyor.';

  @override
  void initState() {
    super.initState();
    if (widget.inviteCode != null) {
      _code = widget.inviteCode!.toLowerCase();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _join(_code!);
      });
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _perform(Future<Map<String, dynamic>> Function() action) async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      final room = await action();
      if (!mounted) return;
      _updateRoom(room);
    } catch (e) {
      if (mounted) setState(() => _error = friendRoomErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _updateRoom(Map<String, dynamic> room) {
    if (!mounted) return;
    final code = room['code']?.toString();
    if (code != null && code.isNotEmpty) _code = code;
    final matchId = room['match_id']?.toString();
    if (room['status'] == 'started' && matchId != null && !_transitioning) {
      _transitioning = true;
      _poll?.cancel();
      context.go(AppRoutes.matchWithId(matchId));
      return;
    }
    final uyari = room['notice']?.toString();
    setState(() {
      _room = room;
      if (uyari != null) {
        _error = uyari;
      } else if (_error == _baglantiKesildi) {
        _error = null;
      }
    });
    if (_code != null && room['status'] == 'waiting' && _poll == null) {
      _poll = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
    }
    if (room['status'] != 'waiting') {
      _poll?.cancel();
      _poll = null;
    }
  }

  Future<void> _refresh() async {
    final code = _code;
    if (code == null || _busy || _transitioning) return;
    try {
      final room = await _api.status(code);
      _updateRoom(room);
    } catch (_) {
      // Geçici ağ hatası daveti iptal etmez: oda açık kalır
      if (mounted) setState(() => _error = _baglantiKesildi);
    }
  }

  Future<void> _join(String code) async {
    final normalized = code.trim().toLowerCase();
    if (!RegExp(r'^[0-9a-f]{30}$').hasMatch(normalized)) {
      setState(() => _error = '30 karakterlik davet kodunu gir.');
      return;
    }
    await _perform(() => _api.join(normalized));
  }

  Future<void> _create() => _perform(_api.create);

  Future<void> _ready() async {
    final code = _code;
    if (code == null) return;
    setState(() { _busy = true; _error = null; });
    try {
      final deckId = await _api.activeDeck();
      if (deckId == null) throw StateError('active_deck_missing');
      final room = await _api.ready(code, deckId);
      _updateRoom(room);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().contains('active_deck_missing')
            ? 'Önce 11 kartlık aktif bir kadro hazırla.'
            : friendRoomErrorText(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave() async {
    final code = _code;
    if (code != null) {
      try { await _api.leave(code); } catch (_) {}
    }
    _poll?.cancel();
    _poll = null;
    if (mounted) {
      setState(() { _code = null; _room = null; _error = null; });
      context.go(AppRoutes.friends);
    }
  }

  Future<void> _share() async {
    final code = _code;
    if (code == null) return;
    final text = 'Futbol Card Arena: benimle oyna!\n'
        '${FriendRoomApi.inviteUrl(code)}\n'
        'Davet kodu: $code';
    await SharePlus.instance.share(ShareParams(text: text, subject: 'Futbol Card Arena daveti'));
  }

  @override
  Widget build(BuildContext context) {
    final room = _room;
    final status = room?['status']?.toString();
    final isHost = room?['is_host'] == true;
    final myReady = isHost ? (room?['host_ready'] == true) : (room?['guest_ready'] == true);
    final guestPresent = room?['guest_name'] != null;
    if (v21IsWeb(context)) {
      return WebFriends(
        code: _code,
        room: room,
        error: _error,
        busy: _busy,
        codeController: _codeController,
        onCreate: _create,
        onJoin: () => _join(_codeController.text),
        onReady: _ready,
        onLeave: _code == null ? () => context.go(AppRoutes.home) : _leave,
        onShare: _share,
        onCopy: () async {
          await Clipboard.setData(ClipboardData(text: _code ?? ''));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Davet kodu kopyalandı')));
          }
        },
      );
    }
    return V21InnerPage(
      title: 'ARKADAŞINLA OYNA',
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
                    Text('ÖZEL MAÇ', textAlign: TextAlign.center, style: V21Type.title(26 * k)),
                    SizedBox(height: 6 * k),
                    Text(
                      'Arkadaşını davet et. Dereceli puanın ve kartların etkilenmez.',
                      textAlign: TextAlign.center,
                      style: V21Type.label(13 * k, weight: FontWeight.w700, color: V21Colors.textMuted, height: 1.35),
                    ),
                    SizedBox(height: 16 * k),
                    if (_code == null) ...[
                      dugme('DAVET OLUŞTUR', _busy ? null : _create, ton: V21ButtonTone.gold, simge: Icons.add_link_rounded),
                      SizedBox(height: 6 * k),
                      TextField(
                        controller: _codeController,
                        style: govde,
                        decoration: const InputDecoration(labelText: 'Davet kodu', border: OutlineInputBorder()),
                        textCapitalization: TextCapitalization.none,
                      ),
                      SizedBox(height: 10 * k),
                      dugme(
                        'ODA KODUYLA KATIL',
                        _busy ? null : () => _join(_codeController.text),
                        simge: Icons.login_rounded,
                      ),
                    ] else ...[
                      SelectableText('Davet kodu: ${_code!}', textAlign: TextAlign.center, style: govde),
                      SizedBox(height: 12 * k),
                      dugme('BAĞLANTIYI PAYLAŞ', _busy ? null : _share, ton: V21ButtonTone.blue, simge: Icons.share_rounded),
                      dugme('BAĞLANTIYI KOPYALA', () async {
                        await Clipboard.setData(ClipboardData(text: FriendRoomApi.inviteUrl(_code!)));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Davet bağlantısı kopyalandı')),
                          );
                        }
                      }, simge: Icons.copy_rounded),
                      Divider(height: 24 * k, color: V21Colors.pillBorder),
                      Text('Oda sahibi: ${room?['host_name'] ?? 'Bağlanıyor...'}', style: govde),
                      Text('Rakip: ${room?['guest_name'] ?? 'Bekleniyor...'}', style: govde),
                      SizedBox(height: 6 * k),
                      Text('Sen: ${myReady ? 'Hazırsın' : 'Hazır değilsin'}', style: govde),
                      SizedBox(height: 12 * k),
                      if (status == 'waiting') ...[
                        dugme(
                          myReady ? 'RAKİP BEKLENİYOR...' : 'HAZIRIM',
                          _busy || (!isHost && !guestPresent) || myReady ? null : _ready,
                          ton: V21ButtonTone.green,
                        ),
                        dugme('ODADAN ÇIK', _busy ? null : _leave),
                      ] else ...[
                        Text(
                          status == 'expired'
                              ? 'Davetin süresi doldu.'
                              : status == 'cancelled'
                              ? 'Oda kapatıldı.'
                              : 'Oda durumu: $status',
                          style: govde,
                        ),
                        SizedBox(height: 10 * k),
                        dugme('GERİ DÖN', _leave),
                      ],
                    ],
                    if (_busy)
                      Padding(
                        padding: EdgeInsets.all(12 * k),
                        child: const Center(child: CircularProgressIndicator(color: V21Colors.goldTop)),
                      ),
                    if (_error != null)
                      Padding(
                        padding: EdgeInsets.only(top: 8 * k),
                        child: Text(
                          _error!,
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
