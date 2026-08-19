import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import 'card_frame_painter.dart';
import 'card_tier_theme.dart';
import 'card_tilt.dart';
import 'holographic_shine.dart';

/// FIFA/EA FC Ultimate Team seviyesinde futbolcu karti.
///
/// KATMAN SIRASI (arkadan one):
///   1. Dis isik (glow)          - seviyeye gore renkli golge
///   2. Cerceve (CustomPaint)    - metalik degrade + pahli silue
///   3. Oyuncu gorseli           - seffaf arka planli, paralaks kayar
///   4. Bilgi katmani            - guc, pozisyon, isim, kulup
///   5. Holografik parlama       - uzerinden gecen isik (Altin ve ustu)
///   6. Yuzey yansimasi          - egilmeye gore kayan parlaklik
///   7. Rozetler                 - koruma kalkani, kilit
///
/// Tum bu yigin [CardTilt] icine sarilir; boylece dokunma veya
/// jiroskop ile 3B egilir.
class PremiumPlayerCard extends StatefulWidget {
  final String fullName;
  final CardPosition position;
  final CardTier tier;
  final int power;
  final String? imageUrl;
  final String? nationality;
  final String? club;

  /// Kartin genisligi. Yukseklik oran ile hesaplanir (FIFA orani ~0.70).
  final double width;

  /// Kart korumaya alindi mi? (kalkan rozeti gosterilir)
  final bool isProtected;

  /// Kart baska bir macta kilitli mi? (soluk gosterilir)
  final bool isLocked;

  /// Kart oynandi mi? (maç ekraninda gri gosterilir)
  final bool isPlayed;

  /// Secili mi? (kadro kurarken)
  final bool isSelected;

  /// Etkilesim acik mi?
  ///
  /// LISTE PERFORMANSI: Koleksiyon ekraninda yuzlerce kart olabilir.
  /// Orada `interactive: false` verip egilme ve holografik animasyonu
  /// kapatmak gerekir; yoksa her kart kendi AnimationController'ini
  /// calistirir ve arayuz takilir.
  final bool interactive;

  /// Jiroskop ile egilme (sadece tekil, buyuk gosterimlerde acilmali)
  final bool useGyroscope;

  final VoidCallback? onTap;

  const PremiumPlayerCard({
    super.key,
    required this.fullName,
    required this.position,
    required this.tier,
    required this.power,
    this.imageUrl,
    this.nationality,
    this.club,
    this.width = 200,
    this.isProtected = false,
    this.isLocked = false,
    this.isPlayed = false,
    this.isSelected = false,
    this.interactive = true,
    this.useGyroscope = false,
    this.onTap,
  });

  /// Envanterdeki bir karttan olustur
  factory PremiumPlayerCard.fromInventory(
    InventoryCard kart, {
    Key? key,
    double width = 200,
    bool isSelected = false,
    bool interactive = true,
    bool useGyroscope = false,
    VoidCallback? onTap,
  }) {
    return PremiumPlayerCard(
      key: key,
      fullName: kart.fullName,
      position: kart.position,
      tier: kart.tier,
      power: kart.power,
      imageUrl: kart.imageUrl,
      nationality: kart.nationality,
      club: kart.club,
      width: width,
      isLocked: kart.isLocked,
      isSelected: isSelected,
      interactive: interactive,
      useGyroscope: useGyroscope,
      onTap: onTap,
    );
  }

  /// Mactaki elden bir karttan olustur
  factory PremiumPlayerCard.fromHand(
    HandCard kart, {
    Key? key,
    double width = 140,
    bool interactive = true,
    VoidCallback? onTap,
  }) {
    return PremiumPlayerCard(
      key: key,
      fullName: kart.fullName,
      position: kart.position,
      tier: kart.tier,
      power: kart.power,
      imageUrl: kart.imageUrl,
      width: width,
      isProtected: kart.isProtected,
      isPlayed: kart.isPlayed,
      interactive: interactive,
      onTap: onTap,
    );
  }

  @override
  State<PremiumPlayerCard> createState() => _PremiumPlayerCardState();
}

class _PremiumPlayerCardState extends State<PremiumPlayerCard>
    with SingleTickerProviderStateMixin {
  late final CardTiltController _egim;

  /// FIFA kartlarinin en/boy orani
  static const double _enBoyOrani = 0.70;

  @override
  void initState() {
    super.initState();
    _egim = CardTiltController();

    if (widget.interactive && widget.useGyroscope) {
      _egim.enableGyroscope();
    }
  }

  @override
  void dispose() {
    _egim.dispose();
    super.dispose();
  }

  double get _yukseklik => widget.width / _enBoyOrani;

  @override
  Widget build(BuildContext context) {
    final tema = CardTierTheme.of(widget.tier);
    final boyut = Size(widget.width, _yukseklik);

    Widget kart = _kartYigini(tema, boyut);

    // Egilme sadece etkilesimli modda
    if (widget.interactive) {
      kart = CardTilt(controller: _egim, child: kart);

      kart = GestureDetector(
        onTap: widget.onTap,
        onPanStart: (d) => _egim.updateFromPointer(d.localPosition, boyut),
        onPanUpdate: (d) => _egim.updateFromPointer(d.localPosition, boyut),
        onPanEnd: (_) => _egim.reset(vsync: this),
        onPanCancel: () => _egim.reset(vsync: this),
        child: kart,
      );
    } else if (widget.onTap != null) {
      kart = GestureDetector(onTap: widget.onTap, child: kart);
    }

    // RepaintBoundary: kartin kendi cizim katmani olur. Egilme
    // animasyonu ekranin geri kalanini yeniden cizmeye zorlamaz.
    return RepaintBoundary(child: kart);
  }

  // ==================================================================
  // KATMANLARIN BIRLESIMI
  // ==================================================================
  Widget _kartYigini(CardTierTheme tema, Size boyut) {
    final soluk = widget.isLocked || widget.isPlayed;

    return AnimatedBorderGlow(
      theme: tema,
      enabled: widget.interactive,
      builder: (context, aci) {
        return SizedBox(
          width: boyut.width,
          height: boyut.height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ---- 1) DIS ISIK ----
              _disIsik(tema),

              // ---- 2) CERCEVE ----
              CustomPaint(
                painter: CardFramePainter(
                  theme: tema,
                  gradientRotation: aci,
                  cornerRadius: boyut.width * 0.09,
                  bevel: boyut.width * 0.13,
                ),
              ),

              // ---- 3+4) GORSEL VE BILGILER (kart siluetine kirpilir) ----
              ClipPath(
                clipper: _KartSiluetiKirpici(
                  cornerRadius: boyut.width * 0.09,
                  bevel: boyut.width * 0.13,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _oyuncuGorseli(tema, boyut),
                    _bilgiKatmani(tema, boyut),

                    // ---- 5) HOLOGRAFIK PARLAMA ----
                    HolographicShine(
                      theme: tema,
                      enabled: widget.interactive,
                    ),

                    // ---- 6) YUZEY YANSIMASI ----
                    if (widget.interactive)
                      SpecularHighlight(
                        controller: _egim,
                        color: tema.specularColor,
                        borderRadius: BorderRadius.circular(boyut.width * 0.09),
                      ),
                  ],
                ),
              ),

              // ---- 7) ROZETLER ----
              if (widget.isProtected) _korumaRozeti(boyut),
              if (widget.isLocked) _kilitRozeti(boyut),

              // ---- SOLUKLASTIRMA ----
              if (soluk)
                IgnorePointer(
                  child: ClipPath(
                    clipper: _KartSiluetiKirpici(
                      cornerRadius: boyut.width * 0.09,
                      bevel: boyut.width * 0.13,
                    ),
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.55),
                    ),
                  ),
                ),

              // ---- SECIM CERCEVESI ----
              if (widget.isSelected) _secimCercevesi(boyut),
            ],
          ),
        );
      },
    );
  }

  // ==================================================================
  // 1) DIS ISIK
  // ==================================================================
  Widget _disIsik(CardTierTheme tema) {
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: tema.glowColor,
              blurRadius: tema.glowRadius,
              spreadRadius: tema.glowRadius * 0.15,
            ),
            // Zemine oturma golgesi
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
      ),
    );
  }

  // ==================================================================
  // 3) OYUNCU GORSELI
  // ==================================================================
  // PARALAKS: Gorsel, egilmenin TERSI yonde hafifce kayar. Bu, oyuncunun
  // cercevenin arkasinda derinlikte durdugu hissini verir - kartin
  // "duz bir resim" degil, katmanli bir nesne gibi gorunmesini saglar.
  Widget _oyuncuGorseli(CardTierTheme tema, Size boyut) {
    final gorsel = _gorselWidget(tema, boyut);

    if (!widget.interactive) {
      return Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(top: boyut.height * 0.10),
          child: gorsel,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _egim,
      child: gorsel,
      builder: (context, cachedChild) {
        final egim = _egim.value;
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: boyut.height * 0.10),
            child: Transform.translate(
              offset: Offset(-egim.dx * 8, -egim.dy * 6),
              child: cachedChild,
            ),
          ),
        );
      },
    );
  }

  /// Gorseli yukler; yoksa ya da yuklenemezse siluet gosterir.
  ///
  /// NOT: Kart gorselleri yapay zeka ile uretilmis 3D Pixar tarzi,
  /// ARKA PLANI SEFFAF (PNG) karakterler olacak. Seffaf olmasi sart;
  /// aksi halde gorselin dikdortgen kenari cercevenin uzerinde
  /// gorunur ve kartin butunlugu bozulur.
  Widget _gorselWidget(CardTierTheme tema, Size boyut) {
    final yol = widget.imageUrl;
    final gorselYuksekligi = boyut.height * 0.52;

    if (yol == null || yol.isEmpty) {
      return _siluet(tema, gorselYuksekligi);
    }

    if (yol.startsWith('http://') || yol.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: yol,
        height: gorselYuksekligi,
        fit: BoxFit.contain,
        fadeInDuration: const Duration(milliseconds: 250),
        placeholder: (_, _) => _siluet(tema, gorselYuksekligi),
        errorWidget: (_, _, _) => _siluet(tema, gorselYuksekligi),
      );
    }

    if (yol.startsWith('assets/')) {
      return Image.asset(
        yol,
        height: gorselYuksekligi,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _siluet(tema, gorselYuksekligi),
      );
    }

    // Sunucudan gelen goreli yol (ornek: 'cards/mid_legend_1.png').
    // Gercek gorseller hazirlanana kadar siluet gosteriyoruz.
    return _siluet(tema, gorselYuksekligi);
  }

  /// Gorsel yokken gosterilen stilize siluet.
  /// Bos bir kutu yerine kartin kimligini koruyan bir yer tutucu.
  Widget _siluet(CardTierTheme tema, double yukseklik) {
    return SizedBox(
      height: yukseklik,
      child: ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (rect) => LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            tema.textColor.withValues(alpha: 0.35),
            tema.textColor.withValues(alpha: 0.08),
          ],
        ).createShader(rect),
        child: Icon(
          Icons.person,
          size: yukseklik,
          color: Colors.white,
        ),
      ),
    );
  }

  // ==================================================================
  // 4) BILGI KATMANI
  // ==================================================================
  Widget _bilgiKatmani(CardTierTheme tema, Size boyut) {
    // Tum yazi boyutlari kart genisligine oranli. Boylece ayni widget
    // hem 90 piksellik liste kucugunde hem 300 piksellik vitrinde
    // dogru gorunur.
    final olcek = boyut.width;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: olcek * 0.09,
        vertical: olcek * 0.08,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- UST SOL: GUC VE POZISYON ----
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '${widget.power}',
                    style: TextStyle(
                      fontSize: olcek * 0.20,
                      height: 1.0,
                      fontWeight: FontWeight.w900,
                      color: tema.textColor,
                      shadows: const [
                        Shadow(color: Colors.black54, blurRadius: 4),
                      ],
                    ),
                  ),
                  Text(
                    widget.position.shortLabel,
                    style: TextStyle(
                      fontSize: olcek * 0.095,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: tema.mutedTextColor,
                    ),
                  ),
                  SizedBox(height: olcek * 0.03),
                  Container(
                    width: olcek * 0.14,
                    height: 1.5,
                    color: tema.mutedTextColor.withValues(alpha: 0.5),
                  ),
                  SizedBox(height: olcek * 0.03),
                  if (widget.nationality != null)
                    Text(
                      widget.nationality!,
                      style: TextStyle(
                        fontSize: olcek * 0.065,
                        fontWeight: FontWeight.w600,
                        color: tema.mutedTextColor,
                      ),
                    ),
                ],
              ),
            ],
          ),

          const Spacer(),

          // ---- ALT: ISIM VE KULUP ----
          Center(
            child: Column(
              children: [
                Container(
                  height: 1,
                  width: olcek * 0.55,
                  color: tema.mutedTextColor.withValues(alpha: 0.35),
                ),
                SizedBox(height: olcek * 0.04),
                Text(
                  widget.fullName.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: olcek * 0.095,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: tema.textColor,
                    shadows: const [
                      Shadow(color: Colors.black45, blurRadius: 3),
                    ],
                  ),
                ),
                SizedBox(height: olcek * 0.02),
                Text(
                  widget.club ?? widget.tier.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: olcek * 0.062,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.8,
                    color: tema.mutedTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================================================================
  // 7) ROZETLER
  // ==================================================================
  Widget _korumaRozeti(Size boyut) {
    return Positioned(
      top: boyut.width * 0.06,
      right: boyut.width * 0.06,
      child: Tooltip(
        message: 'Bu kart korumada. Maci kaybetsen bile senden alinmaz.',
        child: Container(
          padding: EdgeInsets.all(boyut.width * 0.035),
          decoration: BoxDecoration(
            color: const Color(0xFF29CC7A),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF29CC7A).withValues(alpha: 0.6),
                blurRadius: 8,
              ),
            ],
          ),
          child: Icon(
            Icons.shield,
            size: boyut.width * 0.09,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _kilitRozeti(Size boyut) {
    return Positioned(
      top: boyut.width * 0.06,
      left: boyut.width * 0.06,
      child: Tooltip(
        message: 'Bu kart devam eden bir macta kilitli.',
        child: Icon(
          Icons.lock,
          size: boyut.width * 0.11,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }

  Widget _secimCercevesi(Size boyut) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _SecimCercevesiRessami(
          cornerRadius: boyut.width * 0.09,
          bevel: boyut.width * 0.13,
        ),
      ),
    );
  }
}

// ====================================================================
// YARDIMCI SINIFLAR
// ====================================================================

/// Icerigi kart siluetine kirpar
class _KartSiluetiKirpici extends CustomClipper<Path> {
  final double cornerRadius;
  final double bevel;

  const _KartSiluetiKirpici({required this.cornerRadius, required this.bevel});

  @override
  Path getClip(Size size) => CardFramePainter.buildCardPath(
        size,
        cornerRadius: cornerRadius,
        bevel: bevel,
      );

  @override
  bool shouldReclip(_KartSiluetiKirpici oldClipper) =>
      oldClipper.cornerRadius != cornerRadius || oldClipper.bevel != bevel;
}

/// Kadro kurarken secili kartin etrafina cizilen parlak cerceve
class _SecimCercevesiRessami extends CustomPainter {
  final double cornerRadius;
  final double bevel;

  const _SecimCercevesiRessami({
    required this.cornerRadius,
    required this.bevel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final yol = CardFramePainter.buildCardPath(
      size,
      cornerRadius: cornerRadius,
      bevel: bevel,
    );

    canvas.drawPath(
      yol,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..color = const Color(0xFF29CC7A),
    );

    canvas.drawPath(
      yol,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..color = const Color(0xFF29CC7A).withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  @override
  bool shouldRepaint(_SecimCercevesiRessami oldDelegate) => false;
}
