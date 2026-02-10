import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/firebase_api.dart';
import '../../domain/models/user_model.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc() : super(const AuthInitial()) {
    on<CheckLoginStatusRequested>(_onCheckLoginStatus);
    on<LoginRequested>(_onLoginRequested);
    on<LogoutRequested>(_onLogoutRequested);
    on<PasswordChangeRequested>(_onPasswordChangeRequested);
  }

  Future<void> _onCheckLoginStatus(
    CheckLoginStatusRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('email');
      final name = prefs.getString('name');
      final role = prefs.getString('role') ?? '';
      final isStaff = prefs.getBool('isStaff') ?? false;
      final department = prefs.getString('department') ?? '';
      final year = prefs.getString('year');
      final section = prefs.getString('sec');
      final staffName = prefs.getString('staffName');
      final inchargeName = prefs.getString('inchargeName');

      if (email != null && name != null && role.isNotEmpty) {
        final user = UserModel(
          email: email,
          name: name,
          role: role,
          department: department,
          isStaff: isStaff,
          year: year,
          section: section,
          staffName: staffName,
          inchargeName: inchargeName,
        );
        emit(AuthAuthenticated(user: user));
      } else {
        emit(const AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthError(message: 'Failed to check login status: ${e.toString()}'));
    }
  }

  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      final result = await ApiService.login(
        email: event.email.trim(),
        password: event.password.trim(),
        role: event.role.toLowerCase(),
        department: event.department,
      );

      if (result['success']) {
        final userJson = result['profile'];
        final prefs = await SharedPreferences.getInstance();

        // Save user data to SharedPreferences
        await prefs.setString(
          'email',
          userJson["email"] ?? userJson["College Email"] ?? '',
        );
        await prefs.setString(
          'name',
          userJson["name"] ?? userJson["Name"] ?? '',
        );
        await prefs.setBool(
          'isStaff',
          event.role == 'staff' || event.role == 'hod',
        );
        await prefs.setString('role', event.role.toLowerCase());
        await prefs.setString('department', event.department);

        // Store year & section for USER
        if (event.role == 'user') {
          final year = userJson['year'] ?? '';
          final section = userJson['sec'] ?? '';
          await prefs.setString('year', year);
          await prefs.setString('sec', section);
        }

        // Store year & section for STAFF
        if (event.role == 'staff') {
          final year = userJson['year'] ?? '';
          final section = userJson['sec'] ?? '';
          await prefs.setString('year', year);
          await prefs.setString('sec', section);
          final staffName = userJson['name'] ?? userJson['Name'] ?? '';
          final inchargeName =
              userJson['inchargeName'] ?? userJson['incharge'] ?? '';
          await prefs.setString('staffName', staffName);
          await prefs.setString('inchargeName', inchargeName);
        }

        // Update FCM token
        final userEmail =
            userJson["email"] ?? userJson["College Email"] ?? '';
        if (userEmail.isNotEmpty) {
          FirebaseApi().updateTokenForUser(userEmail).catchError((e) {
            print('Error updating FCM token: $e');
          });
        }

        // Create UserModel
        final user = UserModel.fromJson({
          ...userJson,
          'role': event.role.toLowerCase(),
          'department': event.department,
          'isStaff': event.role == 'staff' || event.role == 'hod',
        });

        emit(AuthAuthenticated(user: user));
      } else {
        emit(AuthError(
          message: result['message'] ??
              'Invalid credentials. Please check your email, password, role, and department.',
        ));
      }
    } catch (e) {
      emit(AuthError(message: 'Failed to connect to the server.'));
      print('Login Error: $e');
    }
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      emit(const AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(message: 'Failed to logout: ${e.toString()}'));
    }
  }

  Future<void> _onPasswordChangeRequested(
    PasswordChangeRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      // Implement password change logic here
      // This is a placeholder - replace with actual API call
      await Future.delayed(const Duration(seconds: 1));
      
      emit(const PasswordChangeSuccess());
    } catch (e) {
      emit(PasswordChangeFailure(
        message: 'Failed to change password: ${e.toString()}',
      ));
    }
  }
}
