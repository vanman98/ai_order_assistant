sealed class Failure {
  const Failure(this.message);

  final String message;
  bool get canRetry;
}

final class NetworkFailure extends Failure {
  const NetworkFailure(super.message);

  @override
  bool get canRetry => true;
}

final class ServerFailure extends Failure {
  const ServerFailure(super.message, {this.statusCode});

  final int? statusCode;

  @override
  bool get canRetry =>
      statusCode == null ||
      statusCode == 408 ||
      statusCode == 429 ||
      statusCode! >= 500;
}

final class ValidationFailure extends Failure {
  const ValidationFailure(super.message);

  @override
  bool get canRetry => false;
}

final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure(super.message);

  @override
  bool get canRetry => false;
}

final class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message);

  @override
  bool get canRetry => true;
}
