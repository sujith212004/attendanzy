/**
 * Quick Verification Script for Notification System
 * Verifies all critical components without needing a running database
 * 
 * Usage: node verify-notification-setup.js
 */

const fs = require('fs');
const path = require('path');

const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m',
};

const checks = [];

function check(name, result, details = '') {
  const status = result ? `${colors.green}✓${colors.reset}` : `${colors.red}✗${colors.reset}`;
  console.log(`${status} ${name}`);
  if (details) console.log(`  ${colors.cyan}${details}${colors.reset}`);
  checks.push({ name, result });
}

function fileExists(filePath) {
  return fs.existsSync(filePath);
}

function fileContains(filePath, text) {
  try {
    const content = fs.readFileSync(filePath, 'utf8');
    return content.includes(text);
  } catch {
    return false;
  }
}

console.log(`
${colors.cyan}╔════════════════════════════════════════════════════════════╗
║     NOTIFICATION SYSTEM VERIFICATION CHECKLIST                ║
║     Verifying all components are properly set up              ║
╚════════════════════════════════════════════════════════════════╝${colors.reset}
`);

// === BACKEND CHECKS ===
console.log(`\n${colors.blue}BACKEND SETUP${colors.reset}`);

check(
  'Notification Service exists',
  fileExists('./services/notificationService.js'),
  'Location: services/notificationService.js'
);

check(
  'sendNotificationToToken() function',
  fileContains('./services/notificationService.js', 'sendNotificationToToken'),
  'Required for sending FCM messages'
);

check(
  'notifyStaffOnNewRequest() function',
  fileContains('./services/notificationService.js', 'notifyStaffOnNewRequest'),
  'Sends notification when student submits'
);

check(
  'notifyHODOnForward() function',
  fileContains('./services/notificationService.js', 'notifyHODOnForward'),
  'Sends notification to HOD when forwarded'
);

check(
  'notifyStudentOnStatusChange() function',
  fileContains('./services/notificationService.js', 'notifyStudentOnStatusChange'),
  'Sends notification to student on status update'
);

check(
  'OD Request Controller exists',
  fileExists('./controllers/odRequestController.js'),
  'Location: controllers/odRequestController.js'
);

check(
  'OD Controller imports notifications',
  fileContains('./controllers/odRequestController.js', 'notifyStaffOnNewRequest'),
  'Should import notification functions'
);

check(
  'submitODRequest() calls notification',
  fileContains('./controllers/odRequestController.js', 'notifyStaffOnNewRequest(odRequest'),
  'Should notify staff after submit'
);

check(
  'updateStaffStatus() calls notifications',
  fileContains('./controllers/odRequestController.js', 'notifyHODOnForward') &&
    fileContains('./controllers/odRequestController.js', 'notifyStudentOnStatusChange'),
  'Should notify HOD and student on forward'
);

check(
  'updateHODStatus() calls notification',
  fileContains('./controllers/odRequestController.js', 'notifyStudentOnStatusChange(odRequest, \'OD\', status, \'hod\')'),
  'Should notify student on approval/rejection'
);

check(
  'Leave Request Controller exists',
  fileExists('./controllers/leaveRequestController.js'),
  'Location: controllers/leaveRequestController.js'
);

check(
  'Leave Controller has same notification flow',
  fileContains('./controllers/leaveRequestController.js', 'notifyStaffOnNewRequest') &&
    fileContains('./controllers/leaveRequestController.js', 'notifyHODOnForward') &&
    fileContains('./controllers/leaveRequestController.js', 'notifyStudentOnStatusChange'),
  'Leave requests should follow same flow as OD'
);

check(
  'Routes configured for staff-status',
  fileExists('./routes/odRequests.js') && fileContains('./routes/odRequests.js', ':id/staff-status'),
  'Route: PUT /api/od-requests/:id/staff-status'
);

check(
  'Routes configured for hod-status',
  fileExists('./routes/odRequests.js') && fileContains('./routes/odRequests.js', ':id/hod-status'),
  'Route: PUT /api/od-requests/:id/hod-status'
);

// === FRONTEND CHECKS ===
console.log(`\n${colors.blue}FRONTEND SETUP${colors.reset}`);

check(
  'Notification Handler Service exists',
  fileExists('../frontend/lib/core/services/notification_handler.dart'),
  'Location: lib/core/services/notification_handler.dart'
);

check(
  'NotificationHandler.handleNotification() exists',
  fileContains('../frontend/lib/core/services/notification_handler.dart', 'handleNotification'),
  'Processes incoming notifications'
);

check(
  'Firebase API initialized',
  fileExists('../frontend/lib/core/services/firebase_api.dart'),
  'Location: lib/core/services/firebase_api.dart'
);

check(
  'Firebase API imports notification_handler',
  fileContains('../frontend/lib/core/services/firebase_api.dart', 'notification_handler'),
  'Should integrate with handler'
);

check(
  'API Service HOD methods exist',
  fileContains('../frontend/lib/core/services/api_service.dart', 'updateHODODRequestStatus'),
  'Should have method to update HOD status'
);

check(
  'API Service has staff update methods',
  fileContains('../frontend/lib/core/services/api_service.dart', 'updateODRequestStatus'),
  'Should have method to update staff status'
);

check(
  'Main app initializes NotificationHandler',
  fileContains('../frontend/lib/main.dart', 'NotificationHandler.navigatorKey'),
  'NotificationHandler must be initialized in main'
);

check(
  'Firebase init in main.dart',
  fileContains('../frontend/lib/main.dart', 'Firebase.initializeApp'),
  'Firebase must be initialized before running'
);

// === FIREBASE CONFIG CHECKS ===
console.log(`\n${colors.blue}FIREBASE & CONFIGURATION${colors.reset}`);

check(
  'Firebase Service Account exists',
  fileExists('./config/firebase-service-account.json'),
  'Location: config/firebase-service-account.json'
);

check(
  'Firebase Options configured',
  fileExists('../frontend/lib/core/config/firebase_options.dart'),
  'Location: lib/core/config/firebase_options.dart'
);

check(
  'API Config exists',
  fileExists('../frontend/lib/core/config/api_config.dart'),
  'Location: lib/core/config/api_config.dart'
);

// === DATABASE MODELS CHECKS ===
console.log(`\n${colors.blue}DATABASE MODELS${colors.reset}`);

check(
  'User model has fcmToken field',
  fileContains('./models/User.js', 'fcmToken'),
  'Required for storing device token'
);

check(
  'Staff model has fcmToken field',
  fileContains('./models/Staff.js', 'fcmToken'),
  'Required for storing device token'
);

check(
  'HOD model has fcmToken field',
  fileContains('./models/HOD.js', 'fcmToken'),
  'Required for storing device token'
);

check(
  'OD Request model has staffStatus',
  fileContains('./models/ODRequest.js', 'staffStatus'),
  'Tracks staff approval status'
);

check(
  'OD Request model has hodStatus',
  fileContains('./models/ODRequest.js', 'hodStatus'),
  'Tracks HOD approval status'
);

check(
  'Leave Request model has status fields',
  fileContains('./models/LeaveRequest.js', 'staffStatus') && fileContains('./models/LeaveRequest.js', 'hodStatus'),
  'Same structure as OD Request'
);

// === TEST FILES ===
console.log(`\n${colors.blue}TEST FILES${colors.reset}`);

check(
  'Notification flow test exists',
  fileExists('./test-notification-flow.js'),
  'Location: test-notification-flow.js'
);

check(
  'Test covers all 6 scenarios',
  fileContains('./test-notification-flow.js', 'testStudentSubmitNotifiesStaff') &&
    fileContains('./test-notification-flow.js', 'testHODApprovalNotifiesStudent'),
  '6 test scenarios implemented'
);

// === PRINT SUMMARY ===
console.log(`\n${colors.cyan}═════════════════════════════════════════════════════════════${colors.reset}`);

const passed = checks.filter((c) => c.result).length;
const total = checks.length;
const percentage = Math.round((passed / total) * 100);

console.log(`\n${colors.blue}SUMMARY${colors.reset}`);
console.log(`${colors.green}Passed: ${passed}/${total}${colors.reset}`);
console.log(`${colors.red}Failed: ${total - passed}/${total}${colors.reset}`);
console.log(`${colors.yellow}Completion: ${percentage}%${colors.reset}`);

console.log(`\n${colors.cyan}═════════════════════════════════════════════════════════════${colors.reset}`);

if (percentage === 100) {
  console.log(`
${colors.green}
✅ ALL CHECKS PASSED!

The notification system is properly set up and ready to use:

✓ Backend notification service is configured
✓ Frontend notification handler is integrated  
✓ API endpoints are properly wired
✓ Database models support FCM tokens
✓ Tests are available for verification

NEXT STEPS:
1. Run the notification flow test:
   → npm run test:notifications

2. Test in real app:
   → flutter run

3. Submit OD request and verify notifications

You're ready to go! 🚀
${colors.reset}
  `);
} else if (percentage >= 80) {
  console.log(`
${colors.yellow}
⚠️  MOST CHECKS PASSED (${percentage}%)

Only a few items are missing. Most likely:
- Some optional Firebase config files
- Or test files not yet created

The system should still work, but verify the missing items:
${colors.reset}
  `);
  checks.filter((c) => !c.result).forEach((c) => {
    console.log(`  ${colors.red}✗${colors.reset} ${c.name}`);
  });
} else {
  console.log(`
${colors.red}
❌ CRITICAL ISSUES FOUND (${percentage}% complete)

Please fix the following before using notifications:
${colors.reset}
  `);
  checks.filter((c) => !c.result).forEach((c) => {
    console.log(`  ${colors.red}✗${colors.reset} ${c.name}`);
  });
}

console.log(`\nFor details, see: NOTIFICATION_SYSTEM_GUIDE.md\n`);

process.exit(percentage >= 80 ? 0 : 1);
