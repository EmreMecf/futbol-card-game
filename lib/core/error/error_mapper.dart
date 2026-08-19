import 'dart:io';

import 'package:dio/dio.dart';

import '../utils/logger.dart';
import 'app_exception.dart';

/// Ham hatalari [AppException]'a cevirir.
///
/// ONEMLI TASARIM NOTU:
/// Backend'imiz hatalari su bicimde donuyor:
///   { "error": true, "message": "Sira sizde degil.", "code": "game_rule" }
///
/// Mesajlar zaten TURKCE ve dogrudan kullaniciya gosterilebilir durumda.
/// Cunku oyun kurallarina dair metinler PostgreSQL fonksiyonlarinda
/// yaziyor ve backend onlari oldugu gibi geciriyor. Yani bir kurali
/// degistirdiginde uygulamayi yeniden yayinlamana gerek yok.
class ErrorMapper {
  const ErrorMapper._();

  static AppException map(Object error, [StackTrace? stackTrace]) {
    AppLogger.error('Hata yakalandi', error: error, stackTrace: stackTrace);

    if (error is AppException) return error;

    if (error is DioException) return _fromDio(error);

    if (error is SocketException) return const AppException.network();

    return AppException(
      message: 'Beklenmeyen bir hata olustu. Lutfen tekrar deneyin.',
      type: AppErrorType.unknown,
      technicalDetail: error.toString(),
    );
  }

  static AppException _fromDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const AppException(
          message: 'Sunucu yanit vermedi. Baglantinizi kontrol edip tekrar deneyin.',
          type: AppErrorType.network,
        );

      case DioExceptionType.connectionError:
        return const AppException(
          message: 'Sunucuya ulasilamiyor. Backend calisiyor mu ve adres dogru mu?',
          type: AppErrorType.network,
        );

      case DioExceptionType.cancel:
        return const AppException(
          message: 'Islem iptal edildi.',
          type: AppErrorType.unknown,
        );

      case DioExceptionType.badResponse:
        return _fromResponse(error);

      default:
        return AppException(
          message: 'Beklenmeyen bir baglanti hatasi olustu.',
          type: AppErrorType.network,
          technicalDetail: error.message,
        );
    }
  }

  static AppException _fromResponse(DioException error) {
    final durum = error.response?.statusCode ?? 0;
    final govde = error.response?.data;

    // Backend'in gonderdigi Turkce mesaji cikar
    String? mesaj;
    String? kod;
    if (govde is Map) {
      mesaj = govde['message'] as String?;
      kod = govde['code'] as String?;
    }

    if (durum == 401) {
      return AppException(
        message: mesaj ?? 'Oturumunuzun suresi doldu. Lutfen tekrar giris yapin.',
        type: AppErrorType.unauthorized,
        technicalDetail: kod,
      );
    }

    if (durum == 403) {
      return AppException(
        message: mesaj ?? 'Bu islem icin yetkiniz yok.',
        type: AppErrorType.unauthorized,
        technicalDetail: kod,
      );
    }

    if (durum >= 400 && durum < 500) {
      return AppException(
        message: mesaj ?? 'Istek islenemedi.',
        // "game_rule" -> oyun kurali ihlali (ornek: sira sizde degil)
        type: kod == 'game_rule' ? AppErrorType.gameRule : AppErrorType.unknown,
        technicalDetail: kod,
      );
    }

    if (durum >= 500) {
      return AppException(
        message: mesaj ?? 'Sunucuda bir sorun olustu. Lutfen tekrar deneyin.',
        type: AppErrorType.server,
        technicalDetail: '$durum ${kod ?? ''}',
      );
    }

    return AppException(
      message: mesaj ?? 'Beklenmeyen bir hata olustu.',
      type: AppErrorType.unknown,
      technicalDetail: '$durum',
    );
  }
}
