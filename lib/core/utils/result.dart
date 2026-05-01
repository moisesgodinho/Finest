class Result<T> {
  const Result._({
    required this.isSuccess,
    this.data,
    this.error,
    this.stackTrace,
  });

  factory Result.success([T? data]) {
    return Result._(isSuccess: true, data: data);
  }

  factory Result.failure(Object error, [StackTrace? stackTrace]) {
    return Result._(
      isSuccess: false,
      error: error,
      stackTrace: stackTrace,
    );
  }

  final bool isSuccess;
  final T? data;
  final Object? error;
  final StackTrace? stackTrace;

  bool get isFailure => !isSuccess;
}
