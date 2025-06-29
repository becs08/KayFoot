// lib/models/auth_result.dart
import 'user.dart';

class AuthResult {
  final bool success;
  final String message;
  final User? user;

  AuthResult({
    required this.success,
    required this.message,
    this.user,
  });

  @override
  String toString() {
    return 'AuthResult(success: $success, message: $message, user: ${user?.nom})';
  }
}
