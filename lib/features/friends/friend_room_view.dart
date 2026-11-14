import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/di/injection.dart';
import '../../../core/network/api_client.dart';
import '../../../core/router/app_routes.dart';
import 'friend_room_api.dart';

/// Two-player invitation lobby. Server status remains authoritative.
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
      if (mounted) setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyError(Object e) {
    // Never display auth credentials or entire raw HTTP payloads.
    final message = e.toString();
    if (message.contains('404')) return 'Davet bulunamadi veya suresi doldu.';
    if (message.contains('400')) return 'Davet gecersiz, oda dolu veya kadro hazir degil.';
    return 'Islem tamamlanamadi. Baglantini kontrol edip tekrar dene.';
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
    setState(() => _room = room);
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
      // Keep lobby open: temporary network failures must not cancel an invite.
      if (mounted) setState(() => _error = 'Baglanti kesildi, yeniden deneniyor.');
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
            ? 'Once 11 kartlik aktif bir kadro hazirla.'
            : _friendlyError(e));
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
    final text = 'Futbol Card Arena - Benimle oyna!\n'
        '${FriendRoomApi.inviteUrl(code)}\n'
        'Davet kodu: $code';
    await SharePlus.instance.share(ShareParams(text: text, subject: 'Futbol Card Arena daveti'));
  }

  @override
  Widget build(BuildContext context) {
    final room = _room;
    final status = room?['status']?.toString();
    final isHost = room?['is_host'] == true;
    final myReady = isHost ? room?['host_ready'] == true : room?['guest_ready'] == true;
    final guestPresent = room?['guest_name'] != null;
    return Scaffold(
      appBar: AppBar(title: const Text('ARKADASINLA OYNA')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: const EdgeInsets.all(22),
              children: [
                const Icon(Icons.sports_soccer, size: 58),
                const SizedBox(height: 14),
                Text('Ozel mac', textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 12),
                const Text('Arkadasini davet et. Dereceli puanin ve kartlarin etkilenmez.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                if (_code == null) ...[
                  FilledButton.icon(onPressed: _busy ? null : _create,
                    icon: const Icon(Icons.add_link), label: const Text('DAVET OLUSTUR')),
                  const SizedBox(height: 18),
                  TextField(controller: _codeController,
                    decoration: const InputDecoration(labelText: 'Davet kodu',
                      border: OutlineInputBorder()),
                    textCapitalization: TextCapitalization.none),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _join(_codeController.text),
                    icon: const Icon(Icons.login), label: const Text('ODA KODUYLA KATIL')),
                ] else ...[
                  SelectableText('Davet kodu: ${_code!}', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton.icon(onPressed: _busy ? null : _share,
                      icon: const Icon(Icons.share), label: const Text('LINKI PAYLAS')),
                  TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: FriendRoomApi.inviteUrl(_code!)));
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Davet linki kopyalandi')));
                    },
                    icon: const Icon(Icons.copy), label: const Text('Linki kopyala')),
                  const Divider(height: 35),
                  Text('Oda sahibi: ${room?['host_name'] ?? 'Baglaniyor...'}'),
                  Text('Rakip: ${room?['guest_name'] ?? 'Bekleniyor...'}'),
                  const SizedBox(height: 12),
                  Text('Sen: ${myReady ? 'Hazirsin' : 'Hazir degilsin'}'),
                  const SizedBox(height: 10),
                  if (status == 'waiting') ...[
                    FilledButton(onPressed: _busy || (!isHost && !guestPresent) || myReady
                        ? null : _ready, child: Text(myReady ? 'RAKIP BEKLENIYOR...' : 'HAZIRIM')),
                    const SizedBox(height: 10),
                    OutlinedButton(onPressed: _busy ? null : _leave,
                      child: const Text('ODADAN CIK')),
                  ] else ...[
                    Text(status == 'expired' ? 'Davetin suresi doldu.' :
                      status == 'cancelled' ? 'Oda kapatildi.' : 'Oda durumu: $status'),
                    OutlinedButton(onPressed: _leave, child: const Text('GERI DON')),
                  ],
                ],
                if (_busy) const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator())),
                if (_error != null) Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(_error!, style: const TextStyle(color: Colors.orangeAccent))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
