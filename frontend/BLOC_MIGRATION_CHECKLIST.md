# BLoC Migration Checklist

## ✅ Completed Setup

- [x] Added `flutter_bloc` and `equatable` packages
- [x] Created `AppBlocProviders` wrapper
- [x] Integrated `AppBlocProviders` in `main.dart`
- [x] Created barrel export file (`bloc_exports.dart`)
- [x] Created comprehensive documentation (`BLOC_GUIDE.md`)
- [x] Created implementation summary (`BLOC_IMPLEMENTATION_SUMMARY.md`)

## ✅ BLoCs Created

### Authentication
- [x] `AuthBloc` + Events + States
- [x] `UserModel` domain model
- [x] Login logic with SharedPreferences
- [x] Logout logic
- [x] Check login status
- [x] Password change support

### OD Requests
- [x] `ODBloc` + Events + States
- [x] `ODRequestModel` domain model
- [x] Fetch requests (with filters)
- [x] Create request
- [x] Update request
- [x] Delete request
- [x] Approve/Reject (Staff & HOD)
- [x] MongoDB integration
- [x] Status counts

### Leave Requests
- [x] `LeaveBloc` + Events + States
- [x] `LeaveRequestModel` domain model
- [x] Same functionality as OD

### Issues
- [x] `IssueBloc` + Events + States
- [x] `IssueModel` domain model
- [x] Full CRUD operations
- [x] Resolve & Assign functionality

## 📝 Ready to Migrate Pages

### Priority 1 - Authentication Flow
- [ ] `loginpage.dart` → Use `AuthBloc`
  - Replace setState with BlocBuilder
  - Dispatch LoginRequested event
  - Listen to AuthState for navigation

### Priority 2 - OD Management
- [ ] `studentODstatespage.dart` → Use `ODBloc`
  - See example: `student_od_status_page_bloc_example.dart`
  - Replace local state with BlocBuilder
  - Use FetchODRequests event

- [ ] `odrequestpage.dart` → Use `ODBloc`
  - Dispatch CreateODRequest event
  - Listen for success/error states

- [ ] `StaffOdrequest.dart` → Use `ODBloc`
  - Use FetchStaffODRequests event
  - Implement approve/reject with events

- [ ] `hod_od_management_page.dart` → Use `ODBloc`
  - Use FetchHODODRequests event
  - HOD-specific approval workflow

### Priority 3 - Leave Management
- [ ] `student_leave_status_page.dart` → Use `LeaveBloc`
- [ ] `leave_request_page.dart` → Use `LeaveBloc`
- [ ] `leavereqStaffpage.dart` → Use `LeaveBloc`
- [ ] `hod_leave_management_page.dart` → Use `LeaveBloc`
- [ ] `leave_requests_admin_page.dart` → Use `LeaveBloc`

### Priority 4 - Issues Management
- [ ] `Studentissues.dart` → Use `IssueBloc`
- [ ] `Studentissuehodview.dart` → Use `IssueBloc`
- [ ] `issue_detail_page.dart` → Use `IssueBloc`

### Priority 5 - Other Pages (Create BLoCs as needed)
- [ ] `homepage.dart` → May need HomeBloc or use existing BLoCs
- [ ] `request_status_page.dart` → Combine OD & Leave BLoCs
- [ ] `profile_page.dart` → Use AuthBloc for user data
- [ ] `changepassword.dart` → Use AuthBloc

### Priority 6 - Attendance (Create AttendanceBloc)
- [ ] Create `AttendanceBloc` + Events + States
- [ ] `attendance.dart`
- [ ] `attendancemark.dart`
- [ ] `attendancedetails.dart`
- [ ] `DepAttendance.dart`
- [ ] `Department_Report.dart`
- [ ] `absentees_page.dart`

### Priority 7 - Academics (Create AcademicsBloc)
- [ ] Create `AcademicsBloc` for timetable, GPA, etc.
- [ ] `timetable_page.dart`
- [ ] `cgpa_calculator.dart`
- [ ] `gpa_calculator.dart`
- [ ] `Timetabledepartment.dart`

## 🔄 Migration Process for Each Page

### Step 1: Analyze Current Page
```dart
// Find all:
- setState() calls
- State variables
- API/DB calls
- Loading states
- Error handling
```

### Step 2: Identify Events
```dart
// What can user do?
- Load data
- Create item
- Update item
- Delete item
- Filter/Sort
```

### Step 3: Identify States
```dart
// What UI states exist?
- Initial
- Loading
- Loaded (with data)
- Error
- ActionSuccess (created, updated, etc.)
```

### Step 4: Convert to BLoC
```dart
// 1. Remove StatefulWidget, use StatelessWidget
class MyPage extends StatelessWidget {

// 2. Use BlocBuilder for UI
BlocBuilder<MyBloc, MyState>(
  builder: (context, state) {
    if (state is Loading) return LoadingWidget();
    if (state is Loaded) return DataWidget(state.data);
    return ErrorWidget();
  },
)

// 3. Dispatch events instead of calling functions
onPressed: () {
  context.read<MyBloc>().add(CreateItem(item));
}
```

### Step 5: Test
```bash
flutter run
```

## 🎯 Quick Wins (Start Here!)

### Easiest Pages to Migrate First:
1. **Login Page** - Simple form, single event
2. **Student OD Status** - List view, filters (example provided)
3. **Profile Page** - Display user data from AuthBloc

### Tips:
- Start with read-only pages (easier)
- Then move to create pages
- Finally handle complex approval workflows
- Test after each page migration

## 📚 Resources Created

1. **BLOC_GUIDE.md** - Comprehensive usage examples
2. **BLOC_IMPLEMENTATION_SUMMARY.md** - What's been done
3. **student_od_status_page_bloc_example.dart** - Full working example
4. **bloc_exports.dart** - Easy imports

## 🐛 Common Issues & Solutions

### Issue: Can't access BLoC
```dart
// ❌ Wrong
final bloc = ODBloc();

// ✅ Correct
context.read<ODBloc>()
```

### Issue: State not updating
```dart
// ❌ Wrong - Same object reference
emit(state);

// ✅ Correct - New object
emit(ODLoaded(requests: newRequests));
```

### Issue: Multiple rebuilds
```dart
// ❌ Wrong - BlocBuilder in build method of StatefulWidget
class MyPage extends StatefulWidget {}

// ✅ Correct - Use StatelessWidget
class MyPage extends StatelessWidget {}
```

## 🎉 Success Metrics

Track your progress:
- [ ] 0-5 pages migrated: Getting started
- [ ] 6-10 pages migrated: Good progress
- [ ] 11-20 pages migrated: Great job!
- [ ] 21+ pages migrated: BLoC expert!

## 📞 Need Help?

1. Check `BLOC_GUIDE.md` for examples
2. Look at `student_od_status_page_bloc_example.dart`
3. Review BLoC documentation: https://bloclibrary.dev
4. Check existing BLoC files for patterns

## 🚀 Next Steps

1. Pick one page from Priority 1
2. Follow the migration process
3. Test thoroughly
4. Move to next page
5. Gradually migrate all pages

Remember: **Migrate incrementally!** Don't try to do everything at once.
