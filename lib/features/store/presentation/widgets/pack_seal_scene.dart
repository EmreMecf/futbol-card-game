import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/feedback/game_feedback.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/premium_card/premium_card.dart';
import 'pack_box.dart';

/// MÜHÜRLÜ PAKET SAHNESİ (MD bölüm 4-G: "animasyonlu paket modeli,
/// dokunarak açma").
///
/// ===================================================================
/// SONUCU BU SAHNE BELİRLEMİYOR
/// ===================================================================
/// Bu ekran açıldığında kartlar SUNUCUDA zaten belirlenmiş ve
/// envantere yazılmış durumda (`open_pack()`). Sahne yalnızca bir
/// perde: dokunmak hiçbir ihtimali değiştirmez.
///
/// Patlamadan hemen önceki parıltı, paketin EN İYİ kartının seviye
/// rengini alır (FIFA'daki "walkout ışığı" gibi). Bu da sunucunun
/// verdiği sonucun gösterimi; ek bilgi uydurulmuyor.
///
/// AKIŞ:
///   1. Bekleme: paket süzülür, üstünden ışık geçer.  (dokunana kadar)
///   2. Dokunma: paket titrer, parıltı büyür.          (~0,55 sn)
///   3. Patlama: beyaz flaş, paket büyüyüp kaybolur.   (~0,45 sn)
///   4. [onOpened] -> kartlar sırayla açılır.
///
/// Animasyonlar kapalıysa (Ayarlar) dokunma doğrudan [onOpened]'ı
/// çağırır. "Hepsini göster" her an kartları atlayıp özete gider.
class PackSealScene extends StatefulWidget {
  final PackOpenResult result;

  /// Kutunun rengi (paketin imza seviyesi). Bilinmiyorsa altın.
  final CardTier packTier;

  final VoidCallback onOpened;
  final VoidCallback onSkipAll;

  const PackSealScene({
    super.key,
    required this.result,
    required this.onOpened,
    required this.onSkipAll,
    this.packTier = CardTier.gold,
  });

  /// Dokunduktan sonra açılışın süresi
  static const openDuration = Duration(milliseconds: 1000);

  @override
  State<PackSealScene> createState() => _PackSealSceneState();
}

class _PackSealSceneState extends State<PackSealScene>
    with TickerProviderStateMixin {
  /// Bekleme hareketi (süzülme + ışık geçişi), sürekli döner
  late final AnimationController _bekleme;

  /// Dokunduktan sonraki titreme + patlama
  late final AnimationController _acilis;

  bool _dokunuldu = false;

  @override
  void initState() {
    super.initState();
    _bekleme = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    if (GameFeedback.cardAnimationsEnabled) _bekleme.repeat();

    _acilis = AnimationController(
      vsync: this,
      duration: PackSealScene.openDuration,
    )..addStatusListener((durum) {
        if (durum == AnimationStatus.completed) widget.onOpened();
      });
  }

  @override
  void dispose() {
    _bekleme.dispose();
    _acilis.dispose();
    super.dispose();
  }

  void _ac() {
    if (_dokunuldu) return;
    _dokunuldu = true;

    final enIyi = widget.result.bestCard?.tier ?? CardTier.bronze;
    final nadir = enIyi.rank >= CardTier.diamond.rank;
    GameFeedback.haptic(nadir ? HapticStrength.heavy : HapticStrength.medium);

    if (!GameFeedback.cardAnimationsEnabled) {
      widget.onOpened();
      return;
    }
    _bekleme.stop();
    _acilis.forward();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final enIyi = widget.result.bestCard?.tier ?? CardTier.bronze;
    final parilti = CardTierTheme.of(enIyi).glowColor;
    final kutuGenisligi =
        math.min(220.0, MediaQuery.sizeOf(context).width * 0.52);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Semantics(
          button: true,
          label: '${widget.result.packName}. Açmak için dokun.',
          child: GestureDetector(
            onTap: _ac,
            behavior: HitTestBehavior.opaque,
            child: Column(
              children: [
                // ---- ÜST BANT ----
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.result.packName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.display(
                            size: 18,
                            weight: FontWeight.w900,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: widget.onSkipAll,
                        child: const Text('Hepsini göster'),
                      ),
                    ],
                  ),
                ),

                // ---- PAKET ----
                Expanded(
                  child: Center(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_bekleme, _acilis]),
                      builder: (context, _) => _sahne(
                        kutuGenisligi: kutuGenisligi,
                        parilti: parilti,
                        nadir: enIyi.rank >= CardTier.diamond.rank,
                      ),
                    ),
                  ),
                ),

                // ---- İPUCU ----
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
                  child: AnimatedOpacity(
                    duration: AppDurations.button,
                    opacity: _dokunuldu ? 0 : 1,
                    child: Column(
                      children: [
                        Text(
                          'AÇMAK İÇİN DOKUN',
                          style: AppTypography.display(
                            size: 18,
                            weight: FontWeight.w900,
                            letterSpacing: 2,
                            color: AppColors.victoryGold,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '${widget.result.cards.length} kart seni bekliyor',
                          style: AppTypography.bodyS,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sahne({
    required double kutuGenisligi,
    required Color parilti,
    required bool nadir,
  }) {
    final b = _bekleme.value;
    final a = _acilis.value;

    // Bekleme: yavaş süzülme
    final suzulme = math.sin(b * 2 * math.pi) * 8;

    // Açılış: ilk %55 titreme + parıltı, sonrası patlama
    final titremeK = (a / 0.55).clamp(0.0, 1.0);
    final patlamaK = ((a - 0.55) / 0.45).clamp(0.0, 1.0);
    final titreme = a > 0 && a < 0.55
        ? math.sin(a * 90) * 6 * (0.4 + titremeK)
        : 0.0;
    final olcek = 1 + 0.06 * titremeK + 0.5 * Curves.easeIn.transform(patlamaK);
    final kutuOpakligi = 1 - Curves.easeIn.transform(patlamaK);
    final flas = patlamaK == 0
        ? 0.0
        : math.sin(patlamaK * math.pi).clamp(0.0, 1.0);
    final parlaklik = 0.25 + 0.75 * titremeK;

    return SizedBox(
      width: kutuGenisligi * 1.9,
      height: kutuGenisligi * 2.1,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Arka parıltı (en iyi kartın seviye rengi)
          IgnorePointer(
            child: CustomPaint(
              size: Size(kutuGenisligi * 1.9, kutuGenisligi * 1.9),
              painter: _ParlamaPainter(
                color: _dokunuldu ? parilti : AppColors.victoryGold,
                intensity: _dokunuldu ? parlaklik : 0.5,
                rays: _dokunuldu && nadir,
                turn: b + a,
              ),
            ),
          ),

          // Kutu
          Opacity(
            opacity: kutuOpakligi,
            child: Transform.translate(
              offset: Offset(titreme, suzulme * (1 - titremeK)),
              child: Transform.scale(
                scale: olcek,
                child: Transform.rotate(
                  angle: -0.06 + math.sin(b * 2 * math.pi) * 0.025,
                  child: Stack(
                    children: [
                      PackBox.visual(
                        tier: widget.packTier,
                        label: PackBox.boxLabel(
                          widget.result.packName,
                          widget.result.packSlug,
                        ),
                        width: kutuGenisligi,
                      ),
                      // Folyo üzerinde geçen ışık
                      Positioned.fill(
                        child: IgnorePointer(
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(kutuGenisligi * 0.12),
                            child: CustomPaint(
                              painter: _IsikGecisiPainter(progress: b),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Patlama flaşı
          if (flas > 0)
            IgnorePointer(
              child: Container(
                width: kutuGenisligi * 1.9 * (0.5 + patlamaK),
                height: kutuGenisligi * 1.9 * (0.5 + patlamaK),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    Colors.white.withValues(alpha: flas),
                    parilti.withValues(alpha: flas * 0.6),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Paketin arkasındaki hale; nadir kartta dönen ışık hüzmeleri.
class _ParlamaPainter extends CustomPainter {
  final Color color;
  final double intensity;
  final bool rays;
  final double turn;

  _ParlamaPainter({
    required this.color,
    required this.intensity,
    required this.rays,
    required this.turn,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final m = size.center(Offset.zero);
    final r = size.width / 2;

    canvas.drawCircle(
      m,
      r,
      Paint()
        ..shader = RadialGradient(colors: [
          color.withValues(alpha: 0.55 * intensity),
          color.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: m, radius: r)),
    );

    if (!rays) return;
    final boya = Paint()..color = color.withValues(alpha: 0.18 * intensity);
    const adet = 14;
    for (var i = 0; i < adet; i++) {
      final a = turn * math.pi + i * 2 * math.pi / adet;
      canvas.drawPath(
        Path()
          ..moveTo(m.dx, m.dy)
          ..lineTo(m.dx + r * math.cos(a - 0.07), m.dy + r * math.sin(a - 0.07))
          ..lineTo(m.dx + r * math.cos(a + 0.07), m.dy + r * math.sin(a + 0.07))
          ..close(),
        boya,
      );
    }
  }

  @override
  bool shouldRepaint(_ParlamaPainter e) =>
      e.color != color ||
      e.intensity != intensity ||
      e.rays != rays ||
      e.turn != turn;
}

/// Folyonun üstünden çapraz geçen parlak şerit
class _IsikGecisiPainter extends CustomPainter {
  final double progress;

  _IsikGecisiPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // Döngünün ilk %45'inde geçiyor, kalan sürede bekliyor
    final k = (progress / 0.45).clamp(0.0, 1.0);
    if (k <= 0 || k >= 1) return;
    final x = -size.width + k * size.width * 3;
    final rect = Rect.fromLTWH(x, 0, size.width * 0.5, size.height);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.28),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_IsikGecisiPainter e) => e.progress != progress;
}
