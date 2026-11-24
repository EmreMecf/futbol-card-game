
import 'package:material_ui/material_ui.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/platform/orientation_policy.dart';
import 'package:futbol_card/core/router/app_routes.dart';
import 'package:futbol_card/core/theme/app_theme.dart';
import 'package:futbol_card/core/utils/result.dart';
import 'package:futbol_card/features/auth/domain/repositories/auth_repository.dart';
import 'package:futbol_card/features/auth/presentation/view/login_view.dart';
import 'package:futbol_card/features/auth/presentation/view/register_view.dart';
import 'package:futbol_card/features/auth/presentation/viewmodel/auth_view_model.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

/// Davet linkiyle gelen, giriş yapmamış oyuncu giriş/kayıttan sonra odaya
/// dönmeli; açılışta ekran ölçüsü gelmese de tablet telefon sanılmamalı.
void main() {
  final kod = 'ab12' * 7 + 'cd';

  setUpAll(() => dotenv.loadFromString(envString: 'ENABLE_LOGGING=false'));

  group('davet adresi', () {
    test('giriş adresinde taşınır ve giriş bitince odaya döner', () {
      final giris = AppRoutes.loginFor(AppRoutes.friendInviteWithCode(kod));
      expect(giris, '${AppRoutes.login}?davet=$kod');
      expect(AppRoutes.afterAuth(Uri.parse(giris)), AppRoutes.friendInviteWithCode(kod));
    });

    test('kayıt ekranına geçerken korunur', () {
      final kayit = AppRoutes.registerFrom(Uri.parse('${AppRoutes.login}?davet=$kod'));
      expect(AppRoutes.afterAuth(Uri.parse(kayit)), AppRoutes.friendInviteWithCode(kod));
    });

    test('davet yoksa ya da kod geçersizse ana sayfa', () {
      expect(AppRoutes.loginFor(AppRoutes.collection), AppRoutes.login);
      expect(AppRoutes.loginFor('${AppRoutes.friendInvite}/gecersiz'), AppRoutes.login);
      expect(AppRoutes.afterAuth(Uri.parse(AppRoutes.login)), AppRoutes.home);
      expect(AppRoutes.afterAuth(Uri.parse('${AppRoutes.login}?davet=//kotu.site')), AppRoutes.home);
    });
  });

  Future<void> ac(WidgetTester t, String baslangic) async {
    t.view.physicalSize = const Size(390, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final router = GoRouter(
      initialLocation: baslangic,
      routes: [
        GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginView()),
        GoRoute(path: AppRoutes.register, builder: (_, _) => const RegisterView()),
        GoRoute(
          path: AppRoutes.home,
          builder: (_, _) => const Scaffold(body: Text('ANA SAYFA')),
        ),
        GoRoute(
          path: '${AppRoutes.friendInvite}/:code',
          builder: (_, s) => Scaffold(body: Text('ODA ${s.pathParameters['code']}')),
        ),
      ],
    );
    await t.pumpWidget(
      ChangeNotifierProvider<AuthViewModel>(
        create: (_) => AuthViewModel(_Repo()),
        child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
      ),
    );
    await t.pumpAndSettle();
  }

  Finder alan(String etiket) => find.widgetWithText(TextFormField, etiket);

  testWidgets('giriş bitince davet odası açılır', (t) async {
    await ac(t, '${AppRoutes.login}?davet=$kod');
    await t.enterText(alan('E-posta'), 'emre@test.com');
    await t.enterText(alan('Şifre'), '123456');
    await t.tap(find.text('GİRİŞ YAP'));
    await t.pumpAndSettle();
    expect(find.text('ODA $kod'), findsOneWidget);
  });

  testWidgets('kayıt bitince davet odası açılır', (t) async {
    await ac(t, '${AppRoutes.register}?davet=$kod');
    await t.enterText(find.byType(TextFormField).at(0), 'emre');
    await t.enterText(find.byType(TextFormField).at(1), 'emre@test.com');
    await t.enterText(find.byType(TextFormField).at(2), '123456');
    await t.ensureVisible(find.text('HESAP OLUŞTUR'));
    await t.pumpAndSettle();
    await t.tap(find.text('HESAP OLUŞTUR'));
    await t.pump(const Duration(milliseconds: 500));
    await t.pump(const Duration(seconds: 5));
    await t.pumpAndSettle();
    expect(find.text('ODA $kod'), findsOneWidget);
  });

  group('ekran yönü', () {
    test('telefon dikey, tablet serbest, web serbest', () {
      expect(orientationPolicyFor(const Size(1170, 2532), 3, isWeb: false), OrientationPolicy.portraitOnly);
      expect(orientationPolicyFor(const Size(1640, 2360), 2, isWeb: false), OrientationPolicy.free);
      expect(orientationPolicyFor(const Size(1170, 2532), 3, isWeb: true), OrientationPolicy.free);
    });

    test('ölçü henüz gelmediyse karar ertelenir', () {
      expect(orientationPolicyFor(Size.zero, 2, isWeb: false), OrientationPolicy.unknown);
      expect(orientationPolicyFor(const Size(1640, 2360), 0, isWeb: false), OrientationPolicy.unknown);
    });
  });
}

class _Repo implements AuthRepository {
  static const _u = UserModel(id: 'u1', username: 'Emre');

  @override
  Future<Result<UserModel>> signIn({required String email, required String password}) async => const Success(_u);

  @override
  Future<Result<UserModel>> signUp({required String email, required String password, required String username}) async =>
      const Success(_u);

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
