# Notification System Testing Guide

Complete guide to test and verify the notification flow for Students, Staff, and HODs.

## Quick Start (5 minutes)

### 1. Verify Setup
```bash
cd backend
node verify-notification-setup.js
```

This checks if all components are properly configured. You should see:
```
✅ ALL CHECKS PASSED!
```

### 2. Run Notification Flow Tests  
```bash
node test-notification-flow.js
```

This tests all 6 notification scenarios. Expected output:
```
═══ TEST SUMMARY ═══
ℹ Total Tests: 6
✓ Passed: 6
✗ Failed: 0

All notification flows are working correctly! ✓
```

## Test Files Overview

| File | Purpose | Run Command |
|------|---------|-------------|
| `verify-notification-setup.js` | Verify all components exist | `node verify-notification-setup.js` |
| `test-notification-flow.js` | Test 6 notification scenarios | `node test-notification-flow.js` |
| `TEST_NOTIFICATIONS_README.md` | Detailed test documentation | Reference guide |

## What Gets Tested

### Component Verification (`verify-notification-setup.js`)
Checks 25+ configuration items:
- ✓ Backend services exist and have correct functions
- ✓ Frontend services properly integrated
- ✓ API endpoints configured
- ✓ Database models support FCM tokens
- ✓ Firebase is configured
- ✓ Test files exist

**Output:** Green checkmarks mean everything is set up correctly

---

### Notification Flow Tests (`test-notification-flow.js`)

#### Test 1: Student Submits → Staff Notified
```
Student: submitODRequest()
  ↓
Backend: notifyStaffOnNewRequest()
  ↓
Staff Device: Receives notification
  Title: "New OD Request Received"
  Body: "John Doe (2nd, A) has submitted..."
```

#### Test 2: Staff Forwards → HOD Notified
```
Staff: Click "Accept"
  ↓
Backend: notifyHODOnForward()
  ↓
HOD Device: Receives notification
  Title: "OD Request - Awaiting Approval"
  Body: "John Doe's request requiring your approval"
```

#### Test 3: Staff Forwards → Student Notified
```
Staff: Click "Accept"
  ↓
Backend: notifyStudentOnStatusChange(status='forwarded')
  ↓
Student Device: Receives notification
  Title: "OD Request Forwarded"
  Body: "Your request has been forwarded to HOD for approval"
```

#### Test 4: HOD Approves → Student Notified
```
HOD: Click "Approve"
  ↓
Backend: notifyStudentOnStatusChange(status='approved')
  ↓
Student Device: Receives notification
  Title: "OD Request Accepted"
  Body: "Your request has been accepted by HOD ✓"
```

#### Test 5: HOD Rejects → Student Notified
```
HOD: Click "Reject"
  ↓
Backend: notifyStudentOnStatusChange(status='rejected')
  ↓
Student Device: Receives notification
  Title: "OD Request Rejected"
  Body: "Your request has been rejected by HOD"
```

#### Test 6: Staff Rejects → Student Notified
```
Staff: Click "Reject"
  ↓
Backend: notifyStudentOnStatusChange(status='rejected')
  ↓
Student Device: Receives notification
  Title: "OD Request Rejected"
  Body: "Your request has been rejected by Staff"
```

---

## Understanding Test Output

### ✅ Success Output
```
═══ TEST 1: Student Submits OD Request → Staff Gets Notified ═══
ℹ Simulating: Student submits OD request
✓ Staff notification sent successfully
  - Recipients: staff@college.com
  - Message: "New OD Request Received"
```

**What it means:** 
- System successfully found all staff in the same class
- Notification was queued to send to their FCM tokens
- Message content is correct

### ❌ Failure Output
```
ℹ Simulating: Student submits OD request
✗ Staff notification failed or no staff found
```

**What to check:**
1. Is Staff database populated correctly?
2. Are FCM tokens stored in database?
3. Is Firebase admin SDK initialized?

---

## Integration Tests (Real App Testing)

After verification passes, test in the actual Flutter app:

### Prerequisites
- Backend running: `npm start`
- MongoDB running
- Flutter app installed on emulator/device

### Test Scenario 1: Full Approval Flow

**Step 1: Student Login and Submit**
```
1. Open Flutter app
2. Login as Student (student@college.com)
3. Navigate to "Submit OD"
4. Fill form and submit
5. Check staff's notifications
```

**Expected:** Staff receives notification "New OD Request Received"

**Step 2: Staff Review and Accept**
```
1. Login as Staff (staff@college.com)
2. Open "Staff Requests" section
3. Click "Accept" on student's request
4. Check student's notifications
5. Check HOD's notifications
```

**Expected:**
- Student receives: "Request Forwarded to HOD"
- HOD receives: "Request Awaiting Approval"

**Step 3: HOD Approval**
```
1. Login as HOD (hod@college.com)
2. Open "HOD Requests" section
3. Click "Approve"
4. Check student's notifications
```

**Expected:** Student receives "Request Approved" ✓

### Test Scenario 2: Staff Rejection

**Step 1: Student Submit**
- Same as above

**Step 2: Staff Reject**
```
1. Login as Staff
2. Click "Reject" with reason
3. Check student's notifications
```

**Expected:** Student receives "Request Rejected"

### Test Scenario 3: HOD Rejection

**Step 1-2:** Same as Full Approval Flow

**Step 3: HOD Reject**
```
1. Login as HOD
2. Click "Reject"
3. Check student's notifications
```

**Expected:** Student receives "Request Rejected by HOD"

---

## Debugging Failed Tests

### Issue: Verification fails on Firebase check
```
✗ Firebase Service Account exists
```
**Solution:**
```bash
# Ensure Firebase configuration file exists
ls config/firebase-service-account.json

# If missing, download from Firebase Console
# Project Settings → Service Accounts → Generate New Private Key
```

### Issue: Notification test fails on Staff notification
```
✗ Staff notification failed or no staff found
```
**Solution:**
```bash
# Check MongoDB for Staff records
mongo
use attendanzy_db
db.staffs.find()

# Should see documents with fcmToken field
# If empty, insert test data:
db.staffs.insertOne({
  email: "staff@college.com",
  name: "Dr. Staff",
  department: "CSE",
  year: "2nd",
  sec: "A",
  fcmToken: "test_token_12345"
})
```

### Issue: App doesn't receive notifications
```
Device logs show no notifications arriving
```

**Solution:**
```bash
# 1. Check FCM token is saved after login
adb logcat | grep "FCM Token"

# Expected output:
# Firebase Messaging Token: esa...

# 2. Verify token in MongoDB
db.users.findOne({ email: "student@college.com" }, { fcmToken: 1 })

# Should show fcmToken field populated

# 3. Check Firebase Cloud Messaging logs
# Go to Firebase Console → Debugging

# 4. Ensure foreground notification handler is enabled
# Check: lib/core/services/firebase_api.dart
#   _handleForegroundMessage() called
```

---

## Running Tests with npm Scripts

Update your `backend/package.json`:

```json
{
  "scripts": {
    "start": "node server.js",
    "verify": "node verify-notification-setup.js",
    "test:notifications": "node test-notification-flow.js",
    "test:all": "npm run verify && npm run test:notifications"
  }
}
```

Then run:
```bash
npm run verify           # Quick verification
npm run test:notifications  # Full flow test
npm run test:all        # Both tests
```

---

## Notification Flow Diagram

```
STUDENT SUBMITS OD REQUEST
         |
         ├─→ Backend saves to DB
         │
         └─→ Backend calls notifyStaffOnNewRequest()
                    |
                    └─→ Finds all Staff (dept CSE, year 2, sec A)
                         |
                         └─→ Sends notification to each Staff FCM token
                              ↓
                         STAFF NOTIFICATION ARRIVES ✓
                         
                         Staff Reviews and clicks "Accept"
                              |
                              └─→ Backend calls notifyHODOnForward()
                                   |
                                   └─→ Finds HOD (dept CSE)
                                        |
                                        └─→ Sends notification to HOD FCM token
                                             ↓
                                        HOD NOTIFICATION ARRIVES ✓
                                        
                         Backend also calls notifyStudentOnStatusChange(status='forwarded')
                              |
                              └─→ Finds Student (email)
                                   |
                                   └─→ Sends notification to Student FCM token
                                        ↓
                                   STUDENT NOTIFICATION: Forwarded ✓
                                   
                         HOD Reviews and clicks "Approve"
                              |
                              └─→ Backend calls notifyStudentOnStatusChange(status='approved')
                                   |
                                   └─→ Sends notification to Student FCM token
                                        ↓
                                   STUDENT NOTIFICATION: Approved ✓
                                   
                                   🎉 COMPLETE FLOW FINISHED 🎉
```

---

## Test Checklist

Before considering the system production-ready:

- [ ] `node verify-notification-setup.js` shows all green (100%)
- [ ] `node test-notification-flow.js` shows all 6 tests passing
- [ ] Student can submit OD/Leave request
- [ ] Staff receives notification when student submits
- [ ] Student receives notification when staff forwards
- [ ] HOD receives notification when staff forwards
- [ ] Student receives notification when HOD approves/rejects
- [ ] Leave requests follow same flow as OD
- [ ] All three notification types work (new_request, forwarded, status_update)
- [ ] Notifications appear in foreground when app is open
- [ ] Notifications appear in notification tray when app is closed
- [ ] Clicking notification navigates to correct page

---

## Performance Notes

- **Notification time:** Usually < 5 seconds from action to delivery
- **Database queries:** Each notification triggers 1-2 queries (optimized with indexes)
- **Firebase overhead:** ~100ms for sending to Firebase
- **Network dependent:** Latency increases with poor network

---

## Support

For issues or questions:
1. Check TEST_NOTIFICATIONS_README.md for detailed explanations
2. Review NOTIFICATION_SYSTEM_GUIDE.md for architecture
3. Check backend logs: `npm start` with log output
4. Use `adb logcat` on Android for device-level debugging
5. Check Firebase Console for Cloud Messaging delivery status

---

**Ready to test?** Start with:
```bash
cd backend
node verify-notification-setup.js
```
