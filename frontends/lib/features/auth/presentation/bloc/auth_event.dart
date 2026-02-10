import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class LoginRequested extends AuthEvent {
  final String email;
  final String password;
  final String role;
  final String department;

  const LoginRequested({
    required this.email,
    required this.password,
    required this.role,
    required this.department,
  });

  @override
  List<Object?> get props => [email, password, role, department];
}

class CheckLoginStatusRequested extends AuthEvent {
  const CheckLoginStatusRequested();
}

class LogoutRequested extends AuthEvent {
  const LogoutRequested();
}

class PasswordChangeRequested extends AuthEvent {
  final String oldPassword;
  final String newPassword;

  const PasswordChangeRequested({
    required this.oldPassword,
    required this.newPassword,
  });

  @override
  List<Object?> get props => [oldPassword, newPassword];
}
