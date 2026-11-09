import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../../core/feedback/game_feedback.dart';
import '../../../../../core/theme/ref_tokens.dart';
import '../../../../../shared/widgets/arena_card/rarity_style.dart';
import '../../../../../shared/widgets/avatar2d/avatar_spec.dart';
import '../../../../../shared/widgets/ref_card/ref_player_card.dart';
import '../../../domain/clash_event.dart';
import '../character_stage/character_stage.dart';
import 'figure_painter.dart';
import 'figure_rig.dart';
import 'side_arena_painter.dart';

/// Düellodaki bir taraf
class DuelSide {
  final AvatarSpec spec;
  final String name;
  final CardTier tier;

  /// Karşılaştırmada kullanılan güç (maçta: güç + kimya + taktik bonusu)
  final int power;
  final String? subtitle;

  /// Bu taraf "bu mevkide kartım yok" deyip pas geçti mi?
  final bool passed;

  /// Yüz kimliği (kartın cardId'si); null ise ad
  final String? seed;

  const DuelSide({
    required this.spec,
    required this.name,
    required this.tier,
    required this.power,
    this.subtitle,
    this.passed = false,
    this.seed,
  });
}

enum DuelPhase { intro, launch, materialize, action, result, done }

/// KARTTAN SAHAYA GEÇİŞ + DÜELLO SAHNESİ (2D/2.5D)
///
/// ===================================================================
/// ZAMAN ÇİZELGESİ (hız 1x)
/// ===================================================================
///   0     - 450 ms  GİRİŞ       Kartlar alttan ekrana girer
///   450   - 950     FIRLATMA    Kartlar sahadaki yerlerine uçar,
///                               küçülür ve yan döner (Y ekseni 90°)
///   950   - 1300    BELİRME     Kart kenardan görünmez olduğu anda
///                               figür yaylanarak büyür + ışık halkası
///   1300  - ...     AKSİYON     Mevkiye göre klip dizisi ([clipsFor])
///   ...   + 1100    SONUÇ       Kazananın üstüne spot, sonuç bandı,
///                               yüz ifadeleri değişir
///
/// SONUCU ANİMASYON BELİRLEMEZ: [outcome] sahne açılmadan bellidir
/// (maçta sunucudan gelir). Animasyon sadece onu gösterir.
class DuelStage extends StatefulWidget {
  final DuelSide me;
  final DuelSide opponent;
  final CardPosition position;
  final ClashOutcome outcome;

  /// 1 = normal, 0.5 = yavaş çekim (inceleme için). Maçta ~1.8:
  /// çatışma 1-3 sn, kartın sahaya girişi ~500 ms.
  final double speed;
  final VoidCallback? onFinished;

  /// Dokunuş: önce sonuca atla, sonuçtaysa kapat (maç ekranı)
  final bool skippable;

  /// Sonuç bandının başlığı ve açıklaması (null: KAZANDIN / KAYBETTİN)
  final String? headline;
  final String? detail;

  const DuelStage({
    super.key,
    required this.me,
    required this.opponent,
    required this.position,
    required this.outcome,
    this.speed = 1,
    this.onFinished,
    this.skippable = false,
    this.headline,
    this.detail,
  });

  static const int introEnd = 450;
  static const int launchEnd = 950;
  static const int materializeEnd = 1300;
  static const int resultMs = 1100;

  /// Aksiyonun süresi (iki tarafın uzun olanı)
  static int actionMs(CardPosition p, ClashOutcome o, {bool iPassed = false, bool opponentPassed = false}) => math.max(
    ClipSequencePlayer(clipsFor(p, o, iPassed: iPassed, opponentPassed: opponentPassed).clips).durationMs,
    ClipSequencePlayer(clipsFor(p, _ters(o), iPassed: opponentPassed, opponentPassed: iPassed).clips).durationMs,
  );

  static int totalMs(CardPosition p, ClashOutcome o, {bool iPassed = false, bool opponentPassed = false}) =>
      materializeEnd + actionMs(p, o, iPassed: iPassed, opponentPassed: opponentPassed) + resultMs;

  static DuelPhase phaseAt(
    double ms,
    CardPosition p,
    ClashOutcome o, {
    bool iPassed = false,
    bool opponentPassed = false,
  }) {
    if (ms < introEnd) return DuelPhase.intro;
    if (ms < launchEnd) return DuelPhase.launch;
    if (ms < materializeEnd) return DuelPhase.materialize;
    if (ms < materializeEnd + actionMs(p, o, iPassed: iPassed, opponentPassed: opponentPassed)) {
      return DuelPhase.action;
    }
    if (ms < totalMs(p, o, iPassed: iPassed, opponentPassed: opponentPassed)) return DuelPhase.result;
    return DuelPhase.done;
  }

  @override
  State<DuelStage> createState() => _DuelStageState();
}

ClashOutcome _ters(ClashOutcome o) => switch (o) {
  ClashOutcome.win => ClashOutcome.loss,
  ClashOutcome.loss => ClashOutcome.win,
  ClashOutcome.draw => ClashOutcome.draw,
};

class _DuelStageState extends State<DuelStage> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late ClipSequencePlayer _benim;
  late ClipSequencePlayer _rakip;

  bool get _benPas => widget.me.passed;
  bool get _rakipPas => widget.opponent.passed;

  int get _toplam => DuelStage.totalMs(widget.position, widget.outcome, iPassed: _benPas, opponentPassed: _rakipPas);

  int get _aksiyon => DuelStage.actionMs(widget.position, widget.outcome, iPassed: _benPas, opponentPassed: _rakipPas);

  /// Sonuç bandının başladığı an (0..1)
  double get _sonucOrani => (DuelStage.materializeEnd + _aksiyon) / _toplam;

  bool _bitti = false;
  bool _titredi = false;

  void _bitir() {
    if (_bitti) return;
    _bitti = true;
    widget.onFinished?.call();
  }

  @override
  void initState() {
    super.initState();
    _kur();
    _c = AnimationController(vsync: this, duration: _sure)
      ..addListener(_titresim)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _bitir();
      });
    // Kart animasyonları kapalıysa (düşük performans ayarı) düello
    // atlanır; yalnızca kısa sonuç bandı gösterilir
    if (!GameFeedback.cardAnimationsEnabled) _c.value = _sonucOrani;
    _c.forward();
  }

  /// Çarpışma anında BİR KEZ titreşim; şiddet sonuca göre
  void _titresim() {
    if (_titredi || _c.value < _sonucOrani) return;
    _titredi = true;
    GameFeedback.haptic(switch (widget.outcome) {
      ClashOutcome.win => HapticStrength.medium,
      ClashOutcome.loss => HapticStrength.light,
      ClashOutcome.draw => HapticStrength.selection,
    });
  }

  /// Önce sonuca atla, sonuçtaysa kapat
  void _dokun() {
    if (_c.value < _sonucOrani) {
      _c.value = _sonucOrani;
      _c.forward();
    } else {
      _c.stop();
      _bitir();
    }
  }

  Duration get _sure => Duration(milliseconds: (_toplam / widget.speed).round());

  void _kur() {
    _benim = ClipSequencePlayer(
      clipsFor(widget.position, widget.outcome, iPassed: _benPas, opponentPassed: _rakipPas).clips,
    );
    _rakip = ClipSequencePlayer(
      clipsFor(widget.position, _ters(widget.outcome), iPassed: _rakipPas, opponentPassed: _benPas).clips,
    );
  }

  @override
  void didUpdateWidget(DuelStage old) {
    super.didUpdateWidget(old);
    if (old.position != widget.position || old.outcome != widget.outcome || old.speed != widget.speed) {
      _kur();
      _c
        ..duration = _sure
        ..forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.removeListener(_titresim);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sahne = LayoutBuilder(
      builder: (context, k) {
        final boyut = Size(k.maxWidth, k.maxHeight);
        return AnimatedBuilder(animation: _c, builder: (context, _) => _sahne(boyut, _c.value * _toplam));
      },
    );
    if (!widget.skippable) return sahne;
    return Semantics(
      label: '${widget.headline ?? ''} ${widget.detail ?? ''}',
      liveRegion: true,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _dokun, child: sahne),
    );
  }

  Widget _sahne(Size s, double ms) {
    final faz = DuelStage.phaseAt(ms, widget.position, widget.outcome, iPassed: _benPas, opponentPassed: _rakipPas);
    final zemin = SideArenaPainter.groundY(s);

    // Figür ölçeği: figür ~95 birim, sahne yüksekliğinin ~%40'ı
    final olcek = s.height * 0.0042;
    final basBen = s.width * 0.24;
    final basRakip = s.width * 0.76;

    // Kat edilen yol, iki figür ortada çarpışmayacak şekilde sınırlanır
    final enCokYol = math.max(_benim.travelAt(1e9), _rakip.travelAt(1e9));
    final izin = s.width * 0.14;
    final yolCarpani = enCokYol == 0 ? 1.0 : math.min(1.0, izin / (enCokYol * olcek));

    final aksiyonMs = (ms - DuelStage.materializeEnd).clamp(0.0, double.infinity);
    final pozBen = _benim.poseAt(aksiyonMs);
    final pozRakip = _rakip.poseAt(aksiyonMs);
    final xBen = basBen + _benim.travelAt(aksiyonMs) * olcek * yolCarpani;
    final xRakip = basRakip - _rakip.travelAt(aksiyonMs) * olcek * yolCarpani;

    // Belirme: figür yaylanarak büyür
    final belirme = ((ms - (DuelStage.launchEnd - 60)) / (DuelStage.materializeEnd - DuelStage.launchEnd + 60)).clamp(
      0.0,
      1.0,
    );
    final figurOlcegi = Curves.elasticOut.transform(belirme) * 0.8 + 0.2 * belirme;

    // Sonuç
    final sonucT = ((ms - (DuelStage.materializeEnd + _aksiyon)) / 350).clamp(0.0, 1.0);
    final kazananBen = widget.outcome == ClashOutcome.win;
    final kazananRakip = widget.outcome == ClashOutcome.loss;
    MouthStyle? agiz(bool kazanan, bool kaybeden) => sonucT <= 0
        ? null
        : (kazanan
              ? MouthStyle.grin
              : kaybeden
              ? MouthStyle.serious
              : null);

    final topBende = widget.outcome != ClashOutcome.loss;

    // Material: sahne Scaffold dışında da kullanılabilsin (yazılar
    // varsayılan sarı alt çizgiyle çizilmesin)
    return Material(
      type: MaterialType.transparency,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: SideArenaPainter(
                spotlight: widget.outcome == ClashOutcome.draw
                    ? null
                    : RarityStyle.of(kazananBen ? widget.me.tier : widget.opponent.tier).accent,
                spotlightStrength: sonucT,
                spotlightX: (kazananBen ? xBen : xRakip) / s.width,
              ),
            ),
            if (belirme > 0)
              CustomPaint(
                painter: _FigurlerRessami(
                  ben: widget.me,
                  rakip: widget.opponent,
                  pozBen: pozBen,
                  pozRakip: pozRakip,
                  xBen: xBen,
                  xRakip: xRakip,
                  zemin: zemin,
                  olcek: olcek * figurOlcegi,
                  topBende: topBende,
                  agizBen: agiz(kazananBen, kazananRakip),
                  agizRakip: agiz(kazananRakip, kazananBen),
                  halka: belirme < 1 ? belirme : null,
                  halkaYaricap: s.height * 0.22,
                ),
              ),
            // Kartlar (belirme bitene kadar)
            if (ms < DuelStage.launchEnd + 10) ...[
              _ucanKart(s, ms, widget.me, basBen, zemin, olcek, true),
              _ucanKart(s, ms, widget.opponent, basRakip, zemin, olcek, false),
            ],
            if (faz == DuelPhase.result || faz == DuelPhase.done) _sonucBandi(s, sonucT),
          ],
        ),
      ),
    );
  }

  /// Giriş + fırlatma sırasında kart
  Widget _ucanKart(Size s, double ms, DuelSide d, double hedefX, double zemin, double olcek, bool ben) {
    final kg = math.min(s.width * 0.26, 118.0);
    final kh = kg / RefCardLayout.reveal.aspectRatio;

    // Giriş: alttan yükselir
    final giris = Curves.easeOutBack.transform((ms / DuelStage.introEnd).clamp(0.0, 1.0));
    final baslangic = Offset(ben ? s.width * 0.2 : s.width * 0.8, s.height + kh * 0.6);
    final beklemeNoktasi = Offset(ben ? s.width * 0.2 : s.width * 0.8, s.height - kh * 0.55);
    // Fırlatma: figürün göğüs hizasına uçar
    final firlatT = ((ms - DuelStage.introEnd) / (DuelStage.launchEnd - DuelStage.introEnd)).clamp(0.0, 1.0);
    final firlat = Curves.easeInOutCubic.transform(firlatT);
    final hedef = Offset(hedefX, zemin - 55 * olcek);

    final merkez = Offset.lerp(Offset.lerp(baslangic, beklemeNoktasi, giris)!, hedef, firlat)!;
    final olcekK = 1 - 0.45 * firlat;
    // Son %40'ta yan döner (90°'de görünmez olur, figür o anda belirir)
    final donus = ((firlatT - 0.6) / 0.4).clamp(0.0, 1.0) * math.pi / 2;

    return Positioned(
      left: merkez.dx - kg / 2,
      top: merkez.dy - kh / 2,
      width: kg,
      height: kh,
      child: IgnorePointer(
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0015)
            ..scaleByDouble(olcekK, olcekK, 1, 1)
            ..rotateY(ben ? donus : -donus)
            ..rotateZ((ben ? -0.06 : 0.06) * (1 - firlat)),
          // Uygulamanın ortak kartı (koleksiyondaki kartın aynısı)
          child: RefPlayerCard(
            spec: d.spec,
            seed: d.seed ?? d.name,
            name: d.passed ? 'PAS' : d.name,
            position: widget.position,
            tier: d.tier,
            power: d.power,
            width: kg,
            layout: RefCardLayout.reveal,
          ),
        ),
      ),
    );
  }

  Widget _sonucBandi(Size s, double t) {
    final (varsayilan, renk) = switch (widget.outcome) {
      ClashOutcome.win => ('KAZANDIN', Ref.accent),
      ClashOutcome.loss => ('KAYBETTİN', Ref.red),
      ClashOutcome.draw => ('BERABERE', Ref.gold),
    };
    final yazi = widget.headline ?? varsayilan;
    String guc(DuelSide d) => d.passed ? 'PAS' : '${d.power}';
    return Positioned(
      left: 0,
      right: 0,
      top: s.height * 0.08,
      child: Opacity(
        opacity: t,
        child: Transform.scale(
          scale: 0.85 + 0.15 * Curves.easeOutBack.transform(t),
          child: Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: math.max(120, s.width - 32)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xE60D1425),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: renk, width: 2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    yazi,
                    textAlign: TextAlign.center,
                    style: Ref.heading(26, weight: FontWeight.w900, color: renk),
                  ),
                  Text(
                    '${guc(widget.me)}  -  ${guc(widget.opponent)}',
                    style: Ref.heading(16, weight: FontWeight.w800, color: Colors.white),
                  ),
                  if (widget.detail != null)
                    Text(
                      widget.detail!,
                      textAlign: TextAlign.center,
                      style: Ref.bodyText(11, color: Ref.muted, weight: FontWeight.w700),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FigurlerRessami extends CustomPainter {
  final DuelSide ben, rakip;
  final Pose pozBen, pozRakip;
  final double xBen, xRakip, zemin, olcek;
  final bool topBende;
  final MouthStyle? agizBen, agizRakip;

  /// Belirme ışık halkası (0..1); null = yok
  final double? halka;
  final double halkaYaricap;

  _FigurlerRessami({
    required this.ben,
    required this.rakip,
    required this.pozBen,
    required this.pozRakip,
    required this.xBen,
    required this.xRakip,
    required this.zemin,
    required this.olcek,
    required this.topBende,
    required this.agizBen,
    required this.agizRakip,
    required this.halka,
    required this.halkaYaricap,
  });

  @override
  void paint(Canvas c, Size s) {
    if (halka != null) {
      for (final (x, tier) in [(xBen, ben.tier), (xRakip, rakip.tier)]) {
        final renk = RarityStyle.of(tier).accent;
        final m = Offset(x, zemin - halkaYaricap * 0.45);
        c.drawCircle(
          m,
          halkaYaricap * (0.3 + halka! * 0.9),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6 * (1 - halka!)
            ..color = renk.withValues(alpha: 0.9 * (1 - halka!)),
        );
        // Toz bulutu
        for (var i = 0; i < 6; i++) {
          final a = math.pi + i * math.pi / 5;
          c.drawCircle(
            Offset(x + math.cos(a) * halkaYaricap * 0.5 * halka!, zemin + math.sin(a).abs() * -6 * halka!),
            4 * (1 - halka!),
            Paint()..color = Colors.white.withValues(alpha: 0.5 * (1 - halka!)),
          );
        }
      }
    }
    // Rakip arkada (biraz yukarıda değil; aynı zemin), ben önde çizilir
    FigureDraw.paint(
      c,
      rakip.spec,
      pozRakip,
      origin: Offset(xRakip, zemin),
      scale: olcek,
      facingRight: false,
      mouth: agizRakip,
      drawBall: !topBende,
    );
    FigureDraw.paint(
      c,
      ben.spec,
      pozBen,
      origin: Offset(xBen, zemin),
      scale: olcek,
      facingRight: true,
      mouth: agizBen,
      drawBall: topBende,
    );
  }

  @override
  bool shouldRepaint(_FigurlerRessami old) => true;
}

/// Maçta düellonun çerçevesi: ekranın ortasında, referans `.arena-stage`
/// panel dilinde (koyu çerçeve, 16px köşe), yatay oranlı kutu.
///
/// Sahne yatay bir kutu için tasarlandı; dikey telefonda tam ekran
/// açıldığında figürler ekran yüksekliğine göre büyüyüp üst üste
/// biniyordu. Kutu genişliğe göre ölçeklenir (en fazla 620 px).
class DuelStageFrame extends StatelessWidget {
  final Widget child;
  const DuelStageFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF476B81)),
                  boxShadow: const [BoxShadow(color: Color(0xAA000000), blurRadius: 40)],
                ),
                child: AspectRatio(aspectRatio: 4 / 3.4, child: child),
              ),
              const SizedBox(height: 10),
              Text('Geçmek için dokun', style: Ref.tiny(Ref.muted)),
            ],
          ),
        ),
      ),
    ),
  );
}
