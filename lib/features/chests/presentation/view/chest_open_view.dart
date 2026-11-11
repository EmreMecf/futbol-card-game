import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/feedback/game_feedback.dart';
import '../../../../core/theme/ref_tokens.dart';
import '../../../../core/utils/turkish_text.dart';
import '../../../../shared/widgets/ref/ref_ui.dart';
import '../../../../shared/widgets/ref_card/ref_player_card.dart';
import '../widgets/chest_widgets.dart';

/// SANDIK AÇILIŞI — paket açılışından AYRI bir sahne.
///
/// Sonuç sunucudan gelmiştir (ekran yalnız gösterir). Sıra: sandık
/// sallanır ve kapağı açılır -> 3 kart sırayla belirir (her kartta
/// YENİ / +1 GELİŞİM / KADRO KORUMASI) -> altın ve joker özeti.
/// "Kart animasyonları" kapalıysa sahne doğrudan son hâlinde açılır.
class ChestOpenView extends StatefulWidget {
  final ChestOpenResult result;
  final VoidCallback onClose;

  const ChestOpenView({super.key, required this.result, required this.onClose});

  @override
  State<ChestOpenView> createState() => _ChestOpenViewState();
}

class _ChestOpenViewState extends State<ChestOpenView> with SingleTickerProviderStateMixin {
  late final AnimationController _a;

  @override
  void initState() {
    super.initState();
    _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
    if (GameFeedback.cardAnimationsEnabled) {
      _a.forward();
    } else {
      _a.value = 1;
    }
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  double _aralik(double bas, double son, [Curve egri = Curves.easeOutCubic]) =>
      egri.transform(((_a.value - bas) / (son - bas)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final renk = chestColor(r.chestType);
    return Scaffold(
      backgroundColor: Ref.phoneBg,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Dokunma animasyonu atlatır
          onTap: () => _a.value < 1 ? _a.value = 1 : null,
          child: AnimatedBuilder(
            animation: _a,
            builder: (context, _) {
              final sallan = _aralik(0, 0.25, Curves.linear);
              final kapak = _aralik(0.22, 0.42);
              return LayoutBuilder(builder: (context, k) {
                final genislik = k.maxWidth.clamp(0.0, 620.0);
                final kartG = ((genislik - 28 - 16) / 3).clamp(0.0, 170.0);
                return ListView(
                  padding: Ref.pagePadding,
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 620),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Text('SANDIK AÇILDI',
                              textAlign: TextAlign.center, style: Ref.caps(Ref.gold)),
                          const SizedBox(height: 4),
                          Text('${ChestTypes.name(r.chestType).toUpperTr()} SANDIK',
                              textAlign: TextAlign.center, style: Ref.heading(30, color: renk)),
                          const SizedBox(height: 10),
                          Center(
                            child: Transform.rotate(
                              // Açılmadan önce 3 kez sallanır, kapak açılınca durur
                              angle: math.sin(sallan * math.pi * 6) * 0.08 * (1 - kapak),
                              child: ChestIcon(type: r.chestType, size: 110, open: kapak, glow: kapak > 0),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            for (var i = 0; i < r.cards.length; i++) ...[
                              if (i > 0) const SizedBox(width: 8),
                              Expanded(child: _Kart(card: r.cards[i], width: kartG, t: _aralik(0.4 + i * 0.15, 0.62 + i * 0.15))),
                            ],
                          ]),
                          const SizedBox(height: Ref.pageGap),
                          Opacity(
                            opacity: _aralik(0.8, 1),
                            child: RefCardPanel(children: [
                              Row(children: [
                                const CoinGlyph(size: 18),
                                const SizedBox(width: 8),
                                Expanded(child: Text('+${trThousands(r.coins)} altın', style: Ref.bodyText(14, color: Ref.gold, weight: FontWeight.w900))),
                                if (r.coinsAfter != null)
                                  Text('Bakiye ${trThousands(r.coinsAfter!)}', style: Ref.tiny(Ref.muted)),
                              ]),
                              if (r.jokers.isNotEmpty)
                                Row(children: [
                                  const Icon(Icons.extension_rounded, size: 17, color: Ref.purple),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text('Joker parça: ${jokerSummary(r.jokers)}',
                                        style: Ref.bodyText(12, weight: FontWeight.w700)),
                                  ),
                                ]),
                              // 038: ek item ödülleri (sandık anahtarı, ustalık kitabı)
                              if (r.extras.isNotEmpty)
                                Row(children: [
                                  const Icon(Icons.card_giftcard_rounded, size: 17, color: Ref.gold),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text('Ek ödül: ${extrasSummary(r.extras)}',
                                        style: Ref.bodyText(12, weight: FontWeight.w700)),
                                  ),
                                ]),
                              ChestHint(_aciklama(r)),
                            ]),
                          ),
                          const SizedBox(height: Ref.pageGap),
                          RefCta('TAMAM', fontSize: 21, onTap: widget.onClose),
                        ]),
                      ),
                    ),
                  ],
                );
              });
            },
          ),
        ),
      ),
    );
  }

  static String _aciklama(ChestOpenResult r) {
    final kopya = r.cards.where((k) => k.isCopy).length;
    final koruma = r.cards.where((k) => k.isSquadGuard).length;
    return [
      if (kopya > 0) '+1 GELİŞİM: zaten sahip olduğun futbolcunun gelişim kopyası; seviye sistemi açılınca kullanılır.',
      if (koruma > 0) 'KADRO KORUMASI: kadronda eksik olan mevkiden kart verildi.',
      if (kopya == 0 && koruma == 0) 'Kartlar koleksiyonuna eklendi.',
    ].join(' ');
  }
}

class _Kart extends StatelessWidget {
  final ChestCard card;
  final double width;
  final double t;
  const _Kart({required this.card, required this.width, required this.t});

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 30),
          child: Transform.scale(
            scale: 0.85 + 0.15 * t,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              RefPlayerCard(
                name: card.fullName,
                position: card.position,
                tier: card.tier,
                power: card.power,
                seed: card.cardId,
                kitSeed: card.club ?? card.nationality,
                imageUrl: card.imageUrl,
                width: width,
              ),
              const SizedBox(height: 6),
              ChestOutcomePill(card.outcome),
            ]),
          ),
        ),
      );
}
