# BLoC Implementation Summary for Attendanzy

## ✅ What Has Been Implemented

### 1. **BLoC Packages Added**
- `flutter_bloc` - BLoC state management
- `equatable` - Value equality for Events and States

### 2. **Core Architecture Created**

#### Global BLoC Provider
- **File**: `lib/core/bloc/app_bloc_providers.dart`
- **Purpose**: Provides all BLoCs to the entire app
- **Usage**: Already integrated in `main.dart`

### 3. **Feature BLoCs Implemented**

#### **Authentication BLoC** (`lib/features/auth/`)
**Files Created:**
- `domain/models/user_model.dart` - User data model
- `presentation/bloc/auth_bloc.dart` - Business logic
- `presentation/bloc/auth_event.dart` - Events (LoginRequested, LogoutRequested, etc.)
- `presentation/bloc/auth_state.dart` - States (AuthLoading, AuthAuthenticated, etc.)

**Capabilities:**
- ✅ Login with email, password, role, department
- ✅ Check login status on app start
- ✅ Logout
- ✅ Password change
- ✅ Auto-saves to SharedPreferences
- ✅ Updates FCM token

#### **OD Request BLoC** (`lib/features/od/`)
**Files Created:**
- `domain/models/od_request_model.dart` - OD request model
- `presentation/bloc/od_bloc.dart` - Business logic
- `presentation/bloc/od_event.dart` - Events
- `presentation/bloc/od_state.dart` - States

**Capabilities:**
- ✅ Fetch student's OD requests
- ✅ Create new OD request
- ✅ Update existing request
- ✅ Delete request
- ✅ Filter by status (All, Pending, Accepted, Rejected)
- ✅ Approve/Reject (Staff & HOD)
- ✅ Automatic status counts
- ✅ MongoDB integration

#### **Leave Request BLoC** (`lib/features/leave/`)
**Files Created:**
- `domain/models/leave_request_model.dart`
- `presentation/bloc/leave_bloc.dart`
- `presentation/bloc/leave_event.dart`
- `presentation/bloc/leave_state.dart`

**Capabilities:**
- Same as OD BLoC but for leave requests

#### **Issue Tracking BLoC** (`lib/features/issues/`)
**Files Created:**
- `domain/models/issue_model.dart`
- `presentation/bloc/issue_bloc.dart`
- `presentation/bloc/issue_event.dart`
- `presentation/bloc/issue_state.dart`

**Capabilities:**
- ✅ Fetch issues
- ✅ Create issue
- ✅ Update/Delete issue
- ✅ Resolve issue
- ✅ Assign issue
- ✅ Filter by status

### 4. **Helper Files**

- `lib/bloc_exports.dart` - Barrel file for easy imports
- `BLOC_GUIDE.md` - Comprehensive usage guide

## 📦 Dependencies Added

```yaml
dependencies:
  flutter_bloc: ^8.1.6
  equatable: ^2.0.7
  nested: ^1.0.0  # Auto-added as dependency
  provider: ^6.1.5+1  # Auto-added as dependency
```

## 🚀 How to Use

### In Your Pages:

```dart
// 1. Import BLoC
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/od_bloc.dart';
import '../../bloc/od_event.dart';
import '../../bloc/od_state.dart';

// 2. Use BlocBuilder to rebuild UI
BlocBuilder<ODBloc, ODState>(
  builder: (context, state) {
    if (state is ODLoading) {
      return CircularProgressIndicator();
    }
    if (state is ODLoaded) {
      return ListView.builder(...);
    }
    return Container();
  },
)

// 3. Dispatch events
context.read<ODBloc>().add(
  FetchODRequests(studentEmail: 'student@example.com'),
);
```

## 📝 Migration Steps for Existing Pages

### Before (StatefulWidget with setState):
```dart
class MyPage extends StatefulWidget {
  @override
  _MyPageState createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  List<Request> requests = [];
  bool loading = false;

  void fetchData() async {
    setState(() => loading = true);
    // ... fetch logic
    setState(() {
      requests = result;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return loading
        ? CircularProgressIndicator()
        : ListView.builder(...);
  }
}
```

### After (StatelessWidget with BLoC):
```dart
class MyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Trigger fetch on load
    context.read<ODBloc>().add(FetchODRequests(...));

    return BlocBuilder<ODBloc, ODState>(
      builder: (context, state) {
        if (state is ODLoading) {
          return CircularProgressIndicator();
        }
        if (state is ODLoaded) {
          return ListView.builder(
            itemCount: state.requests.length,
            itemBuilder: (context, index) {
              final request = state.requests[index];
              return ListTile(title: Text(request.subject));
            },
          );
        }
        return Container();
      },
    );
  }
}
```

## ✅ Next Steps

### For You to Do:

1. **Review the BLoC Guide**: Open `BLOC_GUIDE.md` for detailed examples

2. **Start Migrating Pages**: Begin with simple pages
   - ✅ Login page (can use AuthBloc)
   - ✅ OD Status page (can use ODBloc)
   - ✅ Leave Status page (can use LeaveBloc)
   - ✅ Issues page (can use IssueBloc)

3. **Test Each Migration**: 
   ```bash
   flutter run
   ```

4. **Create More BLoCs** (if needed):
   - AttendanceBloc for attendance management
   - AcademicsBloc for GPA/timetable
   - HomeBloc for homepage data

### Example: Migrating Student OD Status Page

The file `lib/features/od/presentation/pages/studentODstatespage.dart` can be refactored to use `ODBloc`.

**Current Issues:**
- Uses StatefulWidget with local state
- Direct MongoDB queries in UI
- setState() for all updates

**BLoC Benefits:**
- Cleaner separation of concerns
- Easier testing
- Reusable logic
- Better error handling

## 🎯 Key Benefits You Get

1. **Cleaner Code**: Business logic separated from UI
2. **Testability**: Easy to unit test BLoCs
3. **Reusability**: Same BLoC used in multiple widgets
4. **Predictable State**: Clear event → state flow
5. **Better Performance**: Only rebuild what's needed
6. **Easier Debugging**: Track all state changes

## 📚 Resources

- **BLoC Package Docs**: https://bloclibrary.dev
- **Your Implementation**: Check `BLOC_GUIDE.md`
- **Examples**: See the BLoC files in each feature folder

## 🐛 Troubleshooting

### Common Issues:

**Issue**: "Cannot find BLoC"
```dart
// Solution: Make sure you're inside AppBlocProviders (already in main.dart)
context.read<ODBloc>() // ✅ Works
```

**Issue**: "setState() called after dispose"
```dart
// Solution: BLoC handles this automatically - no more setState!
```

**Issue**: "State not updating"
```dart
// Solution: Always emit new state instances, use copyWith() or new objects
emit(ODLoaded(requests: newRequests)); // ✅ Correct
```

## 💡 Pro Tips

1. **Use BlocConsumer** when you need both UI updates AND side effects:
   ```dart
   BlocConsumer<ODBloc, ODState>(
     listener: (context, state) {
       if (state is ODError) {
         // Show SnackBar
       }
     },
     builder: (context, state) {
       // Build UI
     },
   )
   ```

2. **Keep BLoCs focused**: One BLoC per feature/domain
3. **Use Equatable**: Helps with state comparison
4. **Don't call BLoC methods directly**: Always use events
5. **Test your BLoCs**: Easy to unit test without UI

## 🎉 You're Ready!

All BLoCs are set up and ready to use. Start with one page, test it, then gradually migrate others. The `BLOC_GUIDE.md` has detailed examples for each scenario.

Happy coding! 🚀
