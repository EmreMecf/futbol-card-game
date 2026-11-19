import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../shared/widgets/error_snackbar.dart';
import '../../../../ui_v21/ui_v21.dart';
import '../viewmodel/auth_view_model.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_validators.dart';
import '../widgets/social_auth_buttons.dart';

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
    // Davet linkiyle gelindiyse kayıt bitince o odaya dönülür
    final hedef = AppRoutes.afterAuth(GoRouterState.of(context).uri);
    final basarili = await viewModel.signUp(
      email: _emailController.text,
      password: _passwordController.text,
      username: _usernameController.text,
    );

    if (!mounted) return;

    if (basarili) {
      AppSnackBar.showSuccess(context, 'Hesabın oluşturuldu! Başlangıç kadron hazır.');
      context.go(hedef);
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
      title: 'KADRONU KUR',
      subtitle: 'Hesabını oluştur; başlangıç kadron hemen hazır olsun.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _usernameController,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newUsername],
              maxLength: AuthValidators.maxUsernameLength,
              onChanged: (_) => _hataTemizle(),
              style: V21Type.label(15, weight: FontWeight.w700, color: Colors.white),
              decoration: authFieldDecoration(
                'Kullanıcı adı',
                Icons.person_outline_rounded,
                helper: 'Rakiplerin seni bu adla görecek',
              ),
              validator: AuthValidators.username,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              onChanged: (_) => _hataTemizle(),
              style: V21Type.label(15, weight: FontWeight.w700, color: Colors.white),
              decoration: authFieldDecoration('E-posta', Icons.mail_outline_rounded),
              validator: AuthValidators.email,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              onChanged: (_) => _hataTemizle(),
              onFieldSubmitted: (_) => _submit(),
              style: V21Type.label(15, weight: FontWeight.w700, color: Colors.white),
              decoration: authFieldDecoration(
                'Şifre',
                Icons.lock_outline_rounded,
                helper: 'En az ${AuthValidators.minPasswordLength} karakter',
                suffix: IconButton(
                  tooltip: _obscurePassword ? 'Şifreyi göster' : 'Şifreyi gizle',
                  color: V21Colors.textMuted,
                  icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: AuthValidators.password,
            ),
            if (hata != null) ...[
              const SizedBox(height: 12),
              AuthErrorBanner(message: hata.message, isConnection: hata.type == AppErrorType.network),
            ],
            const SizedBox(height: 16),
            V21GameButton(
              label: 'HESAP OLUŞTUR',
              size: V21ButtonSize.large,
              status: viewModel.isBusy ? V21ButtonStatus.loading : V21ButtonStatus.normal,
              onPressed: _submit,
            ),
            SocialAuthButtons(onError: (e) => setState(() => _hata = e)),
          ],
        ),
      ),
    );
  }
}
