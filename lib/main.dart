import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/di/injection.dart';
import 'core/utils/logger.dart';
import 'features/auth/domain/repositories/auth_repository.dart';

/// Uygulamanin giris noktasi.
///
/// ACILIS SIRASI (sirasi onemlidir):
///   1. Flutter motorunu hazirla
///   2. .env dosyasini oku (backend adresi icin)
///   3. Bagimliliklari (Get_It) kaydet
///   4. Cihazdaki oturumu geri yukle (varsa WebSocket'i de acar)
///   5. Uygulamayi baslat
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Oyun dikey modda oynanir
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  try {
    await dotenv.load(fileName: '.env');
    await configureDependencies();

    AppLogger.info('Backend adresi: ${AppConfig.apiBaseUrl}');

    // Kayitli oturumu yukle. Basarisiz olsa bile uygulama acilmali;
    // kullanici giris ekranini gorur.
    await getIt<AuthRepository>().restoreSession();
  } catch (e, s) {
    AppLogger.error('Uygulama baslatilamadi', error: e, stackTrace: s);
    runApp(_BaslatmaHatasiEkrani(mesaj: e.toString()));
    return;
  }

  runApp(const FutbolCardApp());
}

/// Acilista bir sey ters giderse (ornek: .env eksik) bos beyaz ekran
/// yerine anlasilir bir mesaj gosterelim.
class _BaslatmaHatasiEkrani extends StatelessWidget {
  final String mesaj;

  const _BaslatmaHatasiEkrani({required this.mesaj});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0B1120),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    size: 64, color: Color(0xFFE5484D)),
                const SizedBox(height: 16),
                const Text(
                  'Uygulama baslatilamadi',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  mesaj,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF9AA5B8)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
