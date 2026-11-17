import 'package:flutter/material.dart';

import '../foundation/v21_colors.dart';
import '../foundation/v21_metrics.dart';
import '../foundation/v21_typography.dart';
import 'v21_progress_bar.dart';

/// V2.1 ORTAK ÜST BAŞLIK (referans 0..390 × 14..58).
///
///   [seviye dairesi]  kullanıcı adı              [kaynak hapları]
///                     ▀▀▀▀▀▀ ilerleme
///
/// [level] null ise dairede sayı yerine kişi simgesi; [levelProgress]
/// null ise çubuk çizilmez. Değerler hep sunucudan gelir.
class V21GameHeader extends StatelessWidget {
  final String username;
  final int? level;
  final double? levelProgress;

  /// "Sezon kademesi" gibi: ekran okuyucu için seviyenin anlamı
  final String levelMeaning;

  /// Sağdaki kaynak hapları (altın vb.)
  final List<Widget> trailing;
  final VoidCallback? onProfileTap;
  final double scale;

  const V21GameHeader({
    super.key,
    required this.username,
    this.level,
    this.levelProgress,
    this.levelMeaning = 'Seviye',
    this.trailing = const [],
    this.onProfileTap,
    this.scale = 1,
  });

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final profil = Semantics(
      button: onProfileTap != null,
      label: ['Profil: $username', if (level != null) '$levelMeaning $level'].join(', '),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onProfileTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            V21LevelBadge(level: level, scale: k),
            SizedBox(width: 10 * k),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: V21Type.title(
                      18 * k,
                      weight: FontWeight.w800,
                      letterSpacing: 0.2,
                      shadows: V21Type.inkShadow(k * 0.7),
                    ),
                  ),
                  if (levelProgress != null) ...[
                    SizedBox(height: 3 * k),
                    SizedBox(
                      width: 110 * k,
                      child: V21ProgressBar(value: levelProgress!, height: 9 * k),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return SizedBox(
      height: V21Metrics.headerHeight * k,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: V21Metrics.headerSidePadding * k,
        ).copyWith(top: 12 * k, bottom: 2 * k, right: 5 * k),
        child: Row(
          children: [
            Expanded(
              child: Align(alignment: Alignment.centerLeft, child: profil),
            ),
            for (final w in trailing) ...[SizedBox(width: 8 * k), w],
          ],
        ),
      ),
    );
  }
}

/// Mavi seviye dairesi (referans çap 44, 3 px lacivert halka)
class V21LevelBadge extends StatelessWidget {
  final int? level;
  final double scale;
  const V21LevelBadge({super.key, required this.level, this.scale = 1});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final d = V21Metrics.levelBadge * k;
    return Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: V21Colors.ink, width: 3 * k),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF6FB3FF), V21Colors.levelBlue, Color(0xFF3C7FEA)],
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 6 * k, offset: Offset(0, 2 * k)),
        ],
      ),
      alignment: Alignment.center,
      child: level == null
          ? Icon(Icons.person_rounded, color: Colors.white, size: d * 0.6)
          : Padding(
              padding: EdgeInsets.all(4 * k),
              child: FittedBox(
                child: Text('$level', style: V21Type.title(24 * k, shadows: V21Type.inkShadow(k * 0.8))),
              ),
            ),
    );
  }
}
