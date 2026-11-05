import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/error/app_exception.dart';
import 'package:futbol_card/core/router/app_routes.dart';
import 'package:futbol_card/core/theme/app_theme.dart';
import 'package:futbol_card/core/utils/result.dart';
import 'package:futbol_card/features/auth/domain/repositories/auth_repository.dart';
import 'package:futbol_card/features/auth/presentation/view/login_view.dart';
import 'package:futbol_card/features/auth/presentation/view/register_view.dart';
import 'package:futbol_card/features/auth/presentation/viewmodel/auth_view_model.dart';
import 'package:futbol_card/features/auth/presentation/widgets/auth_validators.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

/// FAZ 3 — Giriş ve kayıt ekranları.
void main() {
  // ==================================================================
  // DOĞRULAMA KURALLARI — sunucuyla aynı olmalı
  // ==================================================================
  group('AuthValidators', () {
    test('sınırlar sunucu ve veritabanıyla aynı', () {
      // server/lib/routes/auth_routes.dart:
      //   password.length < 6, username 3-20
      // database/migrations/002_users.sql:
      //   check (char_length(username) between 3 and 20)
      expect(AuthValidators.minPasswordLength, 6);
      expect(AuthValidators.minUsernameLength, 3);
      expect(AuthValidators.maxUsernameLength, 20);
    });

    test('e-posta', () {
      expect(AuthValidators.email(''), isNotNull);
      expect(AuthValidators.email('emre'), isNotNull);
      expect(AuthValidators.email('  emre@test.com  '), isNull);
    });

    test('şifre', () {
      expect(AuthValidators.password('12345'), isNotNull);
      expect(AuthValidators.password('123456'), isNull);
    });

    test('kullanıcı adı', () {
      expect(AuthValidators.username('ab'), isNotNull);
      expect(AuthValidators.username('abc'), isNull);
      expect(AuthValidators.username('a' * 21), isNotNull);
      expect(AuthValidators.username('   '), isNotNull);
    });

    test('mesajlar Türkçe karakterli', () {
      // Eski ekranlarda "Gecerli", "Sifre", "Kullanici" yazıyordu
      expect(AuthValidators.email('x'), contains('Geçerli'));
      expect(AuthValidators.password(''), contains('Şifre'));
      expect(AuthValidators.username(''), contains('kullanıcı'));
    });
  });

  // ==================================================================
  // EKRANLAR
  // ==================================================================
  late _SahteAuthRepo repo;
  late AuthViewModel vm;

  setUp(() {
    repo = _SahteAuthRepo();
    vm = AuthViewModel(repo);
  });

  Future<void> ac(WidgetTester tester, Widget ekran) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/test',
      routes: [
        GoRoute(path: '/test', builder: (_, _) => ekran),
        GoRoute(
          path: AppRoutes.home,
          builder: (_, _) => const Scaffold(body: Text('ANA SAYFA')),
        ),
        GoRoute(
          path: AppRoutes.register,
          builder: (_, _) => const Scaffold(body: Text('KAYIT')),
        ),
      ],
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthViewModel>.value(
        value: vm,
        child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder alan(String etiket) => find.widgetWithText(TextFormField, etiket);

  group('LoginView', () {
    testWidgets('Türkçe karakterlerle ve taşmadan çizilir', (tester) async {
      await ac(tester, const LoginView());

      expect(tester.takeException(), isNull);
      expect(find.text('TEKRAR HOŞ GELDİN'), findsOneWidget);
      expect(find.text('GİRİŞ YAP'), findsOneWidget);
      expect(alan('Şifre'), findsOneWidget);
    });

    testWidgets('boş form gönderilmez, sunucuya istek gitmez', (tester) async {
      await ac(tester, const LoginView());

      await tester.tap(find.text('GİRİŞ YAP'));
      await tester.pumpAndSettle();

      expect(find.text('E-posta adresini gir.'), findsOneWidget);
      expect(repo.girisDenemesi, 0);
    });

    testWidgets('yanlış şifrede hata FORMUN İÇİNDE görünür', (tester) async {
      repo.girisHatasi = const AppException(
        message: 'E-posta veya şifre hatalı.',
        type: AppErrorType.unauthorized,
      );
      await ac(tester, const LoginView());

      await tester.enterText(alan('E-posta'), 'emre@test.com');
      await tester.enterText(alan('Şifre'), 'yanlis123');
      await tester.tap(find.text('GİRİŞ YAP'));
      await tester.pumpAndSettle();

      expect(find.text('E-posta veya şifre hatalı.'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      expect(find.text('ANA SAYFA'), findsNothing);
    });

    testWidgets('bağlantı hatası ayrıca açıklanır', (tester) async {
      repo.girisHatasi = const AppException(
        message: 'Sunucuya ulaşılamadı.',
        type: AppErrorType.network,
      );
      await ac(tester, const LoginView());

      await tester.enterText(alan('E-posta'), 'emre@test.com');
      await tester.enterText(alan('Şifre'), '123456');
      await tester.tap(find.text('GİRİŞ YAP'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
      expect(find.textContaining('İnternet bağlantını'), findsOneWidget);
    });

    testWidgets('yazmaya başlayınca eski hata kaybolur', (tester) async {
      repo.girisHatasi = const AppException(message: 'Hatalı.');
      await ac(tester, const LoginView());

      await tester.enterText(alan('E-posta'), 'emre@test.com');
      await tester.enterText(alan('Şifre'), '123456');
      await tester.tap(find.text('GİRİŞ YAP'));
      await tester.pumpAndSettle();
      expect(find.text('Hatalı.'), findsOneWidget);

      await tester.enterText(alan('Şifre'), '1234567');
      await tester.pump();
      expect(find.text('Hatalı.'), findsNothing);
    });

    testWidgets('başarılı girişte ana sayfaya gider', (tester) async {
      await ac(tester, const LoginView());

      await tester.enterText(alan('E-posta'), 'emre@test.com');
      await tester.enterText(alan('Şifre'), '123456');
      await tester.tap(find.text('GİRİŞ YAP'));
      await tester.pumpAndSettle();

      expect(repo.girisDenemesi, 1);
      expect(find.text('ANA SAYFA'), findsOneWidget);
    });

    testWidgets('şifre göster/gizle', (tester) async {
      await ac(tester, const LoginView());

      bool gizli() => tester
          .widget<EditableText>(
            find.descendant(of: alan('Şifre'), matching: find.byType(EditableText)),
          )
          .obscureText;

      expect(gizli(), isTrue);
      await tester.tap(find.byTooltip('Şifreyi göster'));
      await tester.pump();
      expect(gizli(), isFalse);
    });
  });

  group('RegisterView', () {
    testWidgets('üç alan, Türkçe metin, taşma yok', (tester) async {
      await ac(tester, const RegisterView());

      expect(tester.takeException(), isNull);
      expect(find.text('KADRONU KUR'), findsOneWidget);
      expect(alan('Kullanıcı adı'), findsOneWidget);
      expect(find.text('HESAP OLUŞTUR'), findsOneWidget);
    });

    testWidgets('alınmış kullanıcı adı hatası formda görünür', (tester) async {
      repo.kayitHatasi = const AppException(
        message: 'Bu kullanıcı adı alınmış.',
        type: AppErrorType.gameRule,
      );
      await ac(tester, const RegisterView());

      await tester.enterText(alan('Kullanıcı adı'), 'Emre');
      await tester.enterText(alan('E-posta'), 'emre@test.com');
      await tester.enterText(alan('Şifre'), '123456');
      await tester.ensureVisible(find.text('HESAP OLUŞTUR'));
      await tester.tap(find.text('HESAP OLUŞTUR'));
      await tester.pumpAndSettle();

      expect(find.text('Bu kullanıcı adı alınmış.'), findsOneWidget);
      expect(repo.kayitDenemesi, 1);
    });
  });
}

class _SahteAuthRepo implements AuthRepository {
  AppException? girisHatasi;
  AppException? kayitHatasi;
  int girisDenemesi = 0;
  int kayitDenemesi = 0;

  static const _kullanici = UserModel(id: 'u1', username: 'Emre');

  @override
  Future<Result<UserModel>> signIn({
    required String email,
    required String password,
  }) async {
    girisDenemesi++;
    final h = girisHatasi;
    return h == null ? const Success(_kullanici) : Failure(h);
  }

  @override
  Future<Result<UserModel>> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    kayitDenemesi++;
    final h = kayitHatasi;
    return h == null ? const Success(_kullanici) : Failure(h);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Bu test için gerekmiyor');
}
