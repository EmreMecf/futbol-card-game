import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/feedback/game_feedback.dart';
import '../../../../core/theme/ref_tokens.dart';
import '../../../../core/utils/turkish_text.dart';
import '../../../../shared/widgets/ref/ref_ui.dart';
import '../../../../shared/widgets/ref_card/ref_player_card.dart';
import '../../../../shared/widgets/walkout/confetti_overlay.dart';
import '../viewmodel/match_view_model.dart';
import 'league_change_widgets.dart';

/// MAÇ SONUCU — referans `result()` ekranı.
///
///   .winpanel   caps "MAÇ SONUCU", 🏆 / 🛡️ / 🤝 (92px), h1 50px
///               ZAFER! / MÜCADELE BİTTİ / BERABERLİK, skor 49px,
///               "SEN · RAKİP", .rewardrow (altın · puan · koruma), YENİ MAÇ ▶
///   .neutral-button  ANA MENÜYE DÖN
///
/// GERÇEK VERİ: skor, rakip ve el değiştiren kartlar sunucunun maç
/// özetinden; ödül kutuları oyuncunun maç öncesi/sonrası sayaç farkından
/// ([MatchRewardDelta]). Fark bilinmiyorsa kutular hiç çizilmez
/// (referanstaki "+500 XP" gibi oyunda olmayan bir değer gösterilmez).
/// Lig değişimi paneli ve lig atlama kutlaması (oyunda gerçek) korunur.
class MatchResultView extends StatefulWidget {
  final MatchResultSummary? result;
  final MatchRewardDelta? rewardDelta;
  final VoidCallback onClose;

  /// Verilmezse "YENİ MAÇ" butonu gösterilmez
  final VoidCallback? onNewMatch;

  const MatchResultView({
    super.key,
    required this.result,
    required this.onClose,
    this.rewardDelta,
    this.onNewMatch,
  });

  @override
  State<MatchResultView> createState() => _MatchResultViewState();
}

class _MatchResultViewState extends State<MatchResultView> with SingleTickerProviderStateMixin {
  late final AnimationController _giris;
  bool _titredi = false;
  bool _terfiKapandi = false;

  @override
  void initState() {
    super.initState();
    // Galibiyet vurgusu 500-800 ms
    _giris = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
    if (GameFeedback.cardAnimationsEnabled) {
      _giris.forward();
    } else {
      _giris.value = 1;
    }
  }

  @override
  void didUpdateWidget(MatchResultView eski) {
    super.didUpdateWidget(eski);
    _titret();
  }

  void _titret() {
    final s = widget.result;
    if (_titredi || s == null) return;
    _titredi = true;
    GameFeedback.haptic(
      s.didIWin ? HapticStrength.heavy : (s.isDraw ? HapticStrength.light : HapticStrength.medium),
    );
  }

  @override
  void dispose() {
    _giris.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sonuc = widget.result;
    if (sonuc == null) {
      return const Scaffold(
        backgroundColor: Ref.phoneBg,
        body: Center(child: CircularProgressIndicator(color: Ref.accent)),
      );
    }
    _titret();

    return Scaffold(
      backgroundColor: Ref.phoneBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (sonuc.didIWin)
            ConfettiOverlay(
              active: GameFeedback.cardAnimationsEnabled,
              colors: const [Ref.gold, Ref.accent, Ref.blue, Colors.white],
            ),
          SafeArea(
            child: ListView(
              padding: Ref.pagePadding,
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ZaferPaneli(
                          sonuc: sonuc,
                          delta: widget.rewardDelta,
                          giris: _giris,
                          onNewMatch: widget.onNewMatch,
                        ),
                        const SizedBox(height: Ref.pageGap),
                        RefNeutralButton(label: 'ANA MENÜYE DÖN', onTap: widget.onClose),
                        if (sonuc.leagueChange != null) ...[
                          const SizedBox(height: Ref.pageGap),
                          LeagueChangePanel(change: sonuc.leagueChange!),
                        ],
                        if (sonuc.cardsLost.isNotEmpty)
                          _KartBolumu(
                            baslik: 'Kaybettiğin kartlar',
                            aciklama: 'Bu kartlar KALICI olarak rakibine geçti.',
                            kartlar: sonuc.cardsLost,
                            renk: Ref.red,
                          ),
                        if (sonuc.cardsWon.isNotEmpty)
                          _KartBolumu(
                            baslik: 'Kazandığın kartlar',
                            aciklama: 'Bu kartlar artık senin; koleksiyonunda.',
                            kartlar: sonuc.cardsWon,
                            renk: Ref.accent,
                          ),
                        if (!sonuc.hasCardTransfers) ...[
                          const SizedBox(height: Ref.pageGap),
                          RefCardPanel(children: [
                            Row(children: [
                              const Em('🛡️', size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  sonuc.isDraw ? 'Beraberlikte kimse kart kaybetmez.' : 'Hiçbir kart el değiştirmedi.',
                                  style: Ref.bodyText(12, weight: FontWeight.w700),
                                ),
                              ),
                            ]),
                          ]),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (sonuc.leagueChange?.isPromoted == true && !_terfiKapandi)
            Positioned.fill(
              child: LeaguePromotionOverlay(
                change: sonuc.leagueChange!,
                onContinue: () => setState(() => _terfiKapandi = true),
              ),
            ),
        ],
      ),
    );
  }
}

/// .winpanel { background:radial-gradient(ellipse at center,#5e51315e,transparent 68%),
///   linear-gradient(#142c43,#0d1425); border:1px solid #caa358; border-radius:17px;
///   padding:22px 14px; gap:15px; text-align:center }
/// h1 { color:gold; font-size:50px; text-shadow:0 0 24px #e6b44e77 } .trophy { 92px }
class _ZaferPaneli extends StatelessWidget {
  final MatchResultSummary sonuc;
  final MatchRewardDelta? delta;
  final Animation<double> giris;
  final VoidCallback? onNewMatch;

  const _ZaferPaneli({required this.sonuc, required this.delta, required this.giris, required this.onNewMatch});

  @override
  Widget build(BuildContext context) {
    final (emoji, baslik, renk, alt) = _gorunum();
    final d = delta;
    final ust = Column(
      children: [
        Text('MAÇ SONUCU', style: Ref.caps(Ref.gold)),
        const SizedBox(height: 15),
        AnimatedBuilder(
          animation: giris,
          builder: (context, c) => Transform.scale(
            scale: 0.6 + 0.4 * Curves.easeOutBack.transform(giris.value),
            child: Opacity(opacity: giris.value.clamp(0.0, 1.0), child: c),
          ),
          child: Em(emoji, size: 92),
        ),
        const SizedBox(height: 15),
        Text(
          baslik,
          textAlign: TextAlign.center,
          style: Ref.heading(50, color: renk, height: 1).copyWith(
            shadows: [Shadow(color: renk.withValues(alpha: 0.47), blurRadius: 24)],
          ),
        ),
        const SizedBox(height: 6),
        Text(alt, textAlign: TextAlign.center, style: Ref.bodyText(12, color: Ref.muted)),
        const SizedBox(height: 15),
        Text('${sonuc.myScore} – ${sonuc.opponentScore}', style: Ref.heading(49, height: 1.1)),
        const SizedBox(height: 4),
        Text(
          'SEN · ${(sonuc.opponent?.username ?? 'RAKİP').toUpperTr()}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Ref.caps(Ref.muted),
        ),
        if (d != null) ...[
          const SizedBox(height: 15),
          Row(children: [
            Expanded(child: _OdulKutusu(simge: const CoinGlyph(size: 13), deger: d.coins, etiket: 'Altın')),
            const SizedBox(width: 6),
            Expanded(child: _OdulKutusu(simge: const Em('🏆', size: 13), deger: d.rating, etiket: 'Puan')),
            const SizedBox(width: 6),
            Expanded(child: _OdulKutusu(simge: const Em('🛡️', size: 13), deger: d.protectionSlots, etiket: 'Koruma')),
          ]),
        ],
        if (onNewMatch != null) ...[
          const SizedBox(height: 15),
          RefCta('YENİ MAÇ', trailing: RefGlyph.play, onTap: onNewMatch),
        ],
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFCAA358)),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF142C43), Color(0xFF0D1425)],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // radial-gradient(ellipse at center, #5e51315e, transparent 68%)
          const Positioned.fill(child: CustomPaint(painter: _PanelIsigi())),
          ust,
        ],
      ),
    );
  }

  (String, String, Color, String) _gorunum() {
    if (sonuc.isDraw) {
      return ('🤝', 'BERABERLİK', Ref.gold, 'Skor eşit bitti. Kimse kart kaybetmedi.');
    }
    if (sonuc.didIWin) {
      final n = sonuc.cardsWon.length;
      return ('🏆', 'ZAFER!', Ref.gold, n > 0 ? 'Rakibinden $n kart aldın.' : 'Rakibinin korumasız kartı kalmamıştı.');
    }
    final n = sonuc.cardsLost.length;
    return (
      '🛡️',
      'MÜCADELE BİTTİ',
      Ref.red,
      n > 0 ? '$n kartını kalıcı olarak kaptırdın.' : 'Korumadaki kartların sayesinde hiç kart kaybetmedin.',
    );
  }
}

class _PanelIsigi extends CustomPainter {
  const _PanelIsigi();

  @override
  void paint(Canvas c, Size s) {
    final m = s.center(Offset.zero);
    c.save();
    c.translate(m.dx, m.dy);
    c.scale(s.width / s.height, 1);
    final yr = s.height / 2 * 1.41 * 0.68;
    c.drawCircle(
        Offset.zero,
        yr,
        Paint()
          ..shader = const RadialGradient(colors: [Color(0x5E5E5131), Color(0x005E5131)])
              .createShader(Rect.fromCircle(center: Offset.zero, radius: yr)));
    c.restore();
  }

  @override
  bool shouldRepaint(_PanelIsigi old) => false;
}

/// .rewardbox { background:#112039; border:1px solid #334964; border-radius:10px;
///   padding:10px 4px; font-size:11px; font-weight:900 }
class _OdulKutusu extends StatelessWidget {
  final Widget simge;
  final int deger;
  final String etiket;

  const _OdulKutusu({required this.simge, required this.deger, required this.etiket});

  @override
  Widget build(BuildContext context) {
    final metin = deger > 0 ? '+$deger' : '$deger';
    final renk = deger < 0 ? Ref.red : (deger == 0 ? Ref.muted : Ref.text);
    return Semantics(
      label: '$etiket $metin',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF112039),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF334964)),
        ),
        child: Column(children: [
          simge,
          const SizedBox(height: 3),
          Text(metin, style: Ref.bodyText(11, color: renk, weight: FontWeight.w900)),
          Text(etiket, style: Ref.tiny(Ref.muted)),
        ]),
      ),
    );
  }
}

/// El değiştiren kartlar: .card-panel + ortak ızgara kartları
class _KartBolumu extends StatelessWidget {
  final String baslik;
  final String aciklama;
  final List<InventoryCard> kartlar;
  final Color renk;

  const _KartBolumu({required this.baslik, required this.aciklama, required this.kartlar, required this.renk});

  @override
  Widget build(BuildContext context) {
    const genislik = 96.0;
    return Padding(
      padding: const EdgeInsets.only(top: Ref.pageGap),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          gradient: Ref.cardPanelGradient,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: renk.withValues(alpha: 0.7)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$baslik (${kartlar.length})',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Ref.bodyText(14, color: renk, weight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(aciklama, style: Ref.bodyText(11, color: Ref.muted)),
          const SizedBox(height: 10),
          SizedBox(
            height: genislik / RefCardLayout.grid.aspectRatio,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: kartlar.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final k = kartlar[i];
                return RefPlayerCard(
                  key: ValueKey(k.userCardId),
                  name: k.fullName,
                  position: k.position,
                  tier: k.tier,
                  power: k.power,
                  seed: k.cardId,
                  kitSeed: k.club ?? k.nationality,
                  imageUrl: k.imageUrl,
                  width: genislik,
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
