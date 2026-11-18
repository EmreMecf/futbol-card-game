import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../../core/di/injection.dart';
import '../../../features/chests/presentation/widgets/chest_strip.dart' show chestInventoryChanged;
import '../../../features/daily/data/daily_service.dart';
import '../../../features/daily/presentation/daily_panel.dart' show DailyPanelTexts;
import '../../../shared/widgets/error_snackbar.dart';
import '../../ui_v21.dart';

/// Şeridin iki satırı (test edilebilsin diye ayrı).
(String, String) v21DailyLines(DailyStatus d) {
  final sandik = DailyPanelTexts.sandikAdi(d.chestType);
  final seri = d.streak > 0 ? ' · Seri ${d.streak}' : '';
  return (
    d.claimedToday ? 'Sandık alındı$seri' : '$sandik sandık hazır$seri',
    d.firstWinToday ? 'Günün ilk galibiyet bonusu alındı' : 'Günün ilk galibiyeti: ${d.firstWinMultiplier} kat XP',
  );
}

/// 044: V2.1 ANA SAYFA GÜNLÜK ŞERİDİ: ücretsiz günlük sandık ve ilk galibiyet
/// bonusu. Anahtar kapalıysa ya da servis yoksa hiç yer kaplamaz.
class V21DailyStrip extends StatefulWidget {
  final double scale;

  /// Yan boşluk (geniş yerleşimde sütun zaten dar: 0)
  final double? sidePadding;

  /// Yalnız testler: sunucuya gitmeden gösterilecek durum
  @visibleForTesting
  final DailyStatus? debugStatus;

  const V21DailyStrip({super.key, required this.scale, this.sidePadding, this.debugStatus});

  @override
  State<V21DailyStrip> createState() => _V21DailyStripState();
}

class _V21DailyStripState extends State<V21DailyStrip> {
  DailyStatus? _durum;
  bool _aliniyor = false;

  DailyLoopService? get _servis => getIt.isRegistered<DailyLoopService>() ? getIt<DailyLoopService>() : null;

  @override
  void initState() {
    super.initState();
    _durum = widget.debugStatus;
    if (widget.debugStatus == null) _yukle();
  }

  Future<void> _yukle() async {
    final d = await _servis?.status();
    if (mounted) setState(() => _durum = d);
  }

  Future<void> _al() async {
    final s = _servis;
    if (s == null || _aliniyor) return;
    setState(() => _aliniyor = true);
    try {
      final r = await s.claim();
      if (mounted) {
        final tur = DailyPanelTexts.sandikAdi(r['chest_type']?.toString() ?? 'bronze');
        AppSnackBar.showInfo(context, '$tur sandığın Sandıklar bölümüne eklendi.');
      }
      chestInventoryChanged.value++;
    } catch (_) {
      if (mounted) AppSnackBar.showInfo(context, 'Sandık alınamadı. Tekrar dene.');
    }
    if (mounted) setState(() => _aliniyor = false);
    await _yukle();
  }

  @override
  Widget build(BuildContext context) {
    final d = _durum;
    if (d == null || !d.enabled) return const SizedBox.shrink();
    final k = widget.scale;
    final (ust, alt) = v21DailyLines(d);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        widget.sidePadding ?? V21Metrics.primaryButtonSide * k,
        8 * k,
        widget.sidePadding ?? V21Metrics.primaryButtonSide * k,
        0,
      ),
      child: V21GamePanel(
        style: V21PanelStyle.slot,
        scale: k,
        padding: EdgeInsets.symmetric(horizontal: 10 * k, vertical: 6 * k),
        child: Row(
          children: [
            Icon(Icons.card_giftcard_rounded, size: 22 * k, color: V21Colors.coin),
            SizedBox(width: 8 * k),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ust, maxLines: 1, overflow: TextOverflow.ellipsis, style: V21Type.label(12 * k)),
                  Text(alt, maxLines: 1, overflow: TextOverflow.ellipsis, style: V21Type.label(10 * k, color: V21Colors.textMuted)),
                ],
              ),
            ),
            if (!d.claimedToday) ...[
              SizedBox(width: 8 * k),
              SizedBox(
                width: 72 * k,
                child: V21GameButton(
                  label: 'AL',
                  tone: V21ButtonTone.green,
                  size: V21ButtonSize.small,
                  scale: k,
                  semanticsLabel: 'Günlük sandığı al',
                  status: _aliniyor ? V21ButtonStatus.disabled : V21ButtonStatus.normal,
                  onPressed: _al,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
