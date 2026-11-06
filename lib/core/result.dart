/// Kiểu kết quả trả về để xử lý lỗi tường minh thay vì dùng `throw` rải rác.
///
/// Dùng `Result<T>` cho các thao tác có thể thất bại (network, crypto, Firestore).
sealed class Result<T> {
  const Result();

  const factory Result.ok(T value) = Ok<T>;
  const factory Result.err(Failure failure) = Err<T>;

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  T? get valueOrNull => switch (this) {
        Ok<T>(:final value) => value,
        Err<T>() => null,
      };

  Failure? get failureOrNull => switch (this) {
        Ok<T>() => null,
        Err<T>(:final failure) => failure,
      };

  /// Chuyển đổi giá trị bên trong mà không làm mất thông tin lỗi.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
        Ok<T>(:final value) => Ok<R>(transform(value)),
        Err<T>(:final failure) => Err<R>(failure),
      };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);
  final Failure failure;
}

/// Mô tả lỗi có cấu trúc để hiển thị lỗi cho người dùng và log lại.
enum FailureType {
  network,
  auth,
  permission,
  validation,
  crypto,
  notFound,
  rateLimited,
  cancelled,
  unknown,
}

final class Failure {
  const Failure(
    this.type,
    this.message, {
    this.code,
    this.cause,
  });

  final FailureType type;
  final String message;
  final String? code;
  final Object? cause;

  @override
  String toString() => 'Failure($type, $message${code != null ? ', code: $code' : ''})';
}
