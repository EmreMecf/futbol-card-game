import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_models/shared_models.dart';

import '../premium_card/premium_card.dart';
import 'club_crest.dart';
import 'confetti_overlay.dart';
import 'nation_flag.dart';
import 'spotlight_backdrop.dart';

/// WALKOUT — Diamond/Legend kartın görkemli açılış sahnesi.
///
/// ===================================================================
/// SAHNE AKIŞI (toplam ~4.6 saniye)
/// ===================================================================
///   0.0 - 0.5 sn : Ekran kararır, stadyum ışıkları yanar
///   0.5 - 1.5 sn : BAYRAK belirir, 1 saniye durur
///   1.5 - 2.5 sn : POZİSYON belirir, 1 saniye durur
///   2.5 - 3.5 sn : KULÜP ARMASI belirir, 1 saniye durur
///   3.5 - 4.2 sn : KART ekrana VURUR + titreşim + konfeti
///   4.2 - 4.6 sn : Sahne oturur, "devam et" yazısı belirir
///
/// ===================================================================
/// NEDEN TEK BİR AnimationController?
/// ===================================================================
/// Dört aşama için dört ayrı controller kurmak akla yatkın görünür ama
/// yanlıştır:
///
///   * Her controller kendi Ticker'ını kaydeder. Dört ticker, her
///     karede dört ayrı uyanma ve dört ayrı `setState` zinciri demek.
///   * Aşamaları birbirine zincirlemek (`.then()`) gerekir; bir tanesi
///     yarıda kesilirse (kullanıcı atlarsa) hepsini tek tek durdurmak
///     zorunda kalırsın ve kaçırılan bir tanesi arka planda çalışmaya
///     devam eder.
///   * Sahneyi ileri sarmak imkânsız hâle gelir.
///
/// Tek controller + `Interval` eğrileri ile: tek ticker, tek `dispose`,
/// ve "atla" düğmesi tek satır (`_kontrolcu.value = _kartAni`).
///
/// ===================================================================
/// flutter_animate PAKETİ NEDEN KULLANILMADI?
/// ===================================================================
/// Yaptığı iş tam olarak yukarıdaki `Interval` mantığının daha kısa
/// yazımı. Bu ekran için üç sebeple native tercih edildi:
///   1. Projeye yeni bir bağımlılık girmiyor,
///   2. Kartın vuruş anını `HapticFeedback` ve konfeti ile KARE
///      HASSASİYETİNDE eşlemek gerekiyor; bunu controller dinleyicisi
///      ile yapmak paket API'siyle yapmaktan daha doğrudan,
///   3. Projedeki diğer animasyonlar (kart eğilme, holografik parlama)
///      zaten native controller kullanıyor; tek bir yaklaşım olması
///      bakımı kolaylaştırıyor.
class WalkoutScreen extends StatefulWidget {
  final InventoryCard card;

  /// Sahne bitince ya da kullanıcı devam edince çağrılır
  final VoidCallback onContinue;

  const WalkoutScreen({
    super.key,
    required this.card,
    required this.onContinue,
  });

  @override
  State<WalkoutScreen> createState() => _WalkoutScreenState();
}

class _WalkoutScreenState extends State<WalkoutScreen>
    with TickerProviderStateMixin {
  // ---- SAHNE ZAMAN ÇİZELGESİ (0-1 aralığında oranlar) ----
  // Milisaniye yerine oran kullanıyoruz ki toplam süreyi değiştirmek
  // istediğimizde tek bir sayıyı (_toplamSure) değiştirmek yetsin.
  static const Duration _toplamSure = Duration(milliseconds: 4600);

  static const double _isikBas = 0.00;
  static const double _bayrakBas = 0.11; //  500 ms
  static const double _pozisyonBas = 0.33; // 1500 ms
  static const double _kulupBas = 0.54; // 2500 ms
  static const double _kartBas = 0.76; // 3500 ms

  late final AnimationController _kontrolcu = AnimationController(
    vsync: this,
    duration: _toplamSure,
  );

  /// Işıkların yavaş salınımı. Sahne dursa bile ışıklar canlı kalsın
  /// diye AYRI ve sürekli tekrar eden bir controller.
  late final AnimationController _salinim = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  )..repeat();

  bool _konfetiPatladi = false;
  bool _sahneBitti = false;

  CardTierTheme get _tema => CardTierTheme.of(widget.card.tier);

  @override
  void initState() {
    super.initState();

    _kontrolcu.addListener(_zamanlayiciDinle);
    _kontrolcu.addStatusListener((durum) {
      if (durum == AnimationStatus.completed && mounted) {
        setState(() => _sahneBitti = true);
      }
    });

    _kontrolcu.forward();
  }

  /// Sahne ilerledikçe titreşim ve konfetiyi tetikler.
  ///
  /// NEDEN LISTENER, NEDEN Future.delayed DEĞİL?
  /// `Future.delayed(3500ms)` ile tetiklemek, kullanıcı sahneyi
  /// atladığında bile 3.5 saniye sonra patlayan bir zamanlayıcı
  /// bırakırdı. Controller'ın değerini dinlemek, sahne ileri sarılsa
  /// bile doğru anı yakalar — çünkü "an" bir saat değil, animasyonun
  /// kendi ilerlemesi.
  void _zamanlayiciDinle() {
    final t = _kontrolcu.value;

    if (!_konfetiPatladi && t >= _kartBas) {
      _konfetiPatladi = true;

      // Kart ekrana VURUYOR: en güçlü titreşim burada.
      HapticFeedback.heavyImpact();

      // setState sadece konfetiyi başlatmak için; sahnenin geri kalanı
      // AnimatedBuilder ile çiziliyor ve bundan etkilenmiyor.
      if (mounted) setState(() {});
    }
  }

  /// Sahneyi atla — doğrudan kartın vuruş anına git
  void _atla() {
    if (_kontrolcu.value >= _kartBas) {
      widget.onContinue();
      return;
    }
    _kontrolcu.value = _kartBas;
    _kontrolcu.forward();
  }

  @override
  void dispose() {
    _kontrolcu.removeListener(_zamanlayiciDinle);
    _kontrolcu.dispose();
    _salinim.dispose();
    super.dispose();
  }

  // ==================================================================
  // AŞAMA GÖRÜNÜRLÜĞÜ
  // ==================================================================
  /// Bir aşamanın [t] anındaki durumu.
  ///
  /// Aşama üç bölümden oluşur:
  ///   giriş (0.18)  -> büyüyerek belirir
  ///   bekleme       -> tam görünür durur (kullanıcının istediği 1 sn)
  ///   çıkış (0.18)  -> küçülerek kaybolur
  ///
  /// Dönen değer: (saydamlık, ölçek)
  ({double opacity, double scale}) _asama(double t, double bas, double bit) {
    if (t < bas || t > bit) return (opacity: 0, scale: 0.86);

    final sure = bit - bas;
    final yerel = (t - bas) / sure;

    const girisOrani = 0.18;
    const cikisOrani = 0.18;

    if (yerel < girisOrani) {
      final p = Curves.easeOutBack.transform(yerel / girisOrani);
      return (opacity: (yerel / girisOrani).clamp(0.0, 1.0), scale: 0.72 + p * 0.28);
    }

    if (yerel > 1 - cikisOrani) {
      final p = (1 - yerel) / cikisOrani;
      return (opacity: p.clamp(0.0, 1.0), scale: 1.0 + (1 - p) * 0.10);
    }

    return (opacity: 1, scale: 1);
  }

  /// Kartın vuruş animasyonu.
  ///
  /// Kart uzaktan (ölçek 2.3) hızla küçülerek "ekrana çarpar",
  /// easeOutBack ile hafifçe geri seker. Bu tek eğri, kartın ağırlığı
  /// olduğu hissini veren şeydir; doğrusal bir ölçek animasyonu
  /// kartın süzülerek geldiğini düşündürürdü.
  ({double opacity, double scale, double shock}) _kartVurusu(double t) {
    if (t < _kartBas) return (opacity: 0, scale: 2.3, shock: 0);

    final yerel = ((t - _kartBas) / (1 - _kartBas)).clamp(0.0, 1.0);

    // Çarpma ilk %45'te tamamlanır; kalanı oturma süresi
    final carpma = (yerel / 0.45).clamp(0.0, 1.0);
    final p = Curves.easeOutBack.transform(carpma);

    return (
      opacity: (yerel / 0.15).clamp(0.0, 1.0),
      scale: 2.3 - p * 1.3,
      // Şok dalgası halkası çarpma anında doğar ve genişleyip söner
      shock: carpma,
    );
  }

  // ==================================================================
  // ÇİZİM
  // ==================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF04070F),
      body: GestureDetector(
        onTap: _atla,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ---- ZEMİN: karartma + spot ışıkları ----
            AnimatedBuilder(
              animation: Listenable.merge([_kontrolcu, _salinim]),
              builder: (context, _) {
                final isik = ((_kontrolcu.value - _isikBas) / 0.11)
                    .clamp(0.0, 1.0);
                return SpotlightBackdrop(
                  progress: isik,
                  sway: _salinim.value,
                  color: _tema.frameGradient[1],
                );
              },
            ),

            // ---- AŞAMALAR ----
            // Hepsi aynı anda ağaçta duruyor ama sadece sırası gelen
            // görünür oluyor. Aşamaları ekleyip çıkarmak (build/dispose)
            // her geçişte bir kare atlamasına yol açardı; saydamlık
            // değiştirmek bedavaya yakın.
            AnimatedBuilder(
              animation: _kontrolcu,
              builder: (context, _) {
                final t = _kontrolcu.value;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    _asamaKatmani(
                      _asama(t, _bayrakBas, _pozisyonBas),
                      NationFlag(code: widget.card.nationality, width: 170),
                    ),
                    _asamaKatmani(
                      _asama(t, _pozisyonBas, _kulupBas),
                      _pozisyonGosterimi(),
                    ),
                    _asamaKatmani(
                      _asama(t, _kulupBas, _kartBas),
                      ClubCrest(clubName: widget.card.club, size: 140),
                    ),
                  ],
                );
              },
            ),

            // ---- KART ----
            AnimatedBuilder(
              animation: _kontrolcu,
              // child: kartın kendisi SADECE BİR KEZ kuruluyor.
              // Her karede yeniden yaratılsaydı, kartın kendi
              // animasyonları (holografik parlama, dönen çerçeve)
              // sürekli baştan başlar ve titrerdi.
              child: _kartGovdesi(),
              builder: (context, kart) {
                final v = _kartVurusu(_kontrolcu.value);
                if (v.opacity <= 0) return const SizedBox.shrink();

                return Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (v.shock > 0 && v.shock < 1)
                        _sokDalgasi(v.shock),
                      Opacity(
                        opacity: v.opacity,
                        child: Transform.scale(scale: v.scale, child: kart),
                      ),
                    ],
                  ),
                );
              },
            ),

            // ---- KONFETİ ----
            ConfettiOverlay(
              active: _konfetiPatladi,
              colors: [
                _tema.frameGradient[1],
                _tema.textColor,
                Colors.white,
                _tema.glowColor.withValues(alpha: 1),
              ],
            ),

            // ---- ALT BİLGİ ----
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 34),
                child: AnimatedOpacity(
                  opacity: _sahneBitti ? 1 : 0.45,
                  duration: const Duration(milliseconds: 400),
                  child: Text(
                    _sahneBitti ? 'Devam etmek için dokun' : 'Atlamak için dokun',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12.5,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bir aşamayı ekranın ortasına, verilen saydamlık/ölçekle yerleştirir
  Widget _asamaKatmani(
    ({double opacity, double scale}) durum,
    Widget cocuk,
  ) {
    if (durum.opacity <= 0) return const SizedBox.shrink();

    return Center(
      child: Opacity(
        opacity: durum.opacity,
        child: Transform.scale(scale: durum.scale, child: cocuk),
      ),
    );
  }

  // ------------------------------------------------------------------
  // 2. AŞAMA: POZİSYON
  // ------------------------------------------------------------------
  Widget _pozisyonGosterimi() {
    final pozisyon = widget.card.position;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Kısa kod büyük ve baskın: FIFA'da da ekrana "ST" vurur
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_tema.textColor, _tema.frameGradient[1]],
          ).createShader(rect),
          child: Text(
            pozisyon.code,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 86,
              height: 1.0,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          pozisyon.label.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.82),
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 4,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // 4. AŞAMA: KART
  // ------------------------------------------------------------------
  Widget _kartGovdesi() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Seviye şeridi
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: _tema.frameGradient),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: _tema.glowColor, blurRadius: 18),
            ],
          ),
          child: Text(
            widget.card.tier == CardTier.legend
                ? 'LEGEND'
                : widget.card.tier.label.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(height: 18),

        // ---- 3B EĞİLEN KART ----
        // Eğilme/paralaks CardTilt içinde yaşıyor: Transform matrisine
        // perspektif (setEntry(3, 2, 0.001)) ekleyip iki eksende
        // döndürüyor. Burada tekrar yazmıyoruz — koleksiyondaki kartla
        // BİREBİR aynı davranması, tek yerden gelmesiyle garanti.
        _EgilebilirKart(
          child: PremiumPlayerCard.fromInventory(
            widget.card,
            width: 230,
            interactive: false, // eğilmeyi dıştaki sarmalayıcı yönetiyor
          ),
        ),
      ],
    );
  }

  /// Çarpma anında dışa açılan halka
  Widget _sokDalgasi(double ilerleme) {
    return IgnorePointer(
      child: CustomPaint(
        size: const Size(360, 360),
        painter: _ShockwavePainter(
          progress: ilerleme,
          color: _tema.frameGradient[1],
        ),
      ),
    );
  }
}

// ====================================================================
// EĞİLEBİLİR SARMALAYICI
// ====================================================================
/// Kartı parmak/jiroskop hareketine göre 3B eğer.
///
/// Kartın kendi `interactive` modunu kapatıp eğilmeyi buraya almamızın
/// sebebi: walkout'ta kartın ölçeği de animasyonlu. İki ayrı Transform
/// iç içe girdiğinde eğilme merkezi kayıyordu. Burada eğilme dıştaki
/// ölçekten BAĞIMSIZ tek bir katmanda uygulanıyor.
///
/// =====================================================================
/// DENETLEYİCİNİN SAHİBİ NEDEN BURASI?
/// =====================================================================
/// İlk yazımda `CardTiltController` dıştaki [WalkoutScreen] tarafından
/// tutuluyor, ticker'ı ise buradaki State veriyordu. Widget ağacı
/// dağıtılırken ÖNCE çocuk (bu State) yok ediliyor, denetleyici ise
/// hâlâ ebeveynin elinde ve merkeze dönüş animasyonu çalışır durumda
/// kalıyordu:
///
///   "_EgilebilirKartState was disposed with an active Ticker."
///
/// Yani kullanıcı kartı sürüklerken sahneden çıkarsa arka planda
/// durdurulamayan bir ticker kalıyordu. Kural basit: TICKER'I VEREN
/// STATE, CONTROLLER'IN DA SAHİBİ OLMALI.
class _EgilebilirKart extends StatefulWidget {
  final Widget child;

  const _EgilebilirKart({required this.child});

  @override
  State<_EgilebilirKart> createState() => _EgilebilirKartState();
}

class _EgilebilirKartState extends State<_EgilebilirKart>
    with SingleTickerProviderStateMixin {
  late final CardTiltController _kontrolcu;
  Size _boyut = Size.zero;

  @override
  void initState() {
    super.initState();
    _kontrolcu = CardTiltController();
    // Masaüstü ve web'de sessizce devre dışı kalır
    _kontrolcu.enableGyroscope();
  }

  @override
  void dispose() {
    // super.dispose()'dan ÖNCE: ticker'ın serbest bırakılması şart
    _kontrolcu.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, kisitlar) {
        return GestureDetector(
          onPanStart: (d) => _guncelle(d.localPosition),
          onPanUpdate: (d) => _guncelle(d.localPosition),
          onPanEnd: (_) => _kontrolcu.reset(vsync: this),
          onPanCancel: () => _kontrolcu.reset(vsync: this),
          child: AnimatedBuilder(
            animation: _kontrolcu,
            // child: kart ağacı bir kez kurulup yeniden kullanılıyor.
            // Eğilme saniyede 60 kez değişiyor; kartı her seferinde
            // yeniden kurmak 60 FPS'i imkânsız kılardı.
            child: widget.child,
            builder: (context, cocuk) {
              final egim = _kontrolcu.value;

              final matris = Matrix4.identity()
                // Perspektif: bu satır olmadan döndürme 3B değil,
                // düz bir ezilme gibi görünür.
                ..setEntry(3, 2, 0.0011)
                ..rotateY(egim.dx * 0.22)
                ..rotateX(-egim.dy * 0.22);

              return Transform(
                alignment: Alignment.center,
                transform: matris,
                child: cocuk,
              );
            },
          ),
        );
      },
    );
  }

  void _guncelle(Offset yerel) {
    if (_boyut == Size.zero) {
      final kutu = context.findRenderObject() as RenderBox?;
      if (kutu != null) _boyut = kutu.size;
    }
    if (_boyut == Size.zero) return;
    _kontrolcu.updateFromPointer(yerel, _boyut);
  }
}

// ====================================================================
// ŞOK DALGASI
// ====================================================================
class _ShockwavePainter extends CustomPainter {
  final double progress;
  final Color color;

  _ShockwavePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final merkez = Offset(size.width / 2, size.height / 2);
    final yaricap = size.width * 0.18 + size.width * 0.42 * progress;

    canvas.drawCircle(
      merkez,
      yaricap,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10 * (1 - progress)
        ..color = color.withValues(alpha: 0.55 * (1 - progress)),
    );
  }

  @override
  bool shouldRepaint(_ShockwavePainter eski) => eski.progress != progress;
}
