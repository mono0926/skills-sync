/// Custom exceptions for domain-specific errors.
/// Base class for all exceptions thrown by the skills_sync application.
class AppException(
  /// The error message associated with this exception.
  final String message,
) implements Exception {
  /// Creates a new [AppException] with the given [message].
  this;

  @override
  String toString() => message;
}
