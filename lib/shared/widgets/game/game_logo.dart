import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';

/// OYUN LOGOSU — "FUTBOL / CARD ARENA".
///
/// Açılış, giriş ve kayıt ekranlarında aynı logo. Görsel dosya yok:
/// kupa simgesi + Barlow Condensed italik. Böylece her çözünürlükte
/// net ve uygulama paketine ek yük getirmiyor.
///
/// NOT: Gerçek bir logo tasarımı yapıldığında (SVG/PNG) yalnızca bu
/// sınıfın içi değişecek; üç ekran da kendiliğinden güncellenecek.
class GameLogo extends StatelessWidget {
  /// Logo yüksekliğini belirleyen ölçek (yazı boyutu buna oranlı)
  final double size;

  /// Alt satırda slogan gösterilsin mi?
  final bool showTagline;

  const GameLogo({super.key, this.size = 44, this.showTagline = true});

  @override
  Widget build(BuildContext context) {
    final yazi = AppTypography.display(
      size: size,
      weight: FontWeight.w900,
      height: 0.92,
      letterSpacing: 0.5,
    ).copyWith(fontStyle: FontStyle.italic);

    return Semantics(
      header: true,
      label: 'Futbol Card Arena',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ---- Kupa ----
          Container(
            padding: EdgeInsets.all(size * 0.28),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.victoryGold.withValues(alpha: 0.28),
                  AppColors.victoryGold.withValues(alpha: 0),
                ],
              ),
            ),
            child: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (r) => AppGradients.cta.createShader(r),
              child: Icon(Icons.emoji_events_rounded, size: size * 1.35),
            ),
          ),
          SizedBox(height: size * 0.18),
          Text('FUTBOL', style: yazi, textAlign: TextAlign.center),
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (r) => AppGradients.progressGold.createShader(r),
            child: Text('CARD ARENA', style: yazi, textAlign: TextAlign.center),
          ),
          if (showTagline) ...[
            SizedBox(height: size * 0.28),
            Text(
              'Aynı mevki. Daha güçlü kart. Tek kazanan.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyS,
            ),
          ],
        ],
      ),
    );
  }
}
