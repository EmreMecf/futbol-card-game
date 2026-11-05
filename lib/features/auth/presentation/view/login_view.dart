import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/game/game_ui.dart';
import '../viewmodel/auth_view_model.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_validators.dart';

/// Giriş ekranı.
///
/// MVVM NOTU: Bu sınıf sadece "gösterim" yapar. Hiçbir iş mantığı
/// içermez; bütün işlemleri [AuthViewModel] üzerinden yapar.
class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  /// Son denemenin hatası (formun içinde gösterilir)
  AppException? _hata;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _hata = null);

    final viewModel = context.read<AuthViewModel>();
    final basarili = await viewModel.signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (basarili) {
      context.go(AppRoutes.home);
    } else {
      setState(() => _hata = viewModel.error);
      viewModel.clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AuthViewModel>();
    final hata = _hata;

    return AuthScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GameLogo(size: 42),
          const SizedBox(height: AppSpacing.xxxl),
          GlassPanel(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('TEKRAR HOŞ GELDİN', style: AppTypography.h2),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Kadrona dönmek için giriş yap.',
                    style: AppTypography.bodyS,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    onChanged: (_) => _hataTemizle(),
                    decoration: const InputDecoration(
                      labelText: 'E-posta',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                    validator: AuthValidators.email,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onChanged: (_) => _hataTemizle(),
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Şifre',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword
                            ? 'Şifreyi göster'
                            : 'Şifreyi gizle',
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    validator: AuthValidators.password,
                  ),

                  if (hata != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    AuthErrorBanner(
                      message: hata.message,
                      isConnection: hata.type == AppErrorType.network,
                    ),
                  ],

                  const SizedBox(height: AppSpacing.xl),
                  GameButton(
                    label: 'Giriş yap',
                    icon: Icons.login_rounded,
                    isLoading: viewModel.isBusy,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Wrap: dar ekranda ya da büyük yazı boyutunda alt satıra geçer
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Hesabın yok mu?', style: AppTypography.bodyS),
              TextButton(
                onPressed: viewModel.isBusy
                    ? null
                    : () => context.push(AppRoutes.register),
                child: Text(
                  'Hemen kaydol',
                  style: AppTypography.body(
                    size: 13,
                    weight: FontWeight.w900,
                    color: AppColors.victoryGold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Oyuncu yazmaya başlayınca eski hata kaybolsun; yoksa düzeltilmiş
  /// bir e-postanın altında hâlâ "hatalı" yazıyor olurdu.
  void _hataTemizle() {
    if (_hata != null) setState(() => _hata = null);
  }
}
