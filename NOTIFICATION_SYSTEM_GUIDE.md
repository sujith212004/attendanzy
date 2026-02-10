# Notification System Implementation - Attendanzy

## Overview

A complete end-to-end notification system has been implemented to keep students, staff, and HODs informed about request statuses in real-time using Firebase Cloud Messaging (FCM).

## Notification Flow

### 1. **Student Submits OD/Leave Request**
```
Student submits request → Backend saves request → Backend sends notification to Staff
```

**Who Gets Notified:** All staff members in the same department, year, and section
**Notification Type:** "New Request"
**Backend Method:** `notifyStaffOnNewRequest()`

**Notification Content:**
- Title: "New OD/Leave Request Received"
- Body: "StudentName (Year, Section) has submitted an OD/Leave request. Please review and take action."

---

### 2. **Staff Reviews & Forwards Request to HOD**
```
Staff clicks "Accept" → Backend updates staffStatus → Backend sends notifications:
  ├─ Notification to HOD
  └─ Notification to Student (forwarded status)
```

**Flow:**
- **Step 1:** Staff sets `status = 'accepted'`
- **Step 2:** System automatically sets HOD status to 'pending'
- **Step 3:** Two notifications are sent:

**Notification 1 - To HOD:**
- Type: "Forwarded Request"
- Title: "OD/Leave Request - Awaiting Approval"
- Body: "StudentName (Year, Section) has been forwarded by Staff and requires your approval."
- **Backend Method:** `notifyHODOnForward()`

**Notification 2 - To Student:**
- Type: "Status Update"
- Title: "OD/Leave Request Forwarded"
- Body: "Your OD/Leave request has been forwarded to HOD for final approval."
- **Backend Method:** `notifyStudentOnStatusChange()`

---

### 3. **HOD Approves or Rejects Request**
```
HOD clicks "Approve"/"Reject" → Backend updates hodStatus → Backend sends notification to Student
```

**Notification - To Student:**

**If Approved:**
- Type: "Status Update"
- Title: "OD/Leave Request Accepted"
- Body: "Hi StudentName, your OD/Leave request has been accepted by HOD. You're good to go!"
- **Backend Method:** `notifyStudentOnStatusChange()` with status='approved'

**If Rejected:**
- Type: "Status Update"
- Title: "OD/Leave Request Rejected"
- Body: "Hi StudentName, your OD/Leave request has been rejected by HOD. Please contact your department for more details."
- **Backend Method:** `notifyStudentOnStatusChange()` with status='rejected'

---

## Frontend Implementation

### API Service Methods

**Fetch requests (for each user role):**
```dart
// Students
await ApiService.getStudentODRequests(email);

// Staff
await ApiService.getStaffODRequests(year, section, department);

// HOD
await ApiService.getHODODRequests(department);
```

**Update request statuses:**
```dart
// Staff status update
await ApiService.updateODRequestStatus(
  id: requestId,
  status: 'accepted',  // or 'rejected'
  staffName: staffName,
  inchargeName: inchargeName,
);

// HOD status update
await ApiService.updateHODODRequestStatus(
  id: requestId,
  status: 'approved',  // or 'rejected'
  remarks: 'Your remarks',
);
```

### Notification Handler Service

**Location:** `lib/core/services/notification_handler.dart`

**Features:**
- Automatically displays dialog when notification arrives
- Routes users to appropriate screens based on notification type
- Shows different icons and colors for different statuses

**Notification Types Handled:**
1. `new_request` - Shows blue "Review" button
2. `forwarded_request` - Shows orange "View" button
3. `status_update` - Shows color-coded status (green for approved, red for rejected)
4. `hod_decision` - Shows thumbs up/down based on status

---

## Backend Notification Service

**Location:** `backend/services/notificationService.js`

### Key Methods

#### 1. Send to Staff on New Request
```javascript
notifyStaffOnNewRequest(request, requestType)
// Finds all staff by department/year/section and sends notification
```

#### 2. Send to HOD When Request is Forwarded
```javascript
notifyHODOnForward(request, requestType)
// Finds HOD by department and sends notification
```

#### 3. Send to Student on Status Change
```javascript
notifyStudentOnStatusChange(request, requestType, newStatus, approverRole)
// Sends different messages based on who approved (staff vs HOD)
```

#### 4. Send to Staff on HOD Decision
```javascript
notifyStaffOnHODDecision(request, requestType, status)
// Currently disabled - only students get HOD decision notifications
```

---

## Firebase Configuration

### Required Setup

1. **Firebase Project:** Already configured
2. **FCM Tokens:** Automatically generated and stored when user logs in
3. **Token Updates:** Automatically refreshed when token changes
4. **Notification Channels:** Android channel created for proper notification delivery

### Token Management

**Automatic Updates:**
- Token gen on app launch
- Token updates to backend on login
- Token refresh handled automatically by Firebase

**Manual Token Update (after login):**
```dart
await FirebaseApi().updateTokenForUser(email);
```

---

## Complete Notification Flow Diagram

```
┌─────────────┐
│   STUDENT   │
│  Submits OD │
└────┬────────┘
     │
     ▼
┌─────────────────┐
│ Backend Save OD │
└────┬────────────┘
     │
     ├─────────────────┐
     │                 │
     ▼                 ▼
┌─────────────┐   ┌──────────────┐
│   STAFF 1   │   │   STAFF 2    │
│  Notified   │   │  Notified    │
└────┬────────┘   └──────┬───────┘
     │                   │
     └─────────┬─────────┘
               │
          Staff Reviews
               │
          Clicks: Accept
               │
               ▼
    ┌────────────────────────┐
    │ Backend Updates Status  │
    │  Staff Status: Approved │
    │  HOD Status: Pending    │
    └────────┬──────┬────────┘
             │      │
      ┌──────┘      └──────┐
      │                    │
      ▼                    ▼
   ┌──────────┐      ┌──────────────┐
   │   HOD    │      │   STUDENT    │
   │Notified! │      │  Notified!   │
   │(Forwarded)│      │ (Forwarded) │
   └────┬─────┘      └──────┬───────┘
        │                   │
        │                   │ Sees: "Forwarded to HOD"
        │
     HOD Reviews
        │
    Clicks: Approve
        │
        ▼
 ┌──────────────────────┐
 │ Backend Updates      │
 │ HOD Status: Approved │
 │ Status: Accepted     │
 └────────┬─────────────┘
          │
          ▼
     ┌──────────────┐
     │   STUDENT    │
     │  Notified!   │
     │ (Approved)   │
     └──────────────┘
          │
          ▼
   Sees: "Request Approved"
         ✅ Success!
```

---

## Testing the Notification System

### 1. Clear App Data
```bash
# Android
adb shell pm clear com.example.flutter_attendence_app

# iOS
Delete app and reinstall
```

### 2. Test with Mock Backend
- Manually update MongoDB with different statuses
- Or use Postman to hit endpoints:

```
POST /api/od-requests/:id/staff-status
{
  "status": "accepted",
  "staffName": "Staff Name"
}

PUT /api/od-requests/:id/hod-status
{
  "status": "approved",
  "remarks": "Approved"
}
```

### 3. Expected Behavior

**Student Flow:**
1. Submit OD/Leave request ✓
2. See notification when staff accepts (should show "Forwarded to HOD")
3. See notification when HOD approves (should show "Approved")

**Staff Flow:**
1. See notification when student submits request
2. Accept/Reject request
3. See notification travels to HOD

**HOD Flow:**
1. See notification when staff forwards request
2. Approve/Reject request
3. Notification goes to student

---

## Troubleshooting

### Notifications Not Arriving

**Check FCM Token:**
```dart
// In debug console
final token = await FirebaseMessaging.instance.getToken();
print('FCM Token: $token');
```

**Verify Token in Backend:**
```javascript
// In MongoDB
db.users.findOne({ email: "student@college.com" })
// Look for fcmToken field
```

**Check Firebase Cloud Messaging:**
- Go to Firebase Console
- Check that notifications were actually sent
- Check error logs in Firebase Functions

### Token Not Updating

**Manual Update:**
```dart
await FirebaseApi().updateTokenForUser(userEmail);
```

### Notifications Showing But Not Processing Correctly

**Clear Notification Handler Data:**
```dart
// In main.dart, ensure navigatorKey is set:
NotificationHandler.navigatorKey = navigatorKey;
```

---

## Summary

✅ **Student submits request** → Staff gets notification
✅ **Staff forwards request** → HOD gets notification + Student gets notification  
✅ **HOD approves/rejects** → Student gets notification

The system is fully functional and ready to use!
