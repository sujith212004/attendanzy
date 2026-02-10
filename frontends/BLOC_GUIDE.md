# BLoC Implementation Guide for Attendanzy

## Overview
This guide explains how to use the BLoC (Business Logic Component) pattern implemented in the Attendanzy app to manage state and events.

## 📁 Project Structure

```
lib/
├── core/
│   └── bloc/
│       └── app_bloc_providers.dart     # Global BLoC providers
├── features/
│   ├── auth/
│   │   ├── domain/
│   │   │   └── models/
│   │   │       └── user_model.dart     # User data model
│   │   └── presentation/
│   │       └── bloc/
│   │           ├── auth_bloc.dart      # Auth business logic
│   │           ├── auth_event.dart     # Auth events
│   │           └── auth_state.dart     # Auth states
│   ├── od/
│   │   ├── domain/
│   │   │   └── models/
│   │   │       └── od_request_model.dart
│   │   └── presentation/
│   │       └── bloc/
│   │           ├── od_bloc.dart
│   │           ├── od_event.dart
│   │           └── od_state.dart
│   ├── leave/
│   │   ├── domain/
│   │   │   └── models/
│   │   │       └── leave_request_model.dart
│   │   └── presentation/
│   │       └── bloc/
│   │           ├── leave_bloc.dart
│   │           ├── leave_event.dart
│   │           └── leave_state.dart
│   └── issues/
│       ├── domain/
│       │   └── models/
│       │       └── issue_model.dart
│       └── presentation/
│           └── bloc/
│               ├── issue_bloc.dart
│               ├── issue_event.dart
│               └── issue_state.dart
```

## 🚀 Getting Started

### 1. Setup in main.dart

Wrap your MaterialApp with AppBlocProviders:

```dart
import 'package:flutter/material.dart';
import 'core/bloc/app_bloc_providers.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBlocProviders(
      child: MaterialApp(
        title: 'Attendanzy',
        home: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            if (state is AuthAuthenticated) {
              return HomePage(user: state.user);
            }
            return const LoginPage();
          },
        ),
      ),
    );
  }
}
```

## 📖 Using BLoC in Pages

### Authentication Example

#### Login Page with BLoC:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            // Navigate to home page
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => HomePage(user: state.user),
              ),
            );
          } else if (state is AuthError) {
            // Show error message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          if (state is AuthLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return LoginForm();
        },
      ),
    );
  }
}

class LoginForm extends StatelessWidget {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(controller: emailController),
        TextField(controller: passwordController, obscureText: true),
        ElevatedButton(
          onPressed: () {
            // Dispatch login event
            context.read<AuthBloc>().add(
              LoginRequested(
                email: emailController.text,
                password: passwordController.text,
                role: 'user',
                department: 'Computer Science',
              ),
            );
          },
          child: const Text('Login'),
        ),
      ],
    );
  }
}
```

### OD Requests Page with BLoC:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/od_bloc.dart';
import '../../bloc/od_event.dart';
import '../../bloc/od_state.dart';

class StudentODStatusPage extends StatelessWidget {
  final String studentEmail;

  const StudentODStatusPage({
    super.key,
    required this.studentEmail,
  });

  @override
  Widget build(BuildContext context) {
    // Fetch requests when page loads
    context.read<ODBloc>().add(
      FetchODRequests(studentEmail: studentEmail),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('My OD Requests')),
      body: BlocBuilder<ODBloc, ODState>(
        builder: (context, state) {
          if (state is ODLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is ODError) {
            return Center(child: Text('Error: ${state.message}'));
          }

          if (state is ODLoaded) {
            if (state.requests.isEmpty) {
              return const Center(child: Text('No OD Requests'));
            }

            return Column(
              children: [
                // Filter chips
                _buildFilterChips(context, state.currentFilter),
                
                // Stats
                _buildStats(state),
                
                // Requests list
                Expanded(
                  child: ListView.builder(
                    itemCount: state.requests.length,
                    itemBuilder: (context, index) {
                      final request = state.requests[index];
                      return ListTile(
                        title: Text(request.subject),
                        subtitle: Text(request.status),
                        onTap: () {
                          // Navigate to detail page
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          }

          return const Center(child: Text('Unknown state'));
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Refresh requests
          context.read<ODBloc>().add(
            FetchODRequests(studentEmail: studentEmail),
          );
        },
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context, String currentFilter) {
    final filters = ['All', 'Pending', 'Accepted', 'Rejected'];
    
    return Wrap(
      spacing: 8,
      children: filters.map((filter) {
        return ChoiceChip(
          label: Text(filter),
          selected: currentFilter == filter,
          onSelected: (selected) {
            if (selected) {
              context.read<ODBloc>().add(
                FetchODRequests(
                  studentEmail: studentEmail,
                  filterStatus: filter,
                ),
              );
            }
          },
        );
      }).toList(),
    );
  }

  Widget _buildStats(ODLoaded state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _StatCard(label: 'Pending', count: state.pendingCount),
        _StatCard(label: 'Accepted', count: state.acceptedCount),
        _StatCard(label: 'Rejected', count: state.rejectedCount),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int count;

  const _StatCard({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$count', style: const TextStyle(fontSize: 24)),
        Text(label),
      ],
    );
  }
}
```

## 🔄 Common BLoC Patterns

### 1. Dispatching Events

```dart
// Simple event
context.read<AuthBloc>().add(const LogoutRequested());

// Event with parameters
context.read<ODBloc>().add(
  CreateODRequest(request: newRequest),
);
```

### 2. Listening to State Changes

```dart
// BlocBuilder - Rebuilds UI on state changes
BlocBuilder<AuthBloc, AuthState>(
  builder: (context, state) {
    if (state is AuthLoading) {
      return CircularProgressIndicator();
    }
    // ... other states
  },
)

// BlocListener - Performs side effects (navigation, dialogs)
BlocListener<AuthBloc, AuthState>(
  listener: (context, state) {
    if (state is AuthError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.message)),
      );
    }
  },
  child: YourWidget(),
)

// BlocConsumer - Combines both
BlocConsumer<AuthBloc, AuthState>(
  listener: (context, state) {
    // Side effects
  },
  builder: (context, state) {
    // UI updates
  },
)
```

### 3. Creating New Requests

```dart
// Create OD Request
final request = ODRequestModel(
  studentEmail: 'student@example.com',
  subject: 'Sports Event',
  reason: 'Participating in basketball tournament',
  fromDate: '2024-03-01',
  toDate: '2024-03-03',
);

context.read<ODBloc>().add(CreateODRequest(request: request));

// Listen for success
BlocListener<ODBloc, ODState>(
  listener: (context, state) {
    if (state is ODRequestCreated) {
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request created successfully')),
      );
      // Refresh list
      context.read<ODBloc>().add(
        FetchODRequests(studentEmail: studentEmail),
      );
    }
  },
)
```

## 📝 Migration Checklist

When migrating an existing page to BLoC:

1. **Identify State Variables**
   - Find all `setState()` calls
   - List all state variables (loading, error, data, etc.)

2. **Create Events**
   - User actions (button clicks, form submissions)
   - Lifecycle events (page load, refresh)

3. **Create States**
   - Initial, Loading, Loaded, Error states
   - Include all necessary data in states

4. **Update UI**
   - Replace StatefulWidget with StatelessWidget
   - Use BlocBuilder/BlocListener/BlocConsumer
   - Dispatch events instead of calling methods

5. **Remove setState**
   - All state changes happen through BLoC
   - No direct state manipulation in UI

## 🎯 Benefits of BLoC

1. **Separation of Concerns**: Business logic separate from UI
2. **Testability**: Easy to test business logic independently
3. **Reusability**: Same BLoC can be used in multiple widgets
4. **Predictability**: Clear event → state flow
5. **Debugging**: Easy to track state changes with BlocObserver

## 🛠️ Available BLoCs

### AuthBloc
- Events: `LoginRequested`, `LogoutRequested`, `CheckLoginStatusRequested`, `PasswordChangeRequested`
- States: `AuthInitial`, `AuthLoading`, `AuthAuthenticated`, `AuthUnauthenticated`, `AuthError`

### ODBloc
- Events: `FetchODRequests`, `CreateODRequest`, `UpdateODRequest`, `DeleteODRequest`, `ApproveODRequest`, `RejectODRequest`
- States: `ODInitial`, `ODLoading`, `ODLoaded`, `ODError`, `ODRequestCreated`, etc.

### LeaveBloc
- Similar to ODBloc but for leave requests

### IssueBloc
- Events: `FetchIssues`, `CreateIssue`, `UpdateIssue`, `DeleteIssue`, `ResolveIssue`, `AssignIssue`
- States: `IssueInitial`, `IssueLoading`, `IssueLoaded`, `IssueError`, etc.

## 📚 Next Steps

1. Review the BLoC files in each feature folder
2. Start with one simple page (e.g., login page)
3. Migrate gradually, one page at a time
4. Test thoroughly after each migration
5. Use BlocObserver for debugging if needed

## 💡 Tips

- Always dispatch events, never call BLoC methods directly
- Use const constructors for Events and States when possible
- Keep BLoCs focused on a single responsibility
- Use Equatable to easily compare states
- Dispose BLoCs properly (automatic with BlocProvider)
