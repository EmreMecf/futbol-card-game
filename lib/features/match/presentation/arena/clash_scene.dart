import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/feedback/game_feedback.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/turkish_text.dart';
import '../../../../shared/widgets/premium_card/premium_card.dart';
import '../../domain/clash_event.dart';
import 'arena_backdrop.dart';

/// ÇATIŞMA SAHNESİ — sonuçlanmış bir turu sahada oynatır (MD bölüm 6).
///
/// ===================================================================
/// SONUCU ANİMASYON BELİRLEMİYOR
/// ===================================================================
/// Sahne açıldığında sonuç ZATEN BELLİ: sunucu turu çözmüş, kazananı
/// veritabanına yazmış, [ClashEvent] o kayıttan oluşturulmuş. Buradaki
/// her hareket o sonuca göre seçiliyor: kazanan taraf topu alır, şutu
/// atar ya da kurtarır. Sahneyi atlamak ya da kapatmak hiçbir şeyi
/// değiştirmez.
///
/// ===================================================================
/// ZAMAN ÇİZELGESİ (toplam ~2,7 sn; MD: çatışma 1,5-3 sn)
/// ===================================================================
///   0.00 - 0.20  Kartlar girer, güç + kimya görünür
///   0.20 - 0.30  Kartlar kenarlara çekilir, saha öne çıkar
///   0.30 - 0.74  Mevkiye özel düello
///   0.74         Çarpışma: ışık patlaması + titreşim
///   0.76 - 1.00  Sonuç bandı
///
/// PERFORMANS: Tek AnimationController. Oyuncular ve top tek bir
/// CustomPainter'da çiziliyor; kartlar bir kez kurulup her karede
/// sadece dönüşümleri değişiyor (AnimatedBuilder `child`).
class ClashScene extends StatefulWidget {
  final ClashEvent event;

  /// Sahne bitince ya da oyuncu atlayınca
  final VoidCallback onFinished;

  const ClashScene({super.key, required this.event, required this.onFinished});

  /// Sahnenin toplam süresi
  static Duration get totalDuration =>
      AppDurations.clash + const Duration(milliseconds: 500);

  /// Sonuç bandının başladığı an (atlanınca buraya gelinir)
  static const double bannerStart = 0.76;

  static const double _duelloBas = 0.30;
  static const double _duelloBit = 0.74;

  @override
  State<ClashScene> createState() => _ClashSceneState();
}

class _ClashSceneState extends State<ClashScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _kontrolcu;
  bool _titredi = false;

  ClashEvent get _olay => widget.event;

  @override
  void initState() {
    super.initState();
    _kontrolcu =
        AnimationController(vsync: this, duration: ClashScene.totalDuration)
          ..addListener(_carpismaAni)
          ..addStatusListener((s) {
            if (s == AnimationStatus.completed) widget.onFinished();
          });

    // Kart animasyonları kapalıysa düelloyu atla, sadece sonucu göster
    if (!GameFeedback.cardAnimationsEnabled) {
      _kontrolcu.value = ClashScene.bannerStart;
    }
    _kontrolcu.forward();
  }

  /// Çarpışma anında BİR KEZ titreşim. Şiddet sonuca göre.
  void _carpismaAni() {
    if (_titredi || _kontrolcu.value < ClashScene._duelloBit) return;
    _titredi = true;
    GameFeedback.haptic(switch (_olay.outcome) {
      ClashOutcome.win => HapticStrength.medium,
      ClashOutcome.loss => HapticStrength.light,
      ClashOutcome.draw => HapticStrength.selection,
    });
  }

  /// Dokunuş: önce sonuca atla, sonuçtaysa kapat
  void _dokun() {
    if (_kontrolcu.value < ClashScene.bannerStart) {
      _kontrolcu.value = ClashScene.bannerStart;
      _kontrolcu.forward();
    } else {
      _kontrolcu.stop();
      widget.onFinished();
    }
  }

  @override
  void dispose() {
    _kontrolcu.removeListener(_carpismaAni);
    _kontrolcu.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${_olay.headline}. ${_olay.detail}',
      liveRegion: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _dokun,
        child: LayoutBuilder(
          builder: (context, kisit) {
            final boyut = Size(kisit.maxWidth, kisit.maxHeight);
            final kartGenisligi = (boyut.shortestSide * 0.30).clamp(
              90.0,
              150.0,
            );

            final rakipKart = _KartPlakasi(
              move: _olay.opponentMove,
              mine: false,
              width: kartGenisligi,
            );
            final benimKart = _KartPlakasi(
              move: _olay.myMove,
              mine: true,
              width: kartGenisligi,
            );

            return AnimatedBuilder(
              animation: _kontrolcu,
              builder: (context, _) {
                final t = _kontrolcu.value;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // ---- KARARTMA ----
                    ColoredBox(
                      color: Colors.black.withValues(alpha: _karartma(t)),
                    ),

                    // ---- DÜELLO (saha üstünde) ----
                    if (t >= ClashScene._duelloBas - 0.05)
                      Opacity(
                        opacity: _duelloGorunurlugu(t),
                        child: CustomPaint(
                          painter: DuelPainter(
                            event: _olay,
                            progress: _yerel(
                              t,
                              ClashScene._duelloBas,
                              ClashScene._duelloBit,
                            ),
                          ),
                          size: Size.infinite,
                        ),
                      ),

                    // ---- KARTLAR ----
                    _kartKatmani(t, boyut, rakipKart, ust: true),
                    _kartKatmani(t, boyut, benimKart, ust: false),

                    // ---- SONUÇ BANDI ----
                    if (t >= ClashScene.bannerStart)
                      Center(
                        child: Opacity(
                          opacity: _yerel(t, ClashScene.bannerStart, 0.84),
                          child: Transform.scale(
                            scale:
                                0.85 +
                                0.15 *
                                    Curves.easeOutBack.transform(
                                      _yerel(t, ClashScene.bannerStart, 0.88),
                                    ),
                            child: _SonucBandi(event: _olay),
                          ),
                        ),
                      ),

                    // ---- ATLA İPUCU ----
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: AppSpacing.xxl,
                      child: SafeArea(
                        top: false,
                        child: Text(
                          t < ClashScene.bannerStart
                              ? 'Atlamak için dokun'
                              : 'Devam etmek için dokun',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyXS,
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // ZAMANLAMA YARDIMCILARI
  // ------------------------------------------------------------------
  /// [t]'yi [bas]-[bit] aralığında 0-1'e çevirir
  static double _yerel(double t, double bas, double bit) =>
      ((t - bas) / (bit - bas)).clamp(0.0, 1.0);

  double _karartma(double t) {
    // Girişte koyulaşır, düelloda saha görünsün diye açılır, sonuçta
    // tekrar koyulaşır
    if (t < 0.20) return 0.75 * _yerel(t, 0, 0.12);
    if (t < 0.30) return 0.75 - 0.35 * _yerel(t, 0.20, 0.30);
    if (t < ClashScene.bannerStart) return 0.40;
    return 0.40 + 0.30 * _yerel(t, ClashScene.bannerStart, 0.84);
  }

  double _duelloGorunurlugu(double t) {
    final giris = _yerel(
      t,
      ClashScene._duelloBas - 0.05,
      ClashScene._duelloBas,
    );
    final cikis = 1 - 0.6 * _yerel(t, ClashScene.bannerStart, 0.84);
    return giris * cikis;
  }

  /// Kartın konumu: girişte ortaya yakın ve büyük, düelloda kenarda
  /// ve küçük. Rakip kartı üstte, benimki altta.
  Widget _kartKatmani(double t, Size boyut, Widget kart, {required bool ust}) {
    final giris = Curves.easeOutCubic.transform(_yerel(t, 0, 0.18));
    final cekilme = Curves.easeInOutCubic.transform(_yerel(t, 0.20, 0.30));

    // Dikey konum (ekranın oranı olarak, kartın merkezi)
    final baslangic = ust ? -0.35 : 1.35;
    final odak = ust ? 0.30 : 0.70;
    // Alt kart, ekranın dibindeki "Atlamak için dokun" yazısına
    // binmesin diye üsttekinden daha içeride duruyor (güç etiketi
    // yazının altında kalıp okunmuyordu).
    final kenar = ust ? 0.12 : 0.82;
    final y = _ara(_ara(baslangic, odak, giris), kenar, cekilme);

    final olcek = 1.0 - 0.48 * cekilme;

    // Yatay: düelloda kartlar KÖŞELERE çekilir (rakip sol üst, ben sağ
    // alt). Ortada kalsalardı sahanın orta şeridini -oyuncuların ve
    // topun geçtiği yeri- kapatıyorlardı; kaleci kartın arkasında
    // kayboluyordu.
    final x = _ara(0, ust ? -0.32 : 0.32, cekilme);

    // Sonuç bandında kaybeden kart soluklaşır, kazanan parlar
    final bant = _yerel(t, ClashScene.bannerStart, 0.84);
    final kazandi = switch (_olay.outcome) {
      ClashOutcome.win => !ust,
      ClashOutcome.loss => ust,
      ClashOutcome.draw => true,
    };
    final saydamlik = kazandi ? 1.0 : 1.0 - 0.55 * bant;

    return Positioned(
      left: boyut.width * x,
      right: -boyut.width * x,
      top: boyut.height * y - boyut.height * 0.12,
      child: Center(
        child: Opacity(
          opacity: saydamlik,
          child: Transform.scale(scale: olcek, child: kart),
        ),
      ),
    );
  }

  static double _ara(double a, double b, double t) => a + (b - a) * t;
}

// ====================================================================
// KART PLAKASI
// ====================================================================
class _KartPlakasi extends StatelessWidget {
  final MatchMove? move;
  final bool mine;
  final double width;

  const _KartPlakasi({
    required this.move,
    required this.mine,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final m = move;
    final renk = mine ? AppColors.cyan : AppColors.danger;

    if (m == null || m.isPass || m.position == null || m.tier == null) {
      return Container(
        width: width,
        height: width / 0.7,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: renk.withValues(alpha: 0.5)),
        ),
        child: Text(
          'PAS',
          style: AppTypography.display(
            size: 28,
            weight: FontWeight.w900,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Taraf etiketi: SEN / RAKİP
        Text(
          mine ? 'SEN' : 'RAKİP',
          style: AppTypography.display(
            size: 13,
            weight: FontWeight.w900,
            letterSpacing: 1.4,
            color: renk,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        PremiumPlayerCard(
          fullName: m.fullName ?? '',
          position: m.position!,
          tier: m.tier!,
          power: m.power ?? 0,
          imageUrl: m.imageUrl,
          width: width,
          interactive: false,
        ),
        const SizedBox(height: AppSpacing.xs),
        // Gerçek güç: kart gücü + kimya (sunucunun kullandığı değer)
        _GucEtiketi(move: m, color: renk),
      ],
    );
  }
}

class _GucEtiketi extends StatelessWidget {
  final MatchMove move;
  final Color color;

  const _GucEtiketi({required this.move, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.obsidian.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${move.effectivePower ?? 0}',
              style: AppTypography.display(size: 18, weight: FontWeight.w900),
            ),
            if (move.hasChemistry)
              TextSpan(
                text: '  (${move.power} +${move.chemistry} kimya)',
                style: AppTypography.body(
                  size: 10.5,
                  weight: FontWeight.w800,
                  color: AppColors.emerald,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// SONUÇ BANDI
// ====================================================================
class _SonucBandi extends StatelessWidget {
  final ClashEvent event;

  const _SonucBandi({required this.event});

  @override
  Widget build(BuildContext context) {
    final renk = switch (event.outcome) {
      ClashOutcome.win => AppColors.victoryGold,
      ClashOutcome.loss => AppColors.danger,
      ClashOutcome.draw => AppColors.textSecondary,
    };
    final detay = event.detail;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.obsidian.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: renk.withValues(alpha: 0.7), width: 1.5),
        boxShadow: AppShadows.glow(renk, siddet: 0.8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            event.position == null
                ? 'TUR ${event.roundNumber}'
                : 'TUR ${event.roundNumber} · ${event.position!.label.toUpperTr()}',
            style: AppTypography.label,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            event.headline,
            textAlign: TextAlign.center,
            style: AppTypography.display(
              size: 40,
              weight: FontWeight.w900,
              color: renk,
              height: 1,
            ),
          ),
          if (detay.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              detay,
              textAlign: TextAlign.center,
              style: AppTypography.bodyS,
            ),
          ],
        ],
      ),
    );
  }
}

// ====================================================================
// DÜELLO RESSAMI
// ====================================================================
/// Sahadaki iki oyuncu ve top. Hepsi [ArenaProjection] ile perspektife
/// oturtuluyor: uzaktaki (rakip) küçük, yakındaki (ben) büyük.
///
/// Her mevki için ayrı bir senaryo (MD bölüm 6):
///   FORVET    -> kazanan çalımlayarak ilerler ve şut atar
///   DEFANS    -> ikisi ortada çarpışır, top kazananın tarafına seker
///   ORTA SAHA -> kazanan takım arkadaşlarıyla pas yapar, rakip kovalar
///   KALECİ    -> kaybeden şut atar, kazanan kaleci uzanıp kurtarır
///   BERABERLİK-> ikisi topa aynı anda gelir, top ortada kalır
///
/// Senaryo, kazananı sunucudan gelen [ClashEvent.outcome]'dan okuyor;
/// güç karşılaştırması yapmıyor.
class DuelPainter extends CustomPainter {
  final ClashEvent event;

  /// Düello aşamasının ilerlemesi (0-1)
  final double progress;

  DuelPainter({required this.event, required this.progress});

  static const Color _benimRenk = AppColors.cyan;
  static const Color _rakipRenk = AppColors.danger;

  /// Oyuncuların başlangıç derinlikleri
  static const double _benimV = 0.82;
  static const double _rakipV = 0.20;

  @override
  void paint(Canvas canvas, Size size) {
    final p = ArenaProjection(size);
    final s = senaryo(event, progress);

    // Arkadaşlar (orta saha pası)
    for (final a in s.arkadaslar) {
      _oyuncu(
        canvas,
        p,
        a,
        s.kazananBen ? _benimRenk : _rakipRenk,
        soluk: true,
      );
    }

    // Uzaktaki önce (sıralama: yakın olan üstte görünsün)
    final oyuncular = [
      if (s.rakip != null) (s.rakip!, _rakipRenk),
      if (s.ben != null) (s.ben!, _benimRenk),
    ]..sort((a, b) => a.$1.dy.compareTo(b.$1.dy));
    for (final (konum, renk) in oyuncular) {
      _oyuncu(canvas, p, konum, renk);
    }

    _top(canvas, p, s.top, s.topIzi);

    // Çarpışma ışığı
    if (s.patlama > 0) {
      final m = p.project(s.patlamaYeri.dx, s.patlamaYeri.dy);
      final r = 70 * s.patlama;
      canvas.drawCircle(
        m,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.75 * (1 - s.patlama)),
              AppColors.victoryGold.withValues(alpha: 0.35 * (1 - s.patlama)),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(center: m, radius: r)),
      );
    }
  }

  void _oyuncu(
    Canvas canvas,
    ArenaProjection p,
    Offset uv,
    Color renk, {
    bool soluk = false,
  }) {
    final m = p.project(uv.dx, uv.dy);
    final olcek = p.scaleAt(uv.dy);
    // Taban yarıçapı büyük tutuldu: düello çoğu zaman sahanın uzak
    // yarısında geçiyor ve perspektif oyuncuları küçültüyor; küçük
    // ekranda 10 piksellik bir nokta "oyuncu" olarak okunmuyordu.
    final r = 22 * olcek + 7;
    final a = soluk ? 0.35 : 1.0;

    // Zemin gölgesi (perspektifte basık elips)
    canvas.drawOval(
      Rect.fromCenter(center: m, width: r * 2.4, height: r * 0.8),
      Paint()..color = Colors.black.withValues(alpha: 0.45 * a),
    );
    // Gövde: zeminden yukarıda duran disk
    final govde = m.translate(0, -r * 0.9);
    canvas.drawCircle(
      govde,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: [
            Color.lerp(renk, Colors.white, 0.45)!.withValues(alpha: a),
            renk.withValues(alpha: a),
          ],
        ).createShader(Rect.fromCircle(center: govde, radius: r)),
    );
    canvas.drawCircle(
      govde,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.85 * a),
    );
  }

  void _top(Canvas canvas, ArenaProjection p, Offset uv, List<Offset> iz) {
    // İz: topun hızını gösteren solan noktalar
    for (var i = 0; i < iz.length; i++) {
      final m = p.project(iz[i].dx, iz[i].dy);
      canvas.drawCircle(
        m.translate(0, -6),
        3.5 * p.scaleAt(iz[i].dy) + 1,
        Paint()..color = Colors.white.withValues(alpha: 0.12 * (i + 1)),
      );
    }

    final m = p.project(uv.dx, uv.dy);
    final r = 7.5 * p.scaleAt(uv.dy) + 3.5;
    canvas.drawOval(
      Rect.fromCenter(center: m, width: r * 2.2, height: r * 0.7),
      Paint()..color = Colors.black.withValues(alpha: 0.5),
    );
    final top = m.translate(0, -r * 1.3);
    canvas.drawCircle(top, r, Paint()..color = Colors.white);
    canvas.drawCircle(top, r * 0.38, Paint()..color = const Color(0xFF111827));
  }

  @override
  bool shouldRepaint(DuelPainter eski) =>
      eski.progress != progress || eski.event != event;

  // ==================================================================
  // SENARYOLAR
  // ==================================================================
  /// [progress] anında sahnedeki her şeyin saha konumu.
  ///
  /// Saf fonksiyon: aynı girdi her zaman aynı kareyi verir. Bu sayede
  /// test edilebilir (ör. "forvet senaryosunda top kaybedenin kalesinde
  /// bitiyor mu?").
  static DuelFrame senaryo(ClashEvent olay, double progress) {
    final t = progress.clamp(0.0, 1.0);
    final kazananBen = olay.outcome == ClashOutcome.win;
    final beraberlik = olay.outcome == ClashOutcome.draw;

    // Kazanan ve kaybedenin başlangıç noktaları
    final kV = kazananBen ? _benimV : _rakipV;
    final yV = kazananBen ? _rakipV : _benimV;

    // Kaybedenin kale çizgisi (şut buraya gider)
    final kaybedenKalesi = kazananBen ? 0.0 : 1.0;
    final kazananKalesi = kazananBen ? 1.0 : 0.0;

    DuelFrame cerceve({
      required Offset kazanan,
      required Offset? kaybeden,
      required Offset top,
      List<Offset> iz = const [],
      List<Offset> arkadaslar = const [],
      double patlama = 0,
      Offset? patlamaYeri,
    }) {
      return DuelFrame(
        ben: kazananBen || beraberlik ? kazanan : kaybeden,
        rakip: kazananBen || beraberlik ? kaybeden : kazanan,
        top: top,
        topIzi: iz,
        arkadaslar: arkadaslar,
        patlama: patlama,
        patlamaYeri: patlamaYeri ?? top,
        kazananBen: kazananBen,
      );
    }

    double e(double x) => Curves.easeInOutCubic.transform(x.clamp(0.0, 1.0));
    double a(double bas, double bit) =>
        ((t - bas) / (bit - bas)).clamp(0.0, 1.0);
    Offset ara(Offset x, Offset y, double k) => Offset.lerp(x, y, k)!;

    // Patlama: düellonun sonunda (genel zaman çizelgesinde 0.74)
    final patlama = a(0.88, 1.0);

    // ---------------------------------------------------------------
    // BERABERLİK: ikisi topa aynı anda yetişir
    // ---------------------------------------------------------------
    if (beraberlik) {
      const merkez = Offset(0.5, 0.5);
      final k = e(a(0, 0.6));
      final ben = ara(const Offset(0.5, _benimV), const Offset(0.5, 0.57), k);
      final rakip = ara(const Offset(0.5, _rakipV), const Offset(0.5, 0.43), k);
      // Top ortada iki oyuncu arasında gidip gelir
      final salinim =
          math.sin(a(0.55, 1.0) * math.pi * 4) * 0.025 * (1 - a(0.85, 1.0));
      return DuelFrame(
        ben: ben,
        rakip: rakip,
        top: merkez.translate(0, salinim),
        topIzi: const [],
        arkadaslar: const [],
        patlama: patlama,
        patlamaYeri: merkez,
        kazananBen: false,
      );
    }

    // ---------------------------------------------------------------
    // PAS: rakip yok, kazanan topu tek başına kaleye taşır
    // ---------------------------------------------------------------
    final kaybedenPas = kazananBen ? olay.opponentPassed : olay.iPassed;
    final pozisyon = kaybedenPas ? CardPosition.forward : olay.position;

    switch (pozisyon) {
      // -------------------------------------------------------------
      // DEFANS: ortada çarpışma
      // -------------------------------------------------------------
      case CardPosition.defender:
        final k = e(a(0, 0.55));
        final carpismaV = 0.5 + (kV - 0.5) * 0.08;
        final kazanan = ara(Offset(0.48, kV), Offset(0.5, carpismaV), k);
        var kaybeden = ara(Offset(0.52, yV), Offset(0.5, 1 - carpismaV), k);
        // Çarpışmadan sonra kaybeden geri savrulur
        final savrulma = e(a(0.55, 0.8));
        kaybeden = kaybeden.translate(
          0.08 * savrulma,
          (yV - 0.5) * 0.25 * savrulma,
        );
        // Top: ortada başlar, çarpışmada kazananın tarafına seker
        final topYer = ara(
          const Offset(0.5, 0.5),
          Offset(0.42, 0.5 + (kV - 0.5) * 0.45),
          e(a(0.55, 0.95)),
        );
        return cerceve(
          kazanan: kazanan,
          kaybeden: kaybedenPas ? null : kaybeden,
          top: topYer,
          patlama: math.max(patlama, a(0.5, 0.7) * (1 - a(0.7, 0.85))),
          patlamaYeri: const Offset(0.5, 0.5),
        );

      // -------------------------------------------------------------
      // ORTA SAHA: pas üçgeni
      // -------------------------------------------------------------
      case CardPosition.midfielder:
        final yon = kazananBen ? -1.0 : 1.0; // rakip kalesine doğru
        final kazanan = Offset(0.38, 0.5 - yon * 0.05);
        final a1 = Offset(0.68, 0.5 + yon * 0.10);
        final a2 = Offset(0.46, 0.5 + yon * 0.22);
        final duraklar = [kazanan, a1, a2, kazanan.translate(0.05, yon * 0.12)];
        final adim = (t * 3).clamp(0.0, 2.999);
        final i = adim.floor();
        final topYer = ara(duraklar[i], duraklar[i + 1], e(adim - i));
        // Kaybeden topu kovalar ama hep bir adım geride
        final kaybeden = ara(
          Offset(0.5, yV),
          ara(duraklar[math.max(0, i)], topYer, 0.4),
          e(a(0.1, 1.0)) * 0.85,
        );
        return cerceve(
          kazanan: ara(kazanan, duraklar.last, e(a(0.66, 1.0))),
          kaybeden: kaybedenPas ? null : kaybeden,
          top: topYer,
          iz: [
            for (final g in [0.06, 0.04, 0.02])
              ara(
                duraklar[((t - g) * 3).clamp(0.0, 2.999).floor()],
                duraklar[((t - g) * 3).clamp(0.0, 2.999).floor() + 1],
                e(((t - g) * 3).clamp(0.0, 2.999) % 1),
              ),
          ],
          arkadaslar: [a1, a2],
          patlama: patlama,
        );

      // -------------------------------------------------------------
      // KALECİ: kaybeden şut atar, kazanan kurtarır
      // -------------------------------------------------------------
      case CardPosition.goalkeeper:
        // Yakın kale ekranın dışında kalıyor (kamera sahanın içinde);
        // kaleci görünsün diye kale ağzı biraz içeride.
        final kaleV = kazananKalesi == 1.0 ? 0.90 : 0.05;
        final sutcu = Offset(0.45, 0.5 + (kaleV - 0.5) * 0.25);
        final hedef = Offset(0.58, kaleV);
        // Top 0.25'te ayaktan çıkar, 0.85'te kaleciye ulaşır
        final ucus = e(a(0.25, 0.85));
        final topYer = ara(sutcu.translate(0.02, 0), hedef, ucus);
        // Kaleci önce yerinde, sonra topa uzanır
        final kaleci = ara(Offset(0.5, kaleV), hedef, e(a(0.55, 0.85)));
        return cerceve(
          kazanan: kaleci,
          kaybeden: kaybedenPas ? null : sutcu,
          top: topYer,
          // Uçuş sırasında topun arkasında kısa bir iz
          iz: ucus > 0.05 && ucus < 1
              ? [
                  for (final g in [0.15, 0.10, 0.05])
                    ara(sutcu, hedef, (ucus - g).clamp(0.0, 1.0)),
                ]
              : const [],
          patlama: patlama,
          patlamaYeri: hedef,
        );

      // -------------------------------------------------------------
      // FORVET (ve varsayılan): çalım + şut
      // -------------------------------------------------------------
      case CardPosition.forward:
      case null:
        final hucumYonu = kaybedenKalesi == 0.0 ? -1.0 : 1.0;
        // Kazanan kendi yarı sahasından kaybedenin kalesine doğru,
        // zikzak çizerek ilerler
        final ilerleme = e(a(0, 0.65));
        final basV = 0.5 - hucumYonu * 0.18;
        final sonV = 0.5 + hucumYonu * 0.28;
        final zikzak = math.sin(ilerleme * math.pi * 3) * 0.12;
        final kazanan = Offset(0.5 + zikzak, basV + (sonV - basV) * ilerleme);
        // Kaybeden araya girmeye çalışır, ıskalar
        final kaybeden = ara(
          Offset(0.62, yV),
          Offset(0.5 - zikzak * 0.6 + 0.12, sonV + hucumYonu * 0.08),
          e(a(0.15, 0.7)),
        );
        // Şut: 0.65'ten sonra top kaleye
        final kale = Offset(0.53, kaybedenKalesi == 0.0 ? 0.0 : 1.0);
        final ayak = kazanan.translate(0, hucumYonu * 0.025);
        final sut = e(a(0.65, 0.92));
        final topYer = ara(ayak, kale, sut);
        return cerceve(
          kazanan: kazanan,
          kaybeden: kaybedenPas ? null : kaybeden,
          top: topYer,
          iz: sut > 0 && sut < 1
              ? [
                  for (final g in [0.15, 0.1, 0.05])
                    ara(ayak, kale, (sut - g).clamp(0.0, 1.0)),
                ]
              : const [],
          patlama: patlama,
          patlamaYeri: kale,
        );
    }
  }
}

/// Düellonun tek bir karesi (saha koordinatlarıyla)
class DuelFrame {
  /// Benim oyuncum (pas geçtiysem null)
  final Offset? ben;

  /// Rakibin oyuncusu (pas geçtiyse null)
  final Offset? rakip;

  final Offset top;
  final List<Offset> topIzi;

  /// Orta saha senaryosundaki pas arkadaşları
  final List<Offset> arkadaslar;

  /// Çarpışma ışığı (0 = yok, 1 = sönmüş)
  final double patlama;
  final Offset patlamaYeri;

  final bool kazananBen;

  const DuelFrame({
    required this.ben,
    required this.rakip,
    required this.top,
    required this.topIzi,
    required this.arkadaslar,
    required this.patlama,
    required this.patlamaYeri,
    required this.kazananBen,
  });
}
