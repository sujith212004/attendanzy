# Flutter Integration Guide

This guide will help you integrate the backend API with your Flutter application.

## Step 1: Add HTTP Package

Add the `http` package to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.1.0
  shared_preferences: ^2.2.2
```

Run:
```bash
flutter pub get
```

## Step 2: Copy API Service

1. Copy `api_service.dart` to your Flutter project:
   ```
   frontend/lib/services/api_service.dart
   ```

2. Update the `baseUrl` in `api_service.dart`:
   - For Android Emulator: `http://10.0.2.2:5000/api`
   - For iOS Simulator: `http://localhost:5000/api`
   - For Real Device (same network): `http://YOUR_COMPUTER_IP:5000/api`

## Step 3: Update Login Page

Replace the MongoDB login logic in `loginpage.dart`:

### Before (Direct MongoDB):
```dart
final db = await mongo.Db.create(mongoUri);
await db.open();
final collection = db.collection(collectionName);
final user = await collection.findOne(query);
await db.close();
```

### After (API Call):
```dart
import 'services/api_service.dart';

// In _login() method:
final result = await ApiService.login(
  email: email,
  password: password,
  role: selectedRole,
  department: selectedDepartment,
);

if (result['success']) {
  final user = result['profile'];
  // Save to SharedPreferences and navigate
  // ... rest of your code
} else {
  setState(() {
    _errorMessage = result['message'];
  });
}
```

## Step 4: Update OD Request Page

Replace MongoDB operations in `odrequestpage.dart`:

### Submit OD Request:
```dart
// Replace MongoDB insert with:
final result = await ApiService.submitODRequest(
  studentName: studentName,
  studentEmail: studentEmail,
  from: fromAddressController.text.trim(),
  to: toAddressController.text.trim(),
  subject: subjectController.text.trim(),
  content: contentController.text.trim(),
  department: studentDepartment,
  year: studentYear,
  section: studentSection,
  image: imageBase64,
);

if (result['success']) {
  // Show success message
  _showRequestSubmittedDialog(result['data']);
} else {
  // Show error
  _showSnackBar(result['message'], isError: true);
}
```

### Get Student's OD Requests:
```dart
// Replace MongoDB find with:
final result = await ApiService.getStudentODRequests(studentEmail);

if (result['success']) {
  final requests = result['data'] as List;
  // Process requests
} else {
  // Handle error
}
```

## Step 5: Update Leave Request Page

Replace MongoDB operations in `leave_request_page.dart`:

### Submit Leave Request:
```dart
final result = await ApiService.submitLeaveRequest(
  studentName: studentName,
  studentEmail: studentEmail,
  from: _fromAddress ?? '',
  to: _toAddress ?? '',
  subject: subjectController.text.trim(),
  content: contentController.text.trim(),
  reason: contentController.text.trim(),
  leaveType: _selectedLeaveType,
  fromDate: _fromDate!.toIso8601String(),
  toDate: _toDate!.toIso8601String(),
  duration: _toDate!.difference(_fromDate!).inDays + 1,
  department: studentDepartment,
  year: studentYear,
  section: studentSection,
  image: imageBase64,
);

if (result['success']) {
  _showRequestSubmittedDialog(result['data']);
} else {
  _showSnackBar(result['message'], isError: true);
}
```

## Step 6: Update Staff/HOD Pages

For staff and HOD approval pages:

### Get Pending OD Requests (Staff):
```dart
final result = await ApiService.getStaffODRequests(
  department: staffDepartment,
  year: staffYear,
  section: staffSection,
);

if (result['success']) {
  final requests = result['data'] as List;
  // Display requests
}
```

### Approve/Reject OD Request (Staff):
```dart
final result = await ApiService.updateODStaffStatus(
  requestId: requestId,
  status: 'approved', // or 'rejected'
  remarks: 'Approved by staff',
);

if (result['success']) {
  // Refresh list
}
```

### Get Pending OD Requests (HOD):
```dart
final result = await ApiService.getHODODRequests(
  department: hodDepartment,
);

if (result['success']) {
  final requests = result['data'] as List;
  // Display requests
}
```

### Approve/Reject OD Request (HOD):
```dart
final result = await ApiService.updateODHODStatus(
  requestId: requestId,
  status: 'approved', // or 'rejected'
  remarks: 'Approved by HOD',
);

if (result['success']) {
  // Refresh list
}
```

## Step 7: Remove MongoDB Dependency

1. Remove `mongo_dart` from `pubspec.yaml`
2. Remove all MongoDB import statements:
   ```dart
   // Remove this:
   import 'package:mongo_dart/mongo_dart.dart' as mongo;
   ```

3. Remove MongoDB connection code:
   ```dart
   // Remove these:
   mongo.Db? _db;
   final String mongoUri = "...";
   
   Future<void> _initializeDatabase() async {
     // Remove this entire method
   }
   ```

## Step 8: Test the Integration

1. Make sure the backend server is running:
   ```bash
   cd backend
   npm start
   ```

2. Update the API base URL in `api_service.dart` based on your setup

3. Run your Flutter app:
   ```bash
   cd frontend
   flutter run
   ```

4. Test all functionalities:
   - Login (User/Staff/HOD)
   - Submit OD Request
   - Submit Leave Request
   - View requests
   - Approve/Reject requests (Staff/HOD)

## Common Issues

### Connection Refused
- Make sure backend server is running
- Check if the base URL is correct
- For Android emulator, use `10.0.2.2` instead of `localhost`
- For real device, make sure both devices are on the same network

### CORS Errors
- The backend is already configured to allow all origins
- If you still face issues, check browser console for details

### Timeout Errors
- Increase timeout in HTTP requests if needed:
  ```dart
  final response = await http.post(
    Uri.parse('$baseUrl/auth/login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({...}),
  ).timeout(Duration(seconds: 30));
  ```

## Performance Benefits

After integration, you should notice:
- ✅ Faster app startup (no MongoDB connection on app launch)
- ✅ Quicker login response
- ✅ Faster request submissions
- ✅ Better error handling
- ✅ Improved security (credentials not in app)
- ✅ Easier to scale and maintain

## Next Steps

1. Add proper error handling for network failures
2. Implement loading indicators during API calls
3. Add retry logic for failed requests
4. Consider adding JWT authentication for better security
5. Implement offline support with local caching
6. Add request/response logging for debugging
