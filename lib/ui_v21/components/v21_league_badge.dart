import 'package:flutter/material.dart';

import '../foundation/v21_colors.dart';
import '../foundation/v21_metrics.dart';
import '../foundation/v21_typography.dart';
import '../utilities/v21_format.dart';
import 'v21_painters.dart';
import 'v21_progress_bar.dart';

/// V2.1 LİG ROZETİ (referans 62..315 × 72..143):
/// mor kalkan ("M2") + altın panel (lig adı, puan, ilerleme).
///
/// Bütün değerler sunucunun `PlayerRank` cevabından gelir; [code] ve
/// [title] null ise (yükleniyor / alınamadı) yer tutucu çizilir, sayı
/// uydurulmaz.
class V21LeagueBadge extends StatelessWidget {
  /// Kalkandaki kısa kod: "M2", "MC1"
  final String? code;

  /// "MASTER 2"
  final String? title;

  /// Lig puanı (MMR)
  final int? points;

  /// Basamak içi ilerleme 0..1
  final double progress;

  /// Ekran okuyucu ek bilgisi ("50 puan sonra Master 3")
  final String? detail;
  final VoidCallback? onTap;
  final double scale;

  const V21LeagueBadge({
    super.key,
    required this.code,
    required this.title,
    required this.points,
    required this.progress,
    this.detail,
    this.onTap,
    this.scale = 1,
  });

  /// Lig kodu + basamak → "M2". Sunucu kodları: amateur, usta, master,
  /// master_class.
  static String shortCode(String leagueCode, int division) {
    final harf = switch (leagueCode) {
      'amateur' => 'A',
      'usta' => 'U',
      'master' => 'M',
      'master_class' => 'MC',
      _ => leagueCode.isEmpty ? '?' : leagueCode[0].toUpperCase(),
    };
    return '$harf$division';
  }

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final w = V21Metrics.leagueBadgeWidth * k;
    final h = V21Metrics.leagueBadgeHeight * k;
    final shieldW = 56 * k;
    final loading = title == null;

    final panel = Container(
      margin: EdgeInsets.only(left: 48 * k, top: 8 * k, bottom: 1 * k),
      padding: EdgeInsets.fromLTRB(15 * k, 4 * k, 14 * k, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12 * k),
        border: Border.all(color: V21Colors.ink, width: 3 * k),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [V21Colors.badgeGoldTop, V21Colors.badgeGoldBottom],
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 8 * k, offset: Offset(0, 3 * k)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    loading ? 'LİG' : title!,
                    maxLines: 1,
                    style: V21Type.title(26 * k, letterSpacing: 0.2, shadows: V21Type.inkShadow(k)),
                  ),
                ),
              ),
              if (points != null)
                Padding(
                  padding: EdgeInsets.only(right: 10 * k, left: 6 * k),
                  child: Text(
                    V21Format.thousands(points!),
                    style: V21Type.label(
                      12 * k,
                      weight: FontWeight.w800,
                      color: Colors.white,
                      shadows: V21Type.inkShadow(k * 0.6),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 5 * k),
          V21ProgressBar(
            value: progress,
            height: 12 * k,
            trackColor: V21Colors.trackBrown,
            semanticsLabel: 'Lig ilerlemesi',
          ),
        ],
      ),
    );

    final shield = SizedBox(
      width: shieldW,
      height: h,
      child: ClipPath(
        clipper: const V21ShieldClipper(),
        child: DecoratedBox(
          decoration: const BoxDecoration(color: V21Colors.ink),
          child: Padding(
            padding: EdgeInsets.all(3 * k),
            child: ClipPath(
              clipper: const V21ShieldClipper(),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [V21Colors.shieldTop, V21Colors.shieldBottom],
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(4 * k, 0, 4 * k, 4 * k),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(code ?? '?', style: V21Type.title(28 * k, shadows: V21Type.inkShadow(k))),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return Semantics(
      button: onTap != null,
      label: loading
          ? 'Lig bilgisi yükleniyor'
          : ['Lig: $title', if (points != null) '${V21Format.thousands(points!)} puan', ?detail].join(', '),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: w,
          height: h,
          child: Stack(
            children: [
              Positioned.fill(child: panel),
              Positioned(left: 0, top: 0, bottom: 0, child: shield),
            ],
          ),
        ),
      ),
    );
  }
}
