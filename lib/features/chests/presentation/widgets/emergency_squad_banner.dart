import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/ref_tokens.dart';
import '../../../../shared/widgets/ref/ref_ui.dart';
import '../../domain/chest_messages.dart';
import '../../domain/chest_repository.dart';
import 'chest_widgets.dart';

/// ACİL KADRO uyarısı (Ekonomi V2, 032) — kadro ekranında.
///
/// Koleksiyon, formasyonu (1 GK, 4 DEF, 4 MID, 2 FWD) kuracak kadar
/// kart içermiyorsa (kart kaybı sonrası) oyuncu eksik sayıda Bronz kartı
/// ücretsiz alır, 24 saatte bir. Koleksiyon yetiyorsa (yalnız seçim
/// eksikse) ya da ekonomi kapalıysa hiç görünmez.
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
  EmergencySquadStatus? _durum;
  List<ChestCard> _alinan = const [];
  bool _mesgul = false;
  String? _hata;
  String? _anahtar;

  static const _mevkiAd = {'GK': 'kaleci', 'DEF': 'defans', 'MID': 'orta saha', 'FWD': 'forvet'};

  @override
  void initState() {
    super.initState();
    _durum = widget.preview;
    if (_durum == null && getIt.isRegistered<ChestRepository>()) _yukle();
  }

  Future<void> _yukle() async {
    final s = await getIt<ChestRepository>().fetchEmergencySquad();
    if (mounted) setState(() => _durum = s.dataOrNull);
  }

  Future<void> _al() async {
    setState(() {
      _mesgul = true;
      _hata = null;
    });
    // Ağ hatasında tekrar aynı anahtarla (kart iki kez verilmez)
    _anahtar ??= ApiClient.newIdempotencyKey();
    final s = await getIt<ChestRepository>().claimEmergencySquad(idempotencyKey: _anahtar!);
    if (!mounted) return;
    final v = s.dataOrNull;
    setState(() {
      _mesgul = false;
      if (v != null) {
        _alinan = v.cards;
        _durum = v.status;
        _anahtar = null;
      } else {
        _hata = chestErrorMessage(s.errorOrNull!);
      }
    });
    if (v != null) widget.onClaimed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final d = _durum;
    if (_alinan.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: Ref.pageGap),
        child: RefCardPanel(children: [
          Row(children: [
            const Icon(Icons.check_circle_rounded, size: 18, color: Ref.accent),
            const SizedBox(width: 8),
            Expanded(child: Text('Acil kadro alındı', style: Ref.bodyText(13, weight: FontWeight.w800))),
          ]),
          ChestHint('${_alinan.map((k) => '${k.fullName} (${k.position.shortLabel})').join(', ')} koleksiyonuna eklendi. '
              'Boş yuvalara dokunarak kadronu tamamla.'),
        ]),
      );
    }
    if (d == null || !d.enabled || !d.isSquadBroken) return const SizedBox.shrink();

    final eksik = d.missing.entries.map((e) => '${e.value} ${_mevkiAd[e.key] ?? e.key}').join(', ');
    return Padding(
      padding: const EdgeInsets.only(bottom: Ref.pageGap),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Ref.red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Ref.red.withValues(alpha: 0.55)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.warning_amber_rounded, size: 18, color: Ref.red),
            const SizedBox(width: 8),
            Expanded(child: Text('Kadron kurulamıyor', style: Ref.bodyText(13, weight: FontWeight.w800))),
          ]),
          const SizedBox(height: 6),
          Text('Koleksiyonunda eksik: $eksik. Ücretsiz Bronz kart alabilirsin (24 saatte bir); '
              'her mevki bir yedekle birlikte tamamlanır.',
              style: Ref.bodyText(11.5, color: Ref.muted)),
          if (_hata != null) ...[
            const SizedBox(height: 6),
            Text(_hata!, style: Ref.bodyText(11.5, color: Ref.red, weight: FontWeight.w700)),
          ],
          const SizedBox(height: 10),
          if (d.eligible)
            _mesgul
                ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                : RefSecondaryButton('ACİL KADRO AL (${d.grantCount > 0 ? d.grantCount : d.missingCount} BRONZ KART)', leadingIcon: Icons.add_rounded, onTap: _al)
          else
            Text(
              d.nextAt == null
                  ? 'Acil kadro şu an alınamıyor.'
                  : 'Sonraki acil kadro: ${chestDuration(d.nextAt!.difference(d.serverTime))} sonra. '
                      'Bu arada mağazadan paket alabilir ya da sandıklarını açabilirsin.',
              style: Ref.bodyText(11.5, color: Ref.gold, weight: FontWeight.w700),
            ),
        ]),
      ),
    );
  }
}
