import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../ui_v21/ui_v21.dart';
import '../../data/social/google_web_button.dart';
import '../../domain/repositories/social_auth_repository.dart';
import '../viewmodel/auth_view_model.dart';
import 'auth_scaffold.dart';
import 'auth_validators.dart';

/// Giriş ve kayıt ekranlarındaki "Google / Apple ile devam et" bölümü.
/// Ayarlı sağlayıcı yoksa hiç yer kaplamaz.
class SocialAuthButtons extends StatefulWidget {
  /// Hata, formun kendi hata şeridinde gösterilir
  final ValueChanged<AppException?> onError;

  const SocialAuthButtons({super.key, required this.onError});

  @override
  State<SocialAuthButtons> createState() => _SocialAuthButtonsState();
}

class _SocialAuthButtonsState extends State<SocialAuthButtons> {
  StreamSubscription<SocialCredential>? _webGoogle;
  Future<void>? _webGoogleReady;

  @override
  void initState() {
    super.initState();
    final vm = context.read<AuthViewModel>();
    if (vm.googleAvailable && vm.usesWebGoogleButton) {
      _webGoogleReady = vm.prepareGoogle();
      _webGoogle = vm.webGoogleCredentials.listen((c) => _finish(vm.submitCredential(c)));
    }
  }

  @override
  void dispose() {
    _webGoogle?.cancel();
    super.dispose();
  }

  Future<void> _start(SocialProvider provider) =>
      _finish(context.read<AuthViewModel>().continueWith(provider));

  Future<void> _finish(Future<SocialAuthOutcome> pending) async {
    widget.onError(null);
    final vm = context.read<AuthViewModel>();
    // Davet linkiyle gelindiyse giriş bitince o odaya dönülür
    final target = AppRoutes.afterAuth(GoRouterState.of(context).uri);
    var outcome = await pending;
    if (!mounted) return;

    if (outcome == SocialAuthOutcome.needsUsername) {
      final done = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ChangeNotifierProvider<AuthViewModel>.value(value: vm, child: const _UsernameDialog()),
      );
      if (!mounted) return;
      if (done != true) {
        vm.cancelSocial();
        return;
      }
      outcome = SocialAuthOutcome.signedIn;
    }

    switch (outcome) {
      case SocialAuthOutcome.signedIn:
        context.go(target);
      case SocialAuthOutcome.failed:
        widget.onError(vm.error);
        vm.clearError();
      case SocialAuthOutcome.cancelled:
      case SocialAuthOutcome.needsUsername:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();
    if (!vm.googleAvailable && !vm.appleAvailable) return const SizedBox.shrink();

    final onGoogle = vm.isBusy ? null : () => _start(SocialProvider.google);
    final onApple = vm.isBusy ? null : () => _start(SocialProvider.apple);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 14),
        Row(
          children: [
            const Expanded(child: Divider(color: V21Colors.textMuted, height: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text('VEYA', style: V21Type.label(12, weight: FontWeight.w800, color: V21Colors.textMuted)),
            ),
            const Expanded(child: Divider(color: V21Colors.textMuted, height: 1)),
          ],
        ),
        const SizedBox(height: 12),
        if (vm.appleAvailable) ...[
          _ProviderButton(
            label: 'Apple ile devam et',
            background: Colors.black,
            foreground: Colors.white,
            icon: const Icon(Icons.apple, color: Colors.white, size: 24),
            onPressed: onApple,
          ),
          if (vm.googleAvailable) const SizedBox(height: 10),
        ],
        if (vm.googleAvailable)
          if (vm.usesWebGoogleButton)
            FutureBuilder<void>(
              future: _webGoogleReady,
              builder: (context, snap) => snap.connectionState == ConnectionState.done && !snap.hasError
                  ? Center(child: buildGoogleWebButton())
                  : const SizedBox(height: 44),
            )
          else
            _ProviderButton(
              label: 'Google ile devam et',
              background: Colors.white,
              foreground: const Color(0xFF1F1F1F),
              icon: const SizedBox.square(dimension: 20, child: CustomPaint(painter: _GoogleLogoPainter())),
              onPressed: onGoogle,
            ),
      ],
    );
  }
}

class _ProviderButton extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final Widget icon;
  final VoidCallback? onPressed;

  const _ProviderButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: icon,
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: background.withValues(alpha: 0.55),
          disabledForegroundColor: foreground.withValues(alpha: 0.7),
          textStyle: V21Type.label(15, weight: FontWeight.w800, color: foreground),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
    );
  }
}

/// Google'ın dört renkli "G" işareti
class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.2;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: (size.width - stroke) / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    double rad(double degree) => degree * math.pi / 180;

    canvas.drawArc(rect, rad(-40), rad(-100), false, paint..color = const Color(0xFFEA4335));
    canvas.drawArc(rect, rad(-140), rad(-85), false, paint..color = const Color(0xFFFBBC05));
    canvas.drawArc(rect, rad(135), rad(-85), false, paint..color = const Color(0xFF34A853));
    canvas.drawArc(rect, rad(50), rad(-50), false, paint..color = const Color(0xFF4285F4));
    canvas.drawRect(
      Rect.fromLTWH(size.width / 2, size.height / 2 - stroke / 2, size.width / 2, stroke),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(_GoogleLogoPainter oldDelegate) => false;
}

/// Google/Apple ile ilk kez gelen oyuncunun adını seçtiği pencere.
class _UsernameDialog extends StatefulWidget {
  const _UsernameDialog();

  @override
  State<_UsernameDialog> createState() => _UsernameDialogState();
}

class _UsernameDialogState extends State<_UsernameDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  AppException? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);
    final vm = context.read<AuthViewModel>();
    final outcome = await vm.finishWithUsername(_controller.text);
    if (!mounted) return;
    if (outcome == SocialAuthOutcome.signedIn) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = vm.error);
      vm.clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();
    final error = _error;

    return Dialog(
      backgroundColor: V21Colors.inkDeep,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: V21Colors.goldTop, width: 1.5),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AuthScaffold.maxFormWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('ADINI SEÇ', textAlign: TextAlign.center, style: V21Type.title(24, color: V21Colors.goldTop)),
                const SizedBox(height: 6),
                Text(
                  'Rakiplerin seni bu adla görecek.',
                  textAlign: TextAlign.center,
                  style: V21Type.label(13, weight: FontWeight.w700, color: V21Colors.textMuted),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _controller,
                  autofocus: true,
                  maxLength: AuthValidators.maxUsernameLength,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  style: V21Type.label(15, weight: FontWeight.w700, color: Colors.white),
                  decoration: authFieldDecoration('Kullanıcı adı', Icons.person_outline_rounded),
                  validator: AuthValidators.username,
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  AuthErrorBanner(message: error.message, isConnection: error.type == AppErrorType.network),
                ],
                const SizedBox(height: 12),
                V21GameButton(
                  label: 'OYUNA BAŞLA',
                  size: V21ButtonSize.large,
                  status: vm.isBusy ? V21ButtonStatus.loading : V21ButtonStatus.normal,
                  onPressed: _submit,
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: vm.isBusy ? null : () => Navigator.of(context).pop(false),
                  child: Text('VAZGEÇ', style: V21Type.label(13, weight: FontWeight.w800, color: V21Colors.textMuted)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
