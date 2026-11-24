import 'package:material_ui/material_ui.dart';
import 'package:shared_models/shared_models.dart';

import '../foundation/v21_colors.dart';
import '../foundation/v21_typography.dart';
import 'v21_feedback.dart';
import 'v21_game_button.dart';
import 'v21_painters.dart';

/// V2.1 GEÇERSİZ KADRO UYARISI (referans hf17 "KADRO EKSİK").
///
///   KADRO EKSİK   (sunucu reddinde: KADRO GEÇERSİZ + sunucu mesajı)
///   Maça çıkmak için 11 geçerli kart gerekli.
///   ── EKSİK MEVKİLER ──
///   [ ? DEF ×1 ] [ ? FWD ×2 ]
///   [ KADROYU DÜZENLE ]
///   [ KAPAT ]
///
/// Eksik mevki sayıları çağıran ekrandan gelir (Kadrom'da yerel sayım;
/// sunucu doğrulaması reddederse onun mesajı [message] olarak gösterilir).
/// `true` dönerse oyuncu KADROYU DÜZENLE'yi seçti.
abstract final class V21SquadWarning {
  static Future<bool> show(BuildContext context, {required Map<CardPosition, int> missing, String? message}) async {
    final entries = [
      for (final p in CardPosition.values)
        if ((missing[p] ?? 0) > 0) (p, missing[p]!),
    ];
    final r = await V21GameDialog.show<bool>(
      context,
      title: message == null ? 'KADRO EKSİK' : 'KADRO GEÇERSİZ',
      icon: const _Crest(),
      message: message ?? 'Maça çıkmak için ${GameRules.squadSize} geçerli kart gerekli.',
      content: entries.isEmpty ? null : MissingPositions(entries: entries),
      actions: const [
        V21DialogAction('KADROYU DÜZENLE', tone: V21ButtonTone.gold, result: true),
        V21DialogAction('KAPAT', tone: V21ButtonTone.blue, result: false),
      ],
    );
    return r ?? false;
  }
}

class _Crest extends StatelessWidget {
  const _Crest();

  @override
  Widget build(BuildContext context) => const ExcludeSemantics(
    child: SizedBox(
      width: 56,
      height: 62,
      child: ClipPath(
        clipper: V21ShieldClipper(),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF7B4FE0), Color(0xFF3B1C8C)],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Icon(Icons.sports_soccer_rounded, size: 30, color: V21Colors.goldTop),
          ),
        ),
      ),
    ),
  );
}

/// "EKSİK MEVKİLER" kutusu: her eksik mevki için boş kart yuvası
class MissingPositions extends StatelessWidget {
  final List<(CardPosition, int)> entries;
  const MissingPositions({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Eksik mevkiler: ${entries.map((e) => '${e.$2} ${e.$1.label.toLowerCase()}').join(', ')}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        decoration: BoxDecoration(
          color: const Color(0x66120933),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x557B56C9), width: 1.5),
        ),
        child: Column(
          children: [
            Text(
              'EKSİK MEVKİLER',
              style: V21Type.label(12, weight: FontWeight.w900, color: const Color(0xFFFEDB70), letterSpacing: 1.2),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [for (final (p, n) in entries) _Slot(position: p, count: n)],
            ),
          ],
        ),
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  final CardPosition position;
  final int count;
  const _Slot({required this.position, required this.count});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 70,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              foregroundPainter: const V21DashedRRectPainter(color: Color(0xFF8F7BD6), radius: 9),
              child: DecoratedBox(
                decoration: BoxDecoration(color: const Color(0xFF2A1866), borderRadius: BorderRadius.circular(9)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 24, color: Color(0xFFB9A8F0)),
                    Text(position.code, style: V21Type.title(14, color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
          if (count > 1)
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: V21Colors.danger, borderRadius: BorderRadius.circular(10)),
                child: Text(
                  '×$count',
                  style: V21Type.label(11, weight: FontWeight.w900, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
