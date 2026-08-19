import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Kartin 3B egilme durumu.
///
/// Degerler -1.0 ile 1.0 arasindadir:
///   dx > 0  -> kart saga egilir (sag kenar uzaklasir)
///   dy > 0  -> kart asagi egilir (alt kenar uzaklasir)
///
/// NEDEN ValueNotifier?
/// Egilme saniyede 60 kez degisiyor. Bunu setState ile yapsaydik tum
/// kart agaci (gorsel, metinler, cerceve) yeniden kurulurdu. ValueNotifier
/// + AnimatedBuilder ile SADECE donusum matrisi yeniden hesaplaniyor;
/// alt widget'lar hic dokunulmadan tekrar kullaniliyor.
class CardTiltController extends ValueNotifier<Offset> {
  StreamSubscription<GyroscopeEvent>? _jiroskop;

  /// Egilmenin en fazla ne kadar olabilecegi (radyan)
  final double maxTilt;

  /// Parmak cekildikten sonra merkeze donme animasyonu
  AnimationController? _geriDonus;

  CardTiltController({this.maxTilt = 0.22}) : super(Offset.zero);

  /// Dokunma ile egilme: kartin uzerindeki yerel konumdan hesaplar.
  void updateFromPointer(Offset localPosition, Size size) {
    if (size.width == 0 || size.height == 0) return;

    // Merkezi (0,0) kabul edip -1..1 araligina normalize et
    final dx = (localPosition.dx / size.width - 0.5) * 2;
    final dy = (localPosition.dy / size.height - 0.5) * 2;

    value = Offset(dx.clamp(-1.0, 1.0), dy.clamp(-1.0, 1.0));
  }

  /// Parmak cekilince yumusakca merkeze don
  void reset({TickerProvider? vsync}) {
    if (vsync == null) {
      value = Offset.zero;
      return;
    }

    _geriDonus?.dispose();
    final baslangic = value;

    _geriDonus = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 420),
    );

    final egri = CurvedAnimation(
      parent: _geriDonus!,
      curve: Curves.easeOutBack,
    );

    egri.addListener(() {
      value = Offset.lerp(baslangic, Offset.zero, egri.value) ?? Offset.zero;
    });

    _geriDonus!.forward();
  }

  /// Jiroskop ile egilme (telefonu egdikce kart doner).
  ///
  /// NOT: Masaustu ve web'de jiroskop yoktur; bu durumda sessizce
  /// devre disi kalir ve dokunmayla egilme calismaya devam eder.
  void enableGyroscope() {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }

    try {
      _jiroskop = gyroscopeEventStream().listen(
        (olay) {
          // Jiroskop ACISAL HIZ verir (radyan/saniye), aci degil.
          // Bu yuzden degeri biriktirip sonrasinda merkeze cekiyoruz;
          // aksi halde kart yavasca kayip bir kenarda takili kalirdi.
          final yeniX = (value.dx + olay.y * 0.04).clamp(-1.0, 1.0);
          final yeniY = (value.dy - olay.x * 0.04).clamp(-1.0, 1.0);

          // Merkeze dogru hafif geri cekme (yaylanma hissi)
          value = Offset(yeniX * 0.94, yeniY * 0.94);
        },
        onError: (Object _) {
          // Sensor yoksa ya da izin reddedildiyse sessizce vazgec
          _jiroskop?.cancel();
          _jiroskop = null;
        },
        cancelOnError: true,
      );
    } catch (_) {
      // Sensor eklentisi bu platformda yok
    }
  }

  void disableGyroscope() {
    _jiroskop?.cancel();
    _jiroskop = null;
  }

  @override
  void dispose() {
    _jiroskop?.cancel();
    _geriDonus?.dispose();
    super.dispose();
  }
}

/// Karti 3B olarak egen sarmalayici.
///
/// PERSPEKTIF NASIL CALISIYOR?
/// `Matrix4.setEntry(3, 2, perspective)` matrise "kamera uzakligi"
/// ekler. Bu satir olmadan rotateX/rotateY sadece karti yassilastirir;
/// bu satirla birlikte gercek bir derinlik hissi olusur. Deger ne kadar
/// buyukse perspektif o kadar abartili olur (0.001 - 0.002 arasi
/// dogal gorunur).
class CardTilt extends StatelessWidget {
  final CardTiltController controller;
  final Widget child;

  /// Perspektif siddeti
  final double perspective;

  /// Egilme ile birlikte kart hafifce buyusun mu?
  final bool scaleOnTilt;

  const CardTilt({
    super.key,
    required this.controller,
    required this.child,
    this.perspective = 0.0014,
    this.scaleOnTilt = true,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      // child burada BIR KEZ kurulur ve her karede tekrar kullanilir.
      // Egilme degistiginde sadece Transform yeniden hesaplanir.
      child: child,
      builder: (context, cachedChild) {
        final egim = controller.value;
        final siddet = egim.distance.clamp(0.0, 1.0);

        final matris = Matrix4.identity()
          ..setEntry(3, 2, perspective)
          // Dikkat: yatay hareket Y ekseninde donme yaratir
          ..rotateY(egim.dx * controller.maxTilt)
          // Dikey hareket X ekseninde donme yaratir (isareti ters)
          ..rotateX(-egim.dy * controller.maxTilt);

        if (scaleOnTilt) {
          final olcek = 1.0 + siddet * 0.03;
          matris.scaleByDouble(olcek, olcek, 1.0, 1.0);
        }

        return Transform(
          alignment: Alignment.center,
          transform: matris,
          child: cachedChild,
        );
      },
    );
  }
}

/// Egilmeye gore yuzeyde gezinen isik yansimasi (specular highlight).
///
/// Gercek bir metal yuzeyde isik, yuzey egildikce KAYAR. Sabit bir
/// parlama kartin sticker gibi gorunmesine sebep olur; kayan parlama
/// ise "elimde tuttugum fiziksel bir nesne" hissi verir.
class SpecularHighlight extends StatelessWidget {
  final CardTiltController controller;
  final Color color;
  final BorderRadius borderRadius;

  const SpecularHighlight({
    super.key,
    required this.controller,
    required this.color,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final egim = controller.value;

          // Isik kaynagi, egilmenin TERSI yonde hareket eder
          final merkez = Alignment(-egim.dx * 1.2, -egim.dy * 1.2);
          final siddet = egim.distance.clamp(0.0, 1.0);

          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              gradient: RadialGradient(
                center: merkez,
                radius: 0.9,
                colors: [
                  color.withValues(alpha: 0.10 + siddet * 0.35),
                  color.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 1.0],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Egilme aci hesaplamalarinda kullanilan yardimci
double degreesToRadians(double derece) => derece * math.pi / 180.0;
