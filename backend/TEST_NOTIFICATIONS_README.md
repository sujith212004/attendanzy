# Notification Flow Test Suite

This test suite validates that notifications are properly sent to Student, Staff, and HOD at each step of the OD/Leave request workflow.

## What Gets Tested

✅ **Test 1:** Student submits request → Staff gets notified
✅ **Test 2:** Staff forwards request → HOD gets notified  
✅ **Test 3:** Staff forwards request → Student gets notified
✅ **Test 4:** HOD approves request → Student gets notified
✅ **Test 5:** HOD rejects request → Student gets notified
✅ **Test 6:** Staff rejects request → Student gets notified

## Requirements

- Node.js installed
- MongoDB running (or test will mock the database)
- Backend dependencies installed (`npm install`)

## Running the Tests

### Option 1: Direct Node Execution
```bash
cd backend
node test-notification-flow.js
```

### Option 2: Using npm script (Recommended)
Add this to your `backend/package.json`:

```json
"scripts": {
  "test:notifications": "node test-notification-flow.js"
}
```

Then run:
```bash
npm run test:notifications
```

## Expected Output

### ✅ Success Output
```
═══ TEST 1: Student Submits OD Request → Staff Gets Notified ═══
ℹ Simulating: Student submits OD request
✓ Staff notification sent successfully
  - Recipients: staff@college.com
  - Message: "New OD Request Received"

═══ TEST SUMMARY ═══
ℹ Total Tests: 6
✓ Passed: 6
✗ Failed: 0

All notification flows are working correctly! ✓
```

### ❌ Failure Output
```
✗ Staff notification failed or no staff found
✗ HOD notification failed

═══ TEST SUMMARY ═══
ℹ Total Tests: 6
✓ Passed: 3
✗ Failed: 3

Some tests failed. Review Firebase configuration and FCM tokens.
```

## Test Scenarios Explained

### Scenario 1: Complete Approval Flow
```
Student Submits OD
    ↓ (Notification: Staff)
Staff Reviews
    ↓
Staff Accepts & Forwards
    ├─→ (Notification: HOD)
    └─→ (Notification: Student - Forwarded)
    ↓
HOD Reviews
    ↓
HOD Approves
    ↓ (Notification: Student - Approved)
✓ Request Approved
```

### Scenario 2: Staff Rejection
```
Student Submits OD
    ↓ (Notification: Staff)
Staff Reviews
    ↓
Staff Rejects
    ↓ (Notification: Student - Rejected)
✗ Request Rejected
```

### Scenario 3: HOD Rejection
```
Student Submits OD
    ↓ (Notification: Staff)
Staff Reviews & Forwards
    ├─→ (Notification: HOD)
    └─→ (Notification: Student - Forwarded)
    ↓
HOD Reviews
    ↓
HOD Rejects
    ↓ (Notification: Student - Rejected)
✗ Request Rejected
```

## What the Test Checks

Each test verifies:

1. ✓ **Correct recipient** - Notification goes to the right person
   - Staff gets notified when student submits
   - HOD gets notified when staff forwards
   - Student gets notified at each status change

2. ✓ **Correct message** - Notification says the right thing
   - Staff: "New OD Request Received"
   - HOD: "OD Request - Awaiting Approval"
   - Student: "Your request has been [Action] by [Who]"

3. ✓ **FCM token handling** - Notifications use correct FCM tokens
   - Each user has unique mock token
   - System finds user by email/department
   - Token is used for Firebase messaging

4. ✓ **Status updates** - Request status changes correctly
   - staffStatus changes to 'approved' or 'rejected'
   - hodStatus changes when Staff forwards
   - Final status reflects the decision

## Troubleshooting

### Test fails immediately
**Problem:** Cannot connect to notificationService
**Solution:** 
```bash
# Make sure backend is fully set up
npm install

# Check if notificationService.js exists
ls services/notificationService.js
```

### Firebase initialization error
**Problem:** "Firebase not initialized"
**Solution:** 
- Check `services/notificationService.js` line 1
- Firebase initialization happens automatically on module load
- If offline, notifications will be skipped (not an error)

### Database connection errors
**Problem:** "Cannot connect to MongoDB"
**Solution:** 
- Tests don't require real database connection
- Mock objects are used for testing
- If actual DB needed, start MongoDB first: `mongod`

### No notifications received in real app
**Problem:** Tests pass but app doesn't get notifications
**Solution:**
1. Check FCM token is saved after login
2. Verify Firebase credentials in `firebase-service-account.json`
3. Check Firebase Console for message delivery status
4. Ensure app is using correct Firebase project

## Real-World Testing

After tests pass, test the complete flow:

### Step 1: Clear App Cache
```bash
adb shell pm clear com.example.flutter_attendence_app
```

### Step 2: Run App
```bash
flutter run
```

### Step 3: Login as Student
- Check backend logs for FCM token update
- Check MongoDB for `fcmToken` field

### Step 4: Submit Request
- Check staff's phone/emulator
- Should receive notification: "New OD Request Received"

### Step 5: Staff Accepts (as staff user)
- Check student's phone
- Should receive: "Request forwarded to HOD"
- Check HOD's phone
- Should receive: "Request awaiting approval"

### Step 6: HOD Approves (as HOD user)
- Check student's phone
- Should receive: "Request approved"

## Test Metrics

The test suite provides:
- **Total Tests:** Number of scenarios tested
- **Pass Rate:** Percentage of notifications working
- **Detailed Breakdown:** Which notifications succeeded/failed
- **Visual Diagram:** Complete notification flow
- **Conclusion:** Whether system is production-ready

## Integration with CI/CD

Add to your GitHub Actions or CI pipeline:

```yaml
- name: Run Notification Tests
  run: |
    cd backend
    npm install
    node test-notification-flow.js
```

## Notes

- Tests use mock FCM tokens (don't actually send to Firebase)
- To test real Firebase delivery, use different test file
- Tests verify service layer, not network layer
- All user databases (User, Staff, HOD) are mocked

## Contact & Support

If tests fail:
1. Check backend logs for errors
2. Verify notification service is loaded
3. Ensure all models are properly defined
4. Check FCM configuration in Firebase Console
