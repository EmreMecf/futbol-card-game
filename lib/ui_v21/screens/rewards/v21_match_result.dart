import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/audio/sound_cues.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/feedback/game_feedback.dart';
import '../../../features/items/cosmetics/equipped_cosmetics.dart';
import '../../../features/match/presentation/viewmodel/match_view_model.dart' show MatchRewardDelta;
import '../../../ui_v21/components/v21_cosmetics.dart';
import '../../../ui_v21/components/v21_confetti.dart';
import '../../ui_v21.dart';
import 'v21_match_panels.dart';
import '../../../core/l10n/app_language.dart';

/// V2.1 MAÇ SONUCU (referans `assets/v21/screens/win.png`).
///
///   ZAFER! / BERABERLİK / MÜCADELE BİTTİ   (altın / altın / kırmızı başlık)
///   maskot (yalnız galibiyette) · ışın arka planı · konfeti / fişek kozmetiği
///   ( avatar  7 : 4  avatar )
///   ÖDÜLLERİN: +altın · +kupa · +koruma   (yalnız dereceli maç)
///   +2 KART KAZANDIN (kartlar) / -N KART KAYBETTİN
///   [ ANA MENÜ ] [ YENİ MAÇ ]
///   dereceli maçta: maç sandığı, sezon XP'si, lig değişimi (mevcut paneller)
///
/// VERİ: sunucunun maç özeti (`MatchResultSummary`) ve maç öncesi/sonrası
/// sayaç farkı (`MatchRewardDelta`). Fark bilinmiyorsa ödül kartları hiç
/// çizilmez. Antrenman, öğretici ve kart kaybı olmayan modlarda sandık,
/// sezon XP'si ve lig paneli gösterilmez (yalnız `mode == 'ranked'`).
/// Maç skorla değil hükmen mi bitti (teslim ya da üst üste iki hamle
/// kaçırma)? Skorla biten maçta kazanan her zaman daha fazla kart toplar.
bool matchEndedByForfeit(MatchResultSummary s) =>
    !s.isDraw && (s.didIWin ? s.myScore <= s.opponentScore : s.myScore >= s.opponentScore);

class V21MatchResultView extends StatefulWidget {
  final MatchResultSummary? result;
  final MatchRewardDelta? rewardDelta;
  final VoidCallback onClose;
  final VoidCallback? onNewMatch;

  /// "YENİ MAÇ" düğmesinin metni (öğreticide "ÖĞRETİCİYE DEVAM" vb.)
  final String newMatchLabel;

  const V21MatchResultView({
    super.key,
    required this.result,
    required this.onClose,
    this.rewardDelta,
    this.onNewMatch,
    this.newMatchLabel = 'YENİ MAÇ',
  });

  @override
  State<V21MatchResultView> createState() => _V21MatchResultViewState();
}

class _V21MatchResultViewState extends State<V21MatchResultView> with SingleTickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  bool _hapticDone = false;
  bool _promotionClosed = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (V21Motion.cardEffects(context)) {
      _enter.forward();
    } else {
      _enter.value = 1;
    }
  }

  void _haptic(MatchResultSummary s) {
    if (_hapticDone) return;
    _hapticDone = true;
    GameFeedback.haptic(s.didIWin ? HapticStrength.heavy : (s.isDraw ? HapticStrength.light : HapticStrength.medium));
    // Jingle maç müziğini durdurur; ödül sesleri jingle başladıktan sonra
    GameAudio.jingle(s.didIWin ? Jingle.victory : (s.isDraw ? Jingle.draw : Jingle.defeat));
    final coins = widget.rewardDelta?.coins ?? 0;
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      if (coins > 0) GameAudio.sfx(Sfx.coins);
      if (s.cardsWon.isNotEmpty) GameAudio.sfx(Sfx.cardsWon);
      if (s.cardsLost.isNotEmpty) GameAudio.sfx(Sfx.cardsLost);
    });
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.result;
    if (s == null) {
      return const Scaffold(
        backgroundColor: V21Colors.inkDeep,
        body: Center(child: CircularProgressIndicator(color: V21Colors.goldTop)),
      );
    }
    _haptic(s);
    final fireworks = EquippedCosmetics.current?.victory == 'victory_fireworks';
    final effects = V21Motion.cardEffects(context);
    return Theme(
      data: V21Theme.data(context),
      child: Scaffold(
        backgroundColor: V21Colors.inkDeep,
        body: LayoutBuilder(
          builder: (context, c) {
            final k = V21Scale.forSize(c.biggest).s;
            return Stack(
              fit: StackFit.expand,
              children: [
                V21RaysBackground(
                  center: const Alignment(0, -0.45),
                  background: s.didIWin
                      ? const [Color(0xFF8A3FD8), Color(0xFF3A1680), Color(0xFF16082F)]
                      : const [Color(0xFF4A2BA8), Color(0xFF26135F), Color(0xFF120830)],
                  rayColor: s.didIWin ? const Color(0x33FFD27A) : const Color(0x14FFFFFF),
                ),
                if (s.didIWin && !fireworks)
                  ConfettiOverlay(
                    active: effects,
                    colors: const [Color(0xFFFFC832), Color(0xFF3DD15A), Color(0xFF5FB4FF), Colors.white],
                  ),
                SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: V21Metrics.maxContentWidth * k),
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(18 * k, 14 * k, 18 * k, 24 * k),
                        children: _content(context, s, k),
                      ),
                    ),
                  ),
                ),
                if (s.leagueChange?.isPromoted == true && !_promotionClosed)
                  Positioned.fill(
                    child: SfxOnMount(
                      sfx: Sfx.leagueUp,
                      child: V21LeaguePromotionOverlay(
                        change: s.leagueChange!,
                        onContinue: () => setState(() => _promotionClosed = true),
                      ),
                    ),
                  ),
                if (s.didIWin && fireworks) FireworksOverlay(active: effects),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, MatchResultSummary s, double k) {
    final (title, colors, subtitle) = _look(s);
    final d = widget.rewardDelta;
    final ranked = s.mode == 'ranked';
    UserModel? me;
    try {
      me = context.watch<SessionManager>().user;
    } on ProviderNotFoundException {
      me = null;
    }
    return [
      if (!ranked)
        Text(
          s.mode == 'tutorial'
              ? 'ÖĞRETİCİ {p}/3 · ÖDÜL VE PUAN YOK'.trArgs({'p': s.tutorialStep ?? 1})
              : (s.mode == 'training' ? 'ANTRENMAN · ÖDÜL VE PUAN YOK'.tr : 'ÖDÜL VE PUAN YOK'.tr),
          textAlign: TextAlign.center,
          style: V21Type.label(12 * k, weight: FontWeight.w900, color: const Color(0xFFFEDB70), letterSpacing: 1),
        ),
      AnimatedBuilder(
        animation: _enter,
        builder: (context, child) => Transform.scale(
          scale: 0.6 + 0.4 * Curves.easeOutBack.transform(_enter.value),
          child: Opacity(opacity: _enter.value.clamp(0.0, 1.0), child: child),
        ),
        child: Center(
          child: V21HeroTitle(title, size: 70 * k, colors: colors),
        ),
      ),
      if (s.didIWin)
        Center(
          child: ExcludeSemantics(
            child: ShaderMask(
              shaderCallback: (r) => const RadialGradient(
                radius: 0.62,
                colors: [Colors.white, Colors.white, Color(0x00FFFFFF)],
                stops: [0, 0.7, 1],
              ).createShader(r),
              blendMode: BlendMode.dstIn,
              child: Image.asset(V21Assets.victoryMascot, height: 280 * k, fit: BoxFit.contain),
            ),
          ),
        )
      else ...[
        // Galibiyette alt yazı yok (referans): kazanılan kartlar satırı söylüyor
        SizedBox(height: 14 * k),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: V21Type.label(13 * k, weight: FontWeight.w700, color: const Color(0xFFE3D6FF)),
        ),
      ],
      SizedBox(height: 4 * k),
      _ScorePanel(result: s, me: me, scale: k),
      if (s.mode == 'tutorial' && s.tutorialStep == 3) ...[
        SizedBox(height: 10 * k),
        Text(
          'Öğretici tamamlandı! Gümüş sandığın Sandıklar ekranında.'.tr,
          textAlign: TextAlign.center,
          style: V21Type.label(13 * k, weight: FontWeight.w800, color: V21Colors.goldTop),
        ),
      ],
      if (d != null && ranked) ...[
        SizedBox(height: 14 * k),
        Text(
          'ÖDÜLLERİN'.tr,
          textAlign: TextAlign.center,
          style: V21Type.label(12 * k, weight: FontWeight.w900, color: const Color(0xFFFFE3A6), letterSpacing: 1),
        ),
        SizedBox(height: 8 * k),
        Row(
          children: [
            Expanded(
              child: FittedBox(
                child: V21RewardCard(
                  icon: const V21CoinIcon(size: 46),
                  value: _signed(d.coins),
                  label: 'ALTIN'.tr,
                  valueColor: d.coins < 0 ? V21Colors.danger : Colors.white,
                ),
              ),
            ),
            SizedBox(width: 8 * k),
            Expanded(
              child: FittedBox(
                child: V21RewardCard(
                  icon: const V21StarIcon(size: 46, color: Color(0xFFFFD45E)),
                  value: _signed(d.rating),
                  label: 'KUPA'.tr,
                  valueColor: d.rating < 0 ? V21Colors.danger : Colors.white,
                ),
              ),
            ),
            SizedBox(width: 8 * k),
            Expanded(
              child: FittedBox(
                child: V21RewardCard(
                  icon: const Icon(Icons.shield_rounded, size: 46, color: Color(0xFF8FC8FF)),
                  value: _signed(d.protectionSlots),
                  label: 'KORUMA'.tr,
                ),
              ),
            ),
          ],
        ),
      ],
      if (s.cardsWon.isNotEmpty)
        _CardsRow(title: '+{length} KART KAZANDIN'.trArgs({'length': s.cardsWon.length}), cards: s.cardsWon, good: true, scale: k),
      if (s.cardsLost.isNotEmpty)
        _CardsRow(title: '-{length} KART KAYBETTİN'.trArgs({'length': s.cardsLost.length}), cards: s.cardsLost, good: false, scale: k),
      if (!s.hasCardTransfers && !s.noCardLossRules) ...[
        SizedBox(height: 12 * k),
        Text(
          s.isDraw ? 'Beraberlikte kimse kart kaybetmez.'.tr : 'Hiçbir kart el değiştirmedi.'.tr,
          textAlign: TextAlign.center,
          style: V21Type.label(12 * k, weight: FontWeight.w700, color: V21Colors.textMuted),
        ),
      ],
      SizedBox(height: 18 * k),
      Row(
        children: [
          Expanded(
            child: V21GameButton(
              label: 'ANA MENÜ'.tr,
              tone: V21ButtonTone.blue,
              size: V21ButtonSize.large,
              scale: k,
              onPressed: widget.onClose,
            ),
          ),
          if (widget.onNewMatch != null) ...[
            SizedBox(width: 10 * k),
            Expanded(
              child: V21GameButton(
                label: widget.newMatchLabel.tr,
                size: V21ButtonSize.large,
                scale: k,
                onPressed: widget.onNewMatch,
              ),
            ),
          ],
        ],
      ),
      // Ekonomi V2: maç sandığı ve sezon XP'si yalnız dereceli maçta
      if (ranked) ...[
        V21MatchChestPanel(matchId: s.matchId, scale: k),
        V21MatchSeasonXpLine(matchId: s.matchId, scale: k),
      ],
      if (s.leagueChange != null && ranked) ...[
        SizedBox(height: 12 * k),
        V21LeagueChangePanel(change: s.leagueChange!, scale: k),
      ],
    ];
  }

  static String _signed(int v) => v > 0 ? '+$v' : '$v';


  (String, List<Color>, String) _look(MatchResultSummary s) {
    const gold = [Color(0xFFFFF1A8), Color(0xFFFFC21F), Color(0xFFFF7A00)];
    const red = [Color(0xFFFFC2CB), Color(0xFFFF5A6E), Color(0xFFB0193A)];
    if (s.isDraw) return ('BERABERLİK'.tr, gold, 'Skor eşit bitti. Kimse kart kaybetmedi.'.tr);
    // Kazanan daha fazla kart toplamadıysa maç skorla değil hükmen bitti:
    // teslim olundu ya da üst üste iki turda hamle yapılmadı
    final hukmen = matchEndedByForfeit(s);
    if (s.noCardLossRules) {
      if (hukmen) {
        return s.didIWin
            ? ('ZAFER!'.tr, gold, 'Rakip maçı bıraktı, hükmen kazandın.'.tr)
            : ('HÜKMEN YENİLGİ'.tr, red, 'Teslim olundu ya da üst üste iki turda hamle yapılmadı; skor sayılmadı.'.tr);
      }
      return s.didIWin
          ? ('ZAFER!'.tr, gold, '{myScore} kart topladın, maçı kazandın.'.trArgs({'myScore': s.myScore}))
          : ('MÜCADELE BİTTİ'.tr, red, 'Bu maçta kart kaybı yok: kartların sende kaldı.'.tr);
    }
    if (s.didIWin) {
      final n = s.cardsWon.length;
      final kart = n > 0 ? 'Rakibinden {n} kart aldın.'.trArgs({'n': n}) : 'Rakibinin korumasız kartı kalmamıştı.'.tr;
      return ('ZAFER!'.tr, gold, hukmen ? 'Rakip maçı bıraktı, hükmen kazandın. {kart}'.trArgs({'kart': kart}) : kart);
    }
    final n = s.cardsLost.length;
    final kart = n > 0 ? '{n} kartını kalıcı olarak kaptırdın.'.trArgs({'n': n}) : 'Korumadaki kartların sayesinde hiç kart kaybetmedin.'.tr;
    return (hukmen ? 'HÜKMEN YENİLGİ'.tr : 'MÜCADELE BİTTİ'.tr, red, kart);
  }
}

/// Skor paneli (referans: altın kenarlı koyu hap, iki yanda avatar, "7 : 4")
class _ScorePanel extends StatelessWidget {
  final MatchResultSummary result;
  final UserModel? me;
  final double scale;
  const _ScorePanel({required this.result, required this.me, required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final opp = result.opponent;
    return Semantics(
      label: 'Skor {myScore} - {opponentScore}, rakip {p}'.trArgs({'myScore': result.myScore, 'opponentScore': result.opponentScore, 'p': opp?.username ?? 'Rakip'.tr}),
      excludeSemantics: true,
      child: Container(
        height: 72 * k,
        padding: EdgeInsets.symmetric(horizontal: 8 * k),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40 * k),
          border: Border.all(color: const Color(0xFFFFC832), width: 3 * k),
          gradient: const LinearGradient(colors: [Color(0xFF2A1460), Color(0xFF1B0E3A)]),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 10 * k)],
        ),
        child: Row(
          children: [
            V21PlayerAvatar(
              seed: 'oyuncu-${me?.id ?? me?.username ?? 'ben'}',
              semanticsLabel: 'Sen'.tr,
              name: me?.username,
              size: 52 * k,
              background: const Color(0xFF7FC0FF),
            ),
            Expanded(
              child: Center(
                child: Text(
                  '${result.myScore} : ${result.opponentScore}',
                  style: V21Type.title(44 * k, shadows: V21Type.inkShadow(k * 1.2)),
                ),
              ),
            ),
            V21PlayerAvatar(
              seed: 'oyuncu-${opp?.id ?? opp?.username ?? 'rakip'}',
              semanticsLabel: 'Rakip'.tr,
              name: opp?.username,
              size: 52 * k,
              background: const Color(0xFFFF8A9B),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kazanılan / kaybedilen kartlar (referans: solda "+2 KART KAZANDIN",
/// sağda üst üste eğik kartlar). 3'ten fazla kartta yatay kaydırılır.
class _CardsRow extends StatelessWidget {
  final String title;
  final List<InventoryCard> cards;
  final bool good;
  final double scale;
  const _CardsRow({required this.title, required this.cards, required this.good, required this.scale});

  Widget _card(InventoryCard c, double w, double angle) => Transform.rotate(
    angle: angle,
    child: V21PlayerCard(
      name: c.fullName,
      artKey: c.slug,
      position: c.position,
      tier: c.tier,
      power: c.power,
      width: w,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final w = 66 * k;
    final h = w * V21PlayerCard.baseHeight / V21PlayerCard.baseWidth;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: V21Type.title(20 * k, color: good ? V21Colors.successText : const Color(0xFFFF8A9B))),
        Text(
          good ? 'Bu kartlar artık senin; koleksiyonunda.'.tr : 'Bu kartlar KALICI olarak rakibine geçti.'.tr,
          style: V21Type.label(11 * k, weight: FontWeight.w700, color: V21Colors.textMuted),
        ),
      ],
    );
    final Widget fan = cards.length <= 3
        ? SizedBox(
            width: w + (cards.length - 1) * w * 0.72 + 8 * k,
            height: h + 8 * k,
            child: Stack(
              children: [
                for (var i = 0; i < cards.length; i++)
                  Positioned(
                    left: i * w * 0.72,
                    top: i.isEven ? 6 * k : 0,
                    child: _card(cards[i], w, (i.isEven ? -1 : 1) * 0.07),
                  ),
              ],
            ),
          )
        : SizedBox(
            width: 3.2 * w,
            height: h + 8 * k,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: cards.length,
              separatorBuilder: (_, _) => SizedBox(width: 6 * k),
              itemBuilder: (context, i) => _card(cards[i], w, 0),
            ),
          );
    return Padding(
      padding: EdgeInsets.only(top: 12 * k),
      child: Row(
        children: [
          Expanded(child: text),
          SizedBox(width: 8 * k),
          fan,
        ],
      ),
    );
  }
}

/// Sonuç ekranının ana düğmesi: öğreticide sıradaki adıma yönlendirir.
String newMatchLabel(MatchResultSummary s) {
  if (s.mode != 'tutorial') return 'YENİ MAÇ'.tr;
  return (s.tutorialStep ?? 1) >= 3 ? 'DERECELİ MAÇA GEÇ'.tr : 'ÖĞRETİCİYE DEVAM'.tr;
}
