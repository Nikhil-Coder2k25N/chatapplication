class AppException implements Exception {
  final String message;
  final String? code;

  const AppException({required this.message, this.code});

  @override
  String toString() => code != null ? '[$code] $message' : message;
}

class NetworkException extends AppException {
  const NetworkException()
      : super(message: 'No internet connection', code: 'NETWORK_ERROR');
}

class AuthException extends AppException {
  const AuthException({required super.message, super.code});
}

class ChatException extends AppException {
  const ChatException({required super.message, super.code});
}