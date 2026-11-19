import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../../core/di/injection.dart';
import '../../../core/network/api_client.dart';
import '../../../features/chests/domain/chest_messages.dart';
import '../../../features/chests/domain/chest_repository.dart';
import '../../../features/chests/domain/chest_texts.dart';
import '../../ui_v21.dart';

/// ACİL KADRO uyarısı: koleksiyon 4-4-2 kuracak kadar kart içermiyorsa oyuncu
/// eksik sayıda Bronz kartı ücretsiz alır (24 saatte bir). Koleksiyon yetiyorsa
/// ya da ekonomi kapalıysa görünmez.
class EmergencySquadBanner extends StatefulWidget {
  /// Kartlar alındıktan sonra kadro ekranı yenilensin
  final VoidCallback? onClaimed;

  /// Test ve önizleme için doğrudan durum
  final EmergencySquadStatus? preview;

  const EmergencySquadBanner({super.key, this.onClaimed, this.preview});

  @override
  State<EmergencySquadBanner> createState() => _EmergencySquadBannerState();
}

class _EmergencySquadBannerState extends State<EmergencySquadBanner> {
  EmergencySquadStatus? _status;
  List<ChestCard> _claimed = const [];
  bool _busy = false;
  String? _error;
  String? _key;

  static const _names = {'GK': 'kaleci', 'DEF': 'defans', 'MID': 'orta saha', 'FWD': 'forvet'};

  @override
  void initState() {
    super.initState();
    _status = widget.preview;
    if (_status == null && getIt.isRegistered<ChestRepository>()) _load();
  }

  Future<void> _load() async {
    final s = await getIt<ChestRepository>().fetchEmergencySquad();
    if (mounted) setState(() => _status = s.dataOrNull);
  }

  Future<void> _claim() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    // Ağ hatasında aynı anahtarla yeniden denenir: kart iki kez verilmez
    _key ??= ApiClient.newIdempotencyKey();
    final s = await getIt<ChestRepository>().claimEmergencySquad(idempotencyKey: _key!);
    if (!mounted) return;
    final v = s.dataOrNull;
    setState(() {
      _busy = false;
      if (v != null) {
        _claimed = v.cards;
        _status = v.status;
        _key = null;
      } else {
        _error = chestErrorMessage(s.errorOrNull!);
      }
    });
    if (v != null) widget.onClaimed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final k = V21Scale.of(context).s;
    final d = _status;
    final body = V21Type.label(12.5 * k, weight: FontWeight.w700, color: V21Colors.textMuted, height: 1.35);
    if (_claimed.isNotEmpty) {
      return Padding(
        padding: EdgeInsets.only(bottom: 10 * k),
        child: V21GamePanel(
          scale: k,
          radius: 14,
          accent: V21Colors.success,
          padding: EdgeInsets.all(12 * k),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('ACİL KADRO ALINDI', style: V21Type.title(18 * k)),
              Text(
                '${_claimed.map((c) => '${c.fullName} (${c.position.shortLabel})').join(', ')} koleksiyonuna eklendi. '
                'Boş yuvalara dokunarak kadronu tamamla.',
                style: body,
              ),
            ],
          ),
        ),
      );
    }
    if (d == null || !d.enabled || !d.isSquadBroken) return const SizedBox.shrink();

    final missing = d.missing.entries.map((e) => '${e.value} ${_names[e.key] ?? e.key}').join(', ');
    return Padding(
      padding: EdgeInsets.only(bottom: 10 * k),
      child: V21GamePanel(
        scale: k,
        radius: 14,
        accent: V21Colors.danger,
        padding: EdgeInsets.all(12 * k),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('KADRON KURULAMIYOR', style: V21Type.title(18 * k)),
            SizedBox(height: 4 * k),
            Text(
              'Koleksiyonunda eksik: $missing. Ücretsiz Bronz kart alabilirsin (24 saatte bir); '
              'her mevki bir yedekle birlikte tamamlanır.',
              style: body,
            ),
            if (_error != null) ...[
              SizedBox(height: 6 * k),
              Text(
                _error!,
                style: V21Type.label(12 * k, weight: FontWeight.w800, color: const Color(0xFFFF8A9B)),
              ),
            ],
            SizedBox(height: 10 * k),
            if (d.eligible)
              V21GameButton(
                label: 'ACİL KADRO AL (${d.grantCount > 0 ? d.grantCount : d.missingCount} BRONZ KART)',
                tone: V21ButtonTone.green,
                scale: k,
                status: _busy ? V21ButtonStatus.loading : V21ButtonStatus.normal,
                onPressed: _claim,
              )
            else
              Text(
                d.nextAt == null
                    ? 'Acil kadro şu an alınamıyor.'
                    : 'Sonraki acil kadro: ${chestDuration(d.nextAt!.difference(d.serverTime))} sonra. '
                          'Bu arada mağazadan paket alabilir ya da sandıklarını açabilirsin.',
                style: V21Type.label(12.5 * k, weight: FontWeight.w800, color: V21Colors.goldTop),
              ),
          ],
        ),
      ),
    );
  }
}
