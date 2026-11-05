import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/error_snackbar.dart';
import '../../../../shared/widgets/game/game_ui.dart';
import '../viewmodel/auth_view_model.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_validators.dart';

/// Kayıt ekranı.
class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  AppException? _hata;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _hata = null);

    final viewModel = context.read<AuthViewModel>();
    final basarili = await viewModel.signUp(
      email: _emailController.text,
      password: _passwordController.text,
      username: _usernameController.text,
    );

    if (!mounted) return;

    if (basarili) {
      AppSnackBar.showSuccess(
        context,
        'Hesabın oluşturuldu! Başlangıç kadron hazır.',
      );
      context.go(AppRoutes.home);
    } else {
      setState(() => _hata = viewModel.error);
      viewModel.clearError();
    }
  }

  void _hataTemizle() {
    if (_hata != null) setState(() => _hata = null);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AuthViewModel>();
    final hata = _hata;

    return AuthScaffold(
      showBack: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GameLogo(size: 30, showTagline: false),
          const SizedBox(height: AppSpacing.xxl),
          GlassPanel(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('KADRONU KUR', style: AppTypography.h2),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Hesabını oluştur; 15 kartlık başlangıç kadron hemen '
                    'hazır olsun.',
                    style: AppTypography.bodyS,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  TextFormField(
                    controller: _usernameController,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newUsername],
                    maxLength: AuthValidators.maxUsernameLength,
                    onChanged: (_) => _hataTemizle(),
                    decoration: const InputDecoration(
                      labelText: 'Kullanıcı adı',
                      helperText: 'Rakiplerin seni bu adla görecek',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                      counterText: '',
                    ),
                    validator: AuthValidators.username,
                  ),
                  const SizedBox(height: AppSpacing.md),

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
                    autofillHints: const [AutofillHints.newPassword],
                    onChanged: (_) => _hataTemizle(),
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Şifre',
                      helperText:
                          'En az ${AuthValidators.minPasswordLength} karakter',
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
                    label: 'Hesap oluştur',
                    icon: Icons.person_add_alt_1_rounded,
                    isLoading: viewModel.isBusy,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
