import 'dart:io';

import 'package:dio/dio.dart';

import '../utils/logger.dart';
import 'app_exception.dart';
import '../../core/l10n/app_language.dart';
import '../l10n/server_text.dart';

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

    if (error is SocketException) return AppException.network();

    return AppException(
      message: 'Beklenmeyen bir hata olustu. Lutfen tekrar deneyin.'.tr,
      type: AppErrorType.unknown,
      technicalDetail: error.toString(),
    );
  }

  static AppException _fromDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return AppException(
          message: 'Sunucu yanit vermedi. Baglantinizi kontrol edip tekrar deneyin.'.tr,
          type: AppErrorType.network,
        );

      case DioExceptionType.connectionError:
        return AppException(
          message: 'Sunucuya ulasilamiyor. Backend calisiyor mu ve adres dogru mu?'.tr,
          type: AppErrorType.network,
        );

      case DioExceptionType.cancel:
        return AppException(
          message: 'Islem iptal edildi.'.tr,
          type: AppErrorType.unknown,
        );

      case DioExceptionType.badResponse:
        return _fromResponse(error);

      default:
        return AppException(
          message: 'Beklenmeyen bir baglanti hatasi olustu.'.tr,
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
      final ham = govde['message'] as String?;
      mesaj = ham == null ? null : ServerText.translate(ham);
      kod = govde['code'] as String?;
    }

    if (durum == 401) {
      return AppException(
        message: mesaj ?? 'Oturumunuzun suresi doldu. Lutfen tekrar giris yapin.'.tr,
        type: AppErrorType.unauthorized,
        technicalDetail: kod,
      );
    }

    if (durum == 403) {
      return AppException(
        message: mesaj ?? 'Bu islem icin yetkiniz yok.'.tr,
        type: AppErrorType.unauthorized,
        technicalDetail: kod,
      );
    }

    if (durum >= 400 && durum < 500) {
      return AppException(
        message: mesaj ?? 'Istek islenemedi.'.tr,
        // "game_rule" -> oyun kurali ihlali (ornek: sira sizde degil)
        type: kod == 'game_rule' ? AppErrorType.gameRule : AppErrorType.unknown,
        technicalDetail: kod,
      );
    }

    if (durum >= 500) {
      return AppException(
        message: mesaj ?? 'Sunucuda bir sorun olustu. Lutfen tekrar deneyin.'.tr,
        type: AppErrorType.server,
        technicalDetail: '$durum ${kod ?? ''}',
      );
    }

    return AppException(
      message: mesaj ?? 'Beklenmeyen bir hata olustu.'.tr,
      type: AppErrorType.unknown,
      technicalDetail: '$durum',
    );
  }
}
