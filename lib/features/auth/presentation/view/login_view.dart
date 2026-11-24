import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../ui_v21/ui_v21.dart';
import '../viewmodel/auth_view_model.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_validators.dart';
import '../widgets/social_auth_buttons.dart';

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
    // Davet linkiyle gelindiyse giriş bitince o odaya dönülür
    final hedef = AppRoutes.afterAuth(GoRouterState.of(context).uri);
    final basarili = await viewModel.signIn(email: _emailController.text, password: _passwordController.text);

    if (!mounted) return;

    if (basarili) {
      context.go(hedef);
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
      title: 'HOŞ GELDİN!',
      subtitle: 'Kadrona dönmek için giriş yap.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
              autofillHints: const [AutofillHints.password],
              onChanged: (_) => _hataTemizle(),
              onFieldSubmitted: (_) => _submit(),
              style: V21Type.label(15, weight: FontWeight.w700, color: Colors.white),
              decoration: authFieldDecoration(
                'Şifre',
                Icons.lock_outline_rounded,
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
              label: 'GİRİŞ YAP',
              size: V21ButtonSize.large,
              status: viewModel.isBusy ? V21ButtonStatus.loading : V21ButtonStatus.normal,
              onPressed: _submit,
            ),
            SocialAuthButtons(onError: (e) => setState(() => _hata = e)),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Hesabın yok mu?',
                  style: V21Type.label(13, weight: FontWeight.w700, color: V21Colors.textMuted),
                ),
                TextButton(
                  onPressed: viewModel.isBusy
                      ? null
                      : () => context.push(AppRoutes.registerFrom(GoRouterState.of(context).uri)),
                  child: Text('KAYDOL', style: V21Type.title(17, color: V21Colors.goldTop)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Oyuncu yazmaya başlayınca eski hata kaybolsun; yoksa düzeltilmiş
  /// bir e-postanın altında hâlâ "hatalı" yazıyor olurdu.
  void _hataTemizle() {
    if (_hata != null) setState(() => _hata = null);
  }
}
