import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:shared_models/shared_models.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/audio/sound_cues.dart';
import '../../../features/chests/domain/chest_texts.dart';
import '../../ui_v21.dart';

/// V2.1 SANDIK AÇILIŞI (paket açılışından ayrı sahne; referansın kutlama
/// dili: ışın arka planı, altın başlık, ödül kartları).
///
///   ALTIN SANDIK AÇILDI!   sandık 3 kez sallanır ve büyür
///   kartlar sırayla belirir: YENİ / +1 GELİŞİM / KADRO KORUMASI / JOKER
///   ödül kartları: +altın, joker parça, ek eşya   ·   [ TAMAM ]
///
/// Sonuç sunucudan gelmiştir. Animasyon azaltılmışsa ya da "Kart parıltısı"
/// kapalıysa sahne doğrudan son hâlinde açılır; dokunma animasyonu atlar.
class V21ChestOpening extends StatefulWidget {
  final ChestOpenResult result;
  final VoidCallback onClose;
  const V21ChestOpening({super.key, required this.result, required this.onClose});

  @override
  State<V21ChestOpening> createState() => _V21ChestOpeningState();
}

class _V21ChestOpeningState extends State<V21ChestOpening> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
  // Zaman çizelgesiyle aynı noktalar: 3 sallanma, kapak, kartlar, özet
  SoundCues _cues() => SoundCues(_a, [
    (0.0, Sfx.chestShake),
    (0.083, Sfx.chestShake),
    (0.166, Sfx.chestShake),
    (0.22, Sfx.chestOpen),
    for (var i = 0; i < widget.result.cards.length; i++) (0.4 + i * 0.15, Sfx.chestReward),
    (0.8, Sfx.coins),
  ]);
  SoundCues? _sounds;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (V21Motion.cardEffects(context)) {
      _sounds = _cues();
      _a.forward();
    } else {
      // Animasyon kapalı: sahne son hâlinde açılır, tek açılış sesi yeter
      GameAudio.sfx(Sfx.chestOpen);
      _a.value = 1;
    }
  }

  @override
  void dispose() {
    _sounds?.dispose();
    _a.dispose();
    super.dispose();
  }

  double _span(double from, double to, [Curve curve = Curves.easeOutCubic]) =>
      curve.transform(((_a.value - from) / (to - from)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    return Theme(
      data: V21Theme.data(context),
      child: Scaffold(
        backgroundColor: V21Colors.inkDeep,
        body: LayoutBuilder(
          builder: (context, c) {
            final k = V21Scale.forSize(c.biggest).s;
            return Stack(
              children: [
                const Positioned.fill(child: V21RaysBackground()),
                SafeArea(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _a.value < 1 ? _a.value = 1 : null,
                    child: AnimatedBuilder(animation: _a, builder: (context, _) => _content(context, r, k, c.maxWidth)),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _content(BuildContext context, ChestOpenResult r, double k, double width) {
    final shake = _span(0, 0.25, Curves.linear);
    final open = _span(0.22, 0.42);
    final content = math.min(width, V21Metrics.maxContentWidth * k);
    final cardW = ((content - 32 * k - 16 * k) / 3).clamp(0.0, 150 * k);
    final summary = _span(0.8, 1);
    return Center(
      child: SizedBox(
        width: content,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16 * k, 18 * k, 16 * k, 24 * k),
          children: [
            Text(
              'SANDIK AÇILDI',
              textAlign: TextAlign.center,
              style: V21Type.title(18 * k, color: const Color(0xFFFFE6A0)),
            ),
            Center(child: V21HeroTitle('${V21Format.upper(ChestTypes.name(r.chestType))}!', size: 54 * k)),
            SizedBox(height: 6 * k),
            Center(
              child: Transform.rotate(
                // 3 kez sallanır, kapak açılınca durur ve büyür
                angle: math.sin(shake * math.pi * 6) * 0.08 * (1 - open),
                child: Transform.scale(
                  scale: 0.9 + 0.15 * open,
                  child: V21ChestArt.tier(r.chestType, height: 140 * k, glowing: open > 0.5),
                ),
              ),
            ),
            SizedBox(height: 12 * k),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < r.cards.length; i++) ...[
                  if (i > 0) SizedBox(width: 8 * k),
                  _ChestCardReveal(card: r.cards[i], width: cardW, t: _span(0.4 + i * 0.15, 0.62 + i * 0.15)),
                ],
              ],
            ),
            SizedBox(height: 16 * k),
            Opacity(
              opacity: summary,
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 10 * k,
                runSpacing: 10 * k,
                children: [
                  V21RewardCard.coins(r.coins, scale: k),
                  // 056: sandıktan elmas
                  if (r.gems > 0)
                    V21RewardCard(
                      icon: V21GemIcon(size: 46 * k),
                      value: '+${r.gems}',
                      label: 'ELMAS',
                      scale: k,
                    ),
                  if (r.jokers.values.any((v) => v > 0))
                    V21RewardCard(
                      icon: V21ItemArt(
                        category: 'joker',
                        tier: r.jokers.entries.where((e) => e.value > 0).map((e) => e.key).lastOrNull,
                        size: 48 * k,
                      ),
                      value: '+${r.jokers.values.fold<int>(0, (a, b) => a + b)}',
                      label: 'JOKER',
                      scale: k,
                    ),
                  if (r.extras.values.any((v) => v > 0))
                    V21RewardCard(
                      icon: Icon(Icons.card_giftcard_rounded, size: 46 * k, color: const Color(0xFFFFC832)),
                      value: '+${r.extras.values.fold<int>(0, (a, b) => a + b)}',
                      label: 'EŞYA',
                      scale: k,
                    ),
                ],
              ),
            ),
            SizedBox(height: 10 * k),
            Opacity(
              opacity: summary,
              child: Text(
                [
                  if (r.coinsAfter != null) 'Bakiye ${V21Format.thousands(r.coinsAfter!)} altın',
                  if (r.jokers.isNotEmpty) 'Joker: ${jokerSummary(r.jokers)}',
                  if (r.extras.isNotEmpty) 'Ek ödül: ${extrasSummary(r.extras)}',
                  _explain(r),
                ].join('\n'),
                textAlign: TextAlign.center,
                style: V21Type.label(12 * k, weight: FontWeight.w700, color: const Color(0xFFE3D6FF), height: 1.45),
              ),
            ),
            SizedBox(height: 18 * k),
            V21GameButton(label: 'TAMAM', size: V21ButtonSize.large, scale: k, onPressed: widget.onClose),
          ],
        ),
      ),
    );
  }

  static String _explain(ChestOpenResult r) {
    final copies = r.cards.where((c) => c.isCopy).length;
    final guard = r.cards.where((c) => c.isSquadGuard).length;
    return [
      if (copies > 0) '+1 GELİŞİM: zaten sahip olduğun futbolcunun gelişim kopyası.',
      if (guard > 0) 'KADRO KORUMASI: kadronda eksik olan mevkiden kart verildi.',
      if (copies == 0 && guard == 0) 'Kartlar koleksiyonuna eklendi.',
    ].join(' ');
  }
}

class _ChestCardReveal extends StatelessWidget {
  final ChestCard card;
  final double width;
  final double t;
  const _ChestCardReveal({required this.card, required this.width, required this.t});

  @override
  Widget build(BuildContext context) {
    final k = width / 120;
    final (label, color) = switch (card.outcome) {
      ChestCardOutcome.isNew => ('YENİ', V21Colors.success),
      ChestCardOutcome.copy => ('+1 GELİŞİM', const Color(0xFF3FA2F5)),
      ChestCardOutcome.squadGuard => ('KADRO KORUMASI', const Color(0xFFFF9500)),
      ChestCardOutcome.joker => ('JOKER', const Color(0xFFB98AF0)),
      _ => ('KART', V21Colors.dash),
    };
    return Opacity(
      opacity: t,
      child: Transform.translate(
        offset: Offset(0, (1 - t) * 30),
        child: Transform.scale(
          scale: 0.85 + 0.15 * t,
          child: Semantics(
            label: '${card.fullName}, ${V21Rarity.of(card.tier).name}, $label',
            excludeSemantics: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                V21PlayerCard(
                  name: card.fullName,
                  position: card.position,
                  tier: card.tier,
                  power: card.power,
                  width: width,
                ),
                SizedBox(height: 6 * k),
                SizedBox(
                  width: width,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: V21Tag(text: label, background: color, foreground: Colors.white, scale: k),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
