import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_event.dart';
import '../../features/od/presentation/bloc/od_bloc.dart';
import '../../features/leave/presentation/bloc/leave_bloc.dart';
import '../../features/issues/presentation/bloc/issue_bloc.dart';

/// Global BLoC Providers for the entire app
/// Wrap your MaterialApp with this widget in main.dart
class AppBlocProviders extends StatelessWidget {
  final Widget child;

  const AppBlocProviders({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // Authentication BLoC - App-wide
        BlocProvider<AuthBloc>(
          create: (context) => AuthBloc()..add(CheckLoginStatusRequested()),
        ),

        // OD Request BLoC - Feature-specific
        BlocProvider<ODBloc>(create: (context) => ODBloc()),

        // Leave Request BLoC - Feature-specific
        BlocProvider<LeaveBloc>(create: (context) => LeaveBloc()),

        // Issue BLoC - Feature-specific
        BlocProvider<IssueBloc>(create: (context) => IssueBloc()),

        // Add more BLoCs here as needed
        // Example: AttendanceBloc, AcademicsBloc, etc.
      ],
      child: child,
    );
  }
}
