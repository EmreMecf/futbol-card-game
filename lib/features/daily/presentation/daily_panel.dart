import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../../core/di/injection.dart';
import '../../../core/theme/ref_tokens.dart';
import '../../../shared/widgets/error_snackbar.dart';
import '../../../shared/widgets/ref/ref_ui.dart';
import '../../chests/presentation/widgets/chest_strip.dart';
import '../data/daily_service.dart';

/// 044: ANA SAYFA GÜNLÜK PANELİ — ücretsiz günlük sandık (seri: her 3.
/// gün Gümüş) ve günün ilk galibiyeti (çift sezon XP'si).
///
/// Servis kayıtlı değilse (testler) ya da anahtar kapalıysa HİÇ yer kaplamaz.
class DailyPanel extends StatefulWidget {
  const DailyPanel({super.key});

  @override
  State<DailyPanel> createState() => _DailyPanelState();
}

class _DailyPanelState extends State<DailyPanel> {
  DailyStatus? _durum;
  bool _aliniyor = false;

  DailyLoopService? get _servis => getIt.isRegistered<DailyLoopService>() ? getIt<DailyLoopService>() : null;

  @override
  void initState() {
    super.initState();
    _yukle();
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
        final tur = r['chest_type'] == 'silver' ? 'Gümüş' : 'Bronz';
        AppSnackBar.showInfo(context, '$tur sandığın Sandıklar bölümüne eklendi.');
      }
      // Ana sayfadaki sandık şeridi yeni sandığı hemen göstersin
      chestInventoryChanged.value++;
    } catch (e) {
      if (mounted) AppSnackBar.showInfo(context, 'Sandık alınamadı. Tekrar dene.');
    }
    if (mounted) setState(() => _aliniyor = false);
    await _yukle();
  }

  @override
  Widget build(BuildContext context) {
    final d = _durum;
    if (d == null || !d.enabled) return const SizedBox.shrink();
    final (sandik, galibiyet) = DailyPanelTexts.texts(d);
    return Padding(
      padding: const EdgeInsets.only(bottom: Ref.pageGap),
      child: RefCardPanel(children: [
        Row(children: [
          const Em('🎁', size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text('GÜNLÜK', style: Ref.caps(Ref.gold))),
          const RefPill('Her 3. gün Gümüş'),
        ]),
        Text(sandik, style: Ref.bodyText(12, weight: FontWeight.w700)),
        Text(galibiyet, style: Ref.bodyText(11, color: Ref.muted, height: 1.4)),
        if (!d.claimedToday)
          RefSecondaryButton(_aliniyor ? 'ALINIYOR…' : 'GÜNLÜK SANDIĞI AL', onTap: _aliniyor ? null : _al),
      ]),
    );
  }
}

/// Günlük panel metinleri (test edilebilsin diye ayrı)
abstract final class DailyPanelTexts {
  static String sandikAdi(String t) => t == 'silver' ? 'Gümüş' : 'Bronz';

  static (String, String) texts(DailyStatus d) {
    final sandik = d.claimedToday
        ? 'Bugünkü ${sandikAdi(d.chestType)} sandığı alındı. Seri: ${d.streak} gün.'
        : 'Bugün ücretsiz ${sandikAdi(d.chestType)} sandık seni bekliyor.'
            // yeni oyuncuya "Seri: 0 gün" gösterme
            '${d.streak > 0 ? ' Seri: ${d.streak} gün.' : ''}';
    final galibiyet = d.firstWinToday
        ? 'Günün ilk galibiyeti alındı (çift XP).'
        : 'Günün ilk dereceli galibiyeti ${d.firstWinMultiplier} kat sezon XP\'si verir.';
    return (sandik, galibiyet);
  }
}
