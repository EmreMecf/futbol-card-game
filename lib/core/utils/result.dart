import '../error/app_exception.dart';
import '../error/error_mapper.dart';

/// Basarili/basarisiz sonucu tek bir tipte tasiyan sarmalayici.
///
/// Neden? ViewModel'lerde her yere try/catch yazmak yerine repository
/// katmani [Result] dondurur, ViewModel sadece iki durumu ayirir.
/// Dart 3 sealed class sayesinde derleyici eksik durumu yakalar.
sealed class Result<T> {
  const Result();

  /// Verilen islemi calistirir, hata olursa [Failure]'a cevirir.
  static Future<Result<T>> guard<T>(Future<T> Function() action) async {
    try {
      return Success(await action());
    } catch (e, s) {
      return Failure(ErrorMapper.map(e, s));
    }
  }

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  /// Basariliysa veriyi, degilse null doner
  T? get dataOrNull => switch (this) {
        Success<T>(:final data) => data,
        Failure<T>() => null,
      };

  /// Hata varsa hatayi, yoksa null doner
  AppException? get errorOrNull => switch (this) {
        Success<T>() => null,
        Failure<T>(:final error) => error,
      };

  /// Iki durumu da tek satirda ele almak icin
  R when<R>({
    required R Function(T data) success,
    required R Function(AppException error) failure,
  }) {
    return switch (this) {
      Success<T>(:final data) => success(data),
      Failure<T>(:final error) => failure(error),
    };
  }
}

final class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

final class Failure<T> extends Result<T> {
  final AppException error;
  const Failure(this.error);
}
