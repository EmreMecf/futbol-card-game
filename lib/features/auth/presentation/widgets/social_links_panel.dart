import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../../../core/di/injection.dart';
import '../../../../ui_v21/ui_v21.dart';
import '../../data/social/google_web_button.dart';
import '../../domain/repositories/social_auth_repository.dart';
import '../../../../core/l10n/app_language.dart';

/// Ayarlar → HESAP: Google / Apple hesabını, giriş yapmış oyuncunun hesabına bağlar.
///
/// Aynı e-postalı hesaplar kendiliğinden birleşmez; bağlama yalnız burada,
/// hesabın sahibi giriş yapmışken olur. Hiçbir sağlayıcı ayarlı değilse yer kaplamaz.
class SocialLinksPanel extends StatefulWidget {
  final double scale;
  const SocialLinksPanel({super.key, this.scale = 1});

  @override
  State<SocialLinksPanel> createState() => _SocialLinksPanelState();
}

class _SocialLinksPanelState extends State<SocialLinksPanel> {
  SocialAuthRepository? get _repo => getIt.isRegistered<SocialAuthRepository>()
      ? getIt<SocialAuthRepository>()
      : null;

  Set<SocialProvider> _linked = {};
  SocialProvider? _busy;
  String? _message;
  StreamSubscription<SocialCredential>? _webGoogle;

  @override
  void initState() {
    super.initState();
    _load();
    final r = _repo;
    if (r != null && r.googleAvailable && r.usesWebGoogleButton) {
      _webGoogle = r.webGoogleCredentials.listen(_link);
    }
  }

  @override
  void dispose() {
    _webGoogle?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final sonuc = await _repo?.linkedProviders();
    final v = sonuc?.dataOrNull;
    if (v != null && mounted) setState(() => _linked = v);
  }

  Future<void> _start(SocialProvider p) async {
    final r = _repo;
    if (r == null || _busy != null) return;
    setState(() {
      _busy = p;
      _message = null;
    });
    final kimlik = await r.obtainCredential(p);
    final c = kimlik.dataOrNull;
    if (c == null) {
      if (mounted) setState(() => _busy = null);
      return;
    }
    await _link(c);
  }

  Future<void> _link(SocialCredential c) async {
    final r = _repo;
    if (r == null) return;
    if (mounted) setState(() => _busy = c.provider);
    final sonuc = await r.link(c);
    if (!mounted) return;
    setState(() {
      _busy = null;
      _message = sonuc.isSuccess
          ? 'Hesap bağlandı.'.tr
          : (sonuc.errorOrNull?.message ?? 'Bağlanamadı. Tekrar dene.'.tr);
    });
    if (sonuc.isSuccess) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final r = _repo;
    if (r == null || (!r.googleAvailable && !r.appleAvailable)) {
      return const SizedBox.shrink();
    }
    final k = widget.scale;
    Widget satir(SocialProvider p, String ad) {
      final bagli = _linked.contains(p);
      final Widget sag;
      if (bagli) {
        sag = Text(
          'BAĞLI'.tr,
          style: V21Type.title(18 * k, color: V21Colors.successText),
        );
      } else if (p == SocialProvider.google && r.usesWebGoogleButton) {
        sag = buildGoogleWebButton();
      } else {
        sag = SizedBox(
          width: 120 * k,
          child: V21GameButton(
            label: 'BAĞLA'.tr,
            tone: V21ButtonTone.blue,
            size: V21ButtonSize.small,
            scale: k,
            status: _busy == p
                ? V21ButtonStatus.loading
                : V21ButtonStatus.normal,
            semanticsLabel: '{ad} hesabını bağla'.trArgs({'ad': ad}),
            onPressed: () => _start(p),
          ),
        );
      }
      return Padding(
        padding: EdgeInsets.only(top: 10 * k),
        child: Row(
          children: [
            Expanded(
              child: Text(
                ad,
                style: V21Type.label(15 * k, weight: FontWeight.w800),
              ),
            ),
            Flexible(child: sag),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 14 * k),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'BAĞLI HESAPLAR'.tr,
            style: V21Type.label(
              12 * k,
              weight: FontWeight.w900,
              color: V21Colors.textMuted,
              letterSpacing: 0.4,
            ),
          ),
          if (r.googleAvailable) satir(SocialProvider.google, 'Google'),
          if (r.appleAvailable) satir(SocialProvider.apple, 'Apple'),
          if (_message != null)
            Padding(
              padding: EdgeInsets.only(top: 8 * k),
              child: Text(
                _message!,
                style: V21Type.label(
                  12 * k,
                  weight: FontWeight.w700,
                  color: V21Colors.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
