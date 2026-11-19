import 'package:flutter/material.dart';

import '../../../../ui_v21/screens/auth/v21_splash_art.dart';
import '../../../../ui_v21/ui_v21.dart';

/// Giriş ve kayıt ekranlarının ortak iskeleti (referans login.png):
/// stadyum, logo, üç karakter ve altta form paneli.
class AuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  /// Üstte geri düğmesi (kayıt ekranında)
  final bool showBack;

  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBack = false,
  });

  /// Formun en fazla genişliği
  static const double maxFormWidth = 420;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: V21Colors.inkDeep,
      body: LayoutBuilder(
        builder: (context, box) {
          final k = V21Scale.forSize(box.biggest).s;
          final heroH = (box.maxHeight * 0.3).clamp(0.0, 300.0);
          return Stack(
            fit: StackFit.expand,
            children: [
              const V21StadiumScene(horizon: 0.42),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(16 * k, 12 * k, 16 * k, 20 * k),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: maxFormWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(child: V21Logo(scale: k * 0.82)),
                          if (box.maxHeight >= 640)
                            SizedBox(
                              height: heroH,
                              child: ExcludeSemantics(
                                child: ShaderMask(
                                  blendMode: BlendMode.dstIn,
                                  shaderCallback: (r) => const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, Colors.white, Colors.white],
                                    stops: [0, 0.16, 1],
                                  ).createShader(r),
                                  child: Image.asset(
                                    V21Assets.loginHeroes,
                                    fit: BoxFit.cover,
                                    alignment: Alignment.topCenter,
                                  ),
                                ),
                              ),
                            ),
                          V21GamePanel(
                            scale: k,
                            radius: 18,
                            padding: EdgeInsets.all(16 * k),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  title,
                                  textAlign: TextAlign.center,
                                  style: V21Type.title(28 * k, shadows: V21Type.inkShadow(k)),
                                ),
                                SizedBox(height: 2 * k),
                                Text(
                                  subtitle,
                                  textAlign: TextAlign.center,
                                  style: V21Type.label(12.5 * k, weight: FontWeight.w700, color: V21Colors.textMuted),
                                ),
                                SizedBox(height: 14 * k),
                                child,
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (showBack)
                Align(
                  alignment: Alignment.topLeft,
                  child: SafeArea(
                    child: Padding(
                      padding: EdgeInsets.all(8 * k),
                      child: V21BackButton(scale: k, onPressed: () => Navigator.of(context).maybePop()),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Giriş ve kayıt alanının ortak görünümü
InputDecoration authFieldDecoration(String label, IconData icon, {String? helper, Widget? suffix}) => InputDecoration(
  labelText: label,
  helperText: helper,
  counterText: '',
  prefixIcon: Icon(icon, color: V21Colors.textMuted),
  suffixIcon: suffix,
  filled: true,
  fillColor: const Color(0xFF241552),
  labelStyle: V21Type.label(14, weight: FontWeight.w700, color: V21Colors.textMuted),
  helperStyle: V21Type.label(11, weight: FontWeight.w600, color: V21Colors.textMuted),
  errorStyle: V21Type.label(11.5, weight: FontWeight.w800, color: const Color(0xFFFF8A9B)),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: V21Colors.pillBorder, width: 2),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: V21Colors.goldTop, width: 2),
  ),
);

/// Formun içindeki hata şeridi: SnackBar klavyenin arkasında kalıyordu
class AuthErrorBanner extends StatelessWidget {
  final String message;

  /// Bağlantı hatası mı? (farklı simge ve ek açıklama)
  final bool isConnection;

  const AuthErrorBanner({super.key, required this.message, this.isConnection = false});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: V21Colors.danger.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: V21Colors.danger, width: 1.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isConnection ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
              color: const Color(0xFFFF8A9B),
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isConnection ? '$message\nİnternet bağlantını kontrol edip tekrar dene.' : message,
                style: V21Type.label(12.5, weight: FontWeight.w700, color: Colors.white, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
