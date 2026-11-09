import 'package:flutter/material.dart';

import '../../../core/theme/ref_tokens.dart';
import '../ref/ref_ui.dart';

/// OYUN LOGOSU — "FUTBOL / CARD ARENA".
///
/// Açılış, giriş ve kayıt ekranlarında aynı logo. FAZ 8: referans
/// HTML'in marka işaretiyle (.brandmark: 🏆 + italik "FUTBOL" beyaz,
/// "CARD ARENA" altın) aynı; masaüstü kenar çubuğundaki logoyla da
/// birebir. Görsel dosya yok, her çözünürlükte net.
class GameLogo extends StatelessWidget {
  /// Logo yazısının boyutu
  final double size;

  /// Alt satırda slogan gösterilsin mi?
  final bool showTagline;

  const GameLogo({super.key, this.size = 44, this.showTagline = true});

  @override
  Widget build(BuildContext context) {
    final yazi = Ref.heading(size, weight: FontWeight.w900, height: 0.94).copyWith(fontStyle: FontStyle.italic);

    return Semantics(
      header: true,
      label: 'Futbol Card Arena',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RefDropShadow(
            color: const Color(0x66F8C665),
            offset: const Offset(0, 6),
            blur: 18,
            child: Em('🏆', size: size * 1.3),
          ),
          SizedBox(height: size * 0.12),
          // Dar ekranda ya da büyük yazı ölçeğinde taşmasın
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'FUTBOL\n'),
                TextSpan(text: 'CARD ARENA', style: yazi.copyWith(color: Ref.gold)),
              ]),
              textAlign: TextAlign.center,
              style: yazi,
            ),
          ),
          if (showTagline) ...[
            SizedBox(height: size * 0.28),
            Text(
              'Aynı mevki. Daha güçlü kart. Tek kazanan.',
              textAlign: TextAlign.center,
              style: Ref.bodyText(12, color: Ref.muted),
            ),
          ],
        ],
      ),
    );
  }
}
