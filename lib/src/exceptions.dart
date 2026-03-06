/// ドメイン固有のカスタム例外
/// Base class for all exceptions thrown by the skills_sync application.
class AppException implements Exception {
  /// Creates a new [AppException] with the given [message].
  AppException(this.message);

  /// The error message associated with this exception.
  final String message;
  @override
  String toString() => message;
}
