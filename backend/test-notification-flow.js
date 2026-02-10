/**
 * Notification Flow Test Suite
 * Tests whether notifications are sent to Student, Staff, and HOD correctly
 * 
 * Usage: node test-notification-flow.js
 */

const mongoose = require('mongoose');

// Mock Firebase Admin before requiring notificationService
const mockFirebaseAdmin = {
  initializeApp: () => {},
  credential: {
    cert: () => ({})
  },
  messaging: () => ({
    send: async () => ({ success: true, messageId: 'mock-message-id' })
  })
};

require.cache[require.resolve('firebase-admin')] = {
  exports: mockFirebaseAdmin
};

const {
  notifyStaffOnNewRequest,
  notifyHODOnForward,
  notifyStudentOnStatusChange,
  notifyStaffOnHODDecision,
} = require('./services/notificationService');

// Color codes for console output
const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m',
  magenta: '\x1b[35m',
};

const log = {
  success: (msg) => console.log(`${colors.green}✓ ${msg}${colors.reset}`),
  error: (msg) => console.log(`${colors.red}✗ ${msg}${colors.reset}`),
  info: (msg) => console.log(`${colors.blue}ℹ ${msg}${colors.reset}`),
  warn: (msg) => console.log(`${colors.yellow}⚠ ${msg}${colors.reset}`),
  section: (msg) => console.log(`\n${colors.cyan}═══ ${msg} ═══${colors.reset}`),
  indent: (msg, level = 1) => console.log('  '.repeat(level) + msg),
};

// Mock data
const mockStudent = {
  _id: new mongoose.Types.ObjectId(),
  email: 'student@college.com',
  name: 'John Doe',
  studentId: 'STU001',
  year: '2nd',
  section: 'A',
  department: 'CSE',
  fcmToken: 'mock_student_fcm_token_12345',
};

const mockStaff = {
  _id: new mongoose.Types.ObjectId(),
  email: 'staff@college.com',
  Name: 'Dr. Staff Member',
  name: 'Dr. Staff Member',
  year: '2nd',
  sec: 'A',
  section: 'A',
  department: 'CSE',
  fcmToken: 'mock_staff_fcm_token_12345',
};

const mockHOD = {
  _id: new mongoose.Types.ObjectId(),
  email: 'hod@college.com',
  Name: 'Prof. HOD',
  name: 'Prof. HOD',
  department: 'CSE',
  fcmToken: 'mock_hod_fcm_token_12345',
};

const mockODRequest = {
  _id: new mongoose.Types.ObjectId(),
  studentName: mockStudent.name,
  studentEmail: mockStudent.email,
  from: '2024-03-01',
  to: '2024-03-01',
  subject: 'Medical Emergency',
  content: 'Had to visit hospital for emergency',
  department: mockStudent.department,
  year: mockStudent.year,
  section: mockStudent.section,
  staffStatus: 'pending',
  hodStatus: 'pending',
  status: 'pending',
  createdAt: new Date().toISOString(),
};

// Test results tracker
let testResults = {
  total: 0,
  passed: 0,
  failed: 0,
  tests: [],
};

// Mock notification responses
let notificationLog = [];

// Intercept notifications
const originalConsoleLog = console.log;
console.log = function (...args) {
  const message = args.join(' ');
  if (message.includes('Notifying') || message.includes('notification')) {
    notificationLog.push(message);
  }
  originalConsoleLog.apply(console, args);
};

/**
 * Test 1: Student submits OD request → Staff should be notified
 */
async function testStudentSubmitNotifiesStaff() {
  log.section('TEST 1: Student Submits OD Request → Staff Gets Notified');

  try {
    log.info('Simulating: Student submits OD request');
    log.indent('Request data:');
    log.indent(`- Student: ${mockODRequest.studentName} (${mockODRequest.studentEmail})`, 2);
    log.indent(`- Department: ${mockODRequest.department}`, 2);
    log.indent(`- Year: ${mockODRequest.year}, Section: ${mockODRequest.section}`, 2);

    // Mock Staff.find in notificationService
    const Staff = require('./models/Staff');
    const originalFind = Staff.find;
    Staff.find = async () => [mockStaff];

    try {
      // Call notification service
      const result = await notifyStaffOnNewRequest(mockODRequest, 'OD');

      log.info(`Notification result:`, result);

      // Check if staff was notified
      if (result.success && result.results && result.results.length > 0) {
        log.success(`Staff notification sent successfully`);
        log.indent(`- Recipients: ${result.results.map((r) => r.email).join(', ')}`, 1);
        log.indent(`- Message: "New OD Request Received"`, 1);
        recordTest('Student → Staff Notification', true, result);
      } else {
        log.error(`Staff notification failed or no staff found`);
        recordTest('Student → Staff Notification', false, result);
      }
    } finally {
      Staff.find = originalFind;
    }
  } catch (error) {
    log.error(`Test failed: ${error.message}`);
    recordTest('Student → Staff Notification', false, error.message);
  }
}

/**
 * Test 2: Staff accepts and forwards → HOD should be notified
 */
async function testStaffForwardNotifiesHOD() {
  log.section('TEST 2: Staff Forwards Request → HOD Gets Notified');

  try {
    // Mock the request with staff approval
    const forwardedRequest = {
      ...mockODRequest,
      staffStatus: 'approved',
      forwardedBy: mockStaff.name,
      forwardedAt: new Date().toISOString(),
    };

    log.info('Simulating: Staff clicks "Accept" to forward to HOD');
    log.indent('Request update:');
    log.indent(`- staffStatus: ${forwardedRequest.staffStatus}`, 2);
    log.indent(`- Forwarded by: ${forwardedRequest.forwardedBy}`, 2);

    // Mock HOD.findOne to return our mock HOD
    const HOD = require('./models/HOD');
    const originalHODFindOne = HOD.findOne;
    HOD.findOne = async () => mockHOD;

    try {
      // Call notification service
      const result = await notifyHODOnForward(forwardedRequest, 'OD');

      log.info(`HOD Notification result:`, result);

      if (result.success) {
        log.success(`HOD notification sent successfully`);
        log.indent(`- Recipient: ${mockHOD.email}`, 1);
        log.indent(`- Message: "OD Request - Awaiting Approval"`, 1);
        recordTest('Staff Forward → HOD Notification', true, result);
      } else {
        log.error(`HOD notification failed`);
        recordTest('Staff Forward → HOD Notification', false, result);
      }
    } finally {
      HOD.findOne = originalHODFindOne;
    }
  } catch (error) {
    log.error(`Test failed: ${error.message}`);
    recordTest('Staff Forward → HOD Notification', false, error.message);
  }
}

/**
 * Test 3: Staff forwards → Student should be notified
 */
async function testStaffForwardNotifiesStudent() {
  log.section('TEST 3: Staff Forwards Request → Student Gets Notified');

  try {
    const forwardedRequest = {
      ...mockODRequest,
      staffStatus: 'approved',
      forwardedBy: mockStaff.name,
    };

    log.info('Simulating: Student receives status update from staff');
    log.indent('Notification type: "Forwarded"', 1);

    // Mock User.findOne to return our mock student
    const User = require('./models/User');
    const originalUserFindOne = User.findOne;
    User.findOne = async () => mockStudent;

    try {
      // Call notification service
      const result = await notifyStudentOnStatusChange(forwardedRequest, 'OD', 'forwarded', 'staff');

      log.info(`Student notification result:`, result);

      if (result.success) {
        log.success(`Student notification sent successfully`);
        log.indent(`- Recipient: ${mockStudent.email}`, 1);
        log.indent(`- Message: "Your OD request has been forwarded to HOD"`, 1);
        recordTest('Staff Forward → Student Notification', true, result);
      } else {
        log.error(`Student notification failed`);
        recordTest('Staff Forward → Student Notification', false, result);
      }
    } finally {
      User.findOne = originalUserFindOne;
    }
  } catch (error) {
    log.error(`Test failed: ${error.message}`);
    recordTest('Staff Forward → Student Notification', false, error.message);
  }
}

/**
 * Test 4: HOD approves → Student should be notified
 */
async function testHODApprovalNotifiesStudent() {
  log.section('TEST 4: HOD Approves Request → Student Gets Notified');

  try {
    const approvedRequest = {
      ...mockODRequest,
      staffStatus: 'approved',
      hodStatus: 'approved',
      status: 'accepted',
    };

    log.info('Simulating: HOD clicks "Approve"');
    log.indent('Request update:');
    log.indent(`- hodStatus: ${approvedRequest.hodStatus}`, 2);
    log.indent(`- Final status: ${approvedRequest.status}`, 2);

    // Mock User.findOne to return our mock student
    const User = require('./models/User');
    const originalUserFindOne = User.findOne;
    User.findOne = async () => mockStudent;

    try {
      // Call notification service
      const result = await notifyStudentOnStatusChange(approvedRequest, 'OD', 'approved', 'hod');

      log.info(`Student approval notification result:`, result);

      if (result.success) {
        log.success(`Student approval notification sent successfully`);
        log.indent(`- Recipient: ${mockStudent.email}`, 1);
        log.indent(`- Message: "Your OD request has been approved by HOD"`, 1);
        recordTest('HOD Approve → Student Notification', true, result);
      } else {
        log.error(`Student approval notification failed`);
        recordTest('HOD Approve → Student Notification', false, result);
      }
    } finally {
      User.findOne = originalUserFindOne;
    }
  } catch (error) {
    log.error(`Test failed: ${error.message}`);
    recordTest('HOD Approve → Student Notification', false, error.message);
  }
}

/**
 * Test 5: HOD rejects → Student should be notified
 */
async function testHODRejectionNotifiesStudent() {
  log.section('TEST 5: HOD Rejects Request → Student Gets Notified');

  try {
    const rejectedRequest = {
      ...mockODRequest,
      staffStatus: 'approved',
      hodStatus: 'rejected',
      status: 'rejected',
      hodRemarks: 'Insufficient reasons provided',
    };

    log.info('Simulating: HOD clicks "Reject"');
    log.indent('Request update:');
    log.indent(`- hodStatus: ${rejectedRequest.hodStatus}`, 2);
    log.indent(`- Final status: ${rejectedRequest.status}`, 2);
    log.indent(`- Remarks: ${rejectedRequest.hodRemarks}`, 2);

    // Mock User.findOne to return our mock student
    const User = require('./models/User');
    const originalUserFindOne = User.findOne;
    User.findOne = async () => mockStudent;

    try {
      // Call notification service
      const result = await notifyStudentOnStatusChange(rejectedRequest, 'OD', 'rejected', 'hod');

      log.info(`Student rejection notification result:`, result);

      if (result.success) {
        log.success(`Student rejection notification sent successfully`);
        log.indent(`- Recipient: ${mockStudent.email}`, 1);
        log.indent(`- Message: "Your OD request has been rejected by HOD"`, 1);
        recordTest('HOD Reject → Student Notification', true, result);
      } else {
        log.error(`Student rejection notification failed`);
        recordTest('HOD Reject → Student Notification', false, result);
      }
    } finally {
      User.findOne = originalUserFindOne;
    }
  } catch (error) {
    log.error(`Test failed: ${error.message}`);
    recordTest('HOD Reject → Student Notification', false, error.message);
  }
}

/**
 * Test 6: Staff rejects → Student should be notified
 */
async function testStaffRejectionNotifiesStudent() {
  log.section('TEST 6: Staff Rejects Request → Student Gets Notified');

  try {
    const rejectedRequest = {
      ...mockODRequest,
      staffStatus: 'rejected',
      status: 'rejected',
      rejectionReason: 'Invalid OD reason',
    };

    log.info('Simulating: Staff clicks "Reject"');
    log.indent('Request update:');
    log.indent(`- staffStatus: ${rejectedRequest.staffStatus}`, 2);
    log.indent(`- Final status: ${rejectedRequest.status}`, 2);
    log.indent(`- Reason: ${rejectedRequest.rejectionReason}`, 2);

    // Mock User.findOne to return our mock student
    const User = require('./models/User');
    const originalUserFindOne = User.findOne;
    User.findOne = async () => mockStudent;

    try {
      // Call notification service
      const result = await notifyStudentOnStatusChange(rejectedRequest, 'OD', 'rejected', 'staff');

      log.info(`Student rejection notification result:`, result);

      if (result.success) {
        log.success(`Student rejection notification sent successfully`);
        log.indent(`- Recipient: ${mockStudent.email}`, 1);
        log.indent(`- Message: "Your OD request has been rejected by Staff"`, 1);
        recordTest('Staff Reject → Student Notification', true, result);
      } else {
        log.error(`Student rejection notification failed`);
        recordTest('Staff Reject → Student Notification', false, result);
      }
    } finally {
      User.findOne = originalUserFindOne;
    }
  } catch (error) {
    log.error(`Test failed: ${error.message}`);
    recordTest('Staff Reject → Student Notification', false, error.message);
  }
}

/**
 * Record test result
 */
function recordTest(testName, passed, result) {
  testResults.total++;
  if (passed) {
    testResults.passed++;
  } else {
    testResults.failed++;
  }
  testResults.tests.push({ name: testName, passed, result });
}

/**
 * Print test summary
 */
function printSummary() {
  log.section('TEST SUMMARY');

  log.info(`Total Tests: ${testResults.total}`);
  log.success(`Passed: ${testResults.passed}`);
  log.error(`Failed: ${testResults.failed}`);

  log.section('DETAILED RESULTS');
  testResults.tests.forEach((test, index) => {
    const status = test.passed
      ? `${colors.green}✓ PASS${colors.reset}`
      : `${colors.red}✗ FAIL${colors.reset}`;
    console.log(`${index + 1}. ${status} - ${test.name}`);
  });

  log.section('NOTIFICATION FLOW DIAGRAM');
  console.log(`
${colors.cyan}
SCENARIO: Student submits OD request
┌─────────────────────────────────────────┐
│         STUDENT SUBMITS OD              │
│    (Test 1: Student → Staff)            │
└──────────────────┬──────────────────────┘
                   │
                   ▼
         ┌─────────────────┐
         │  STAFF NOTIFIED │
         │  New OD Request │
         └────────┬────────┘
                  │
         Staff reviews & accepts
                  │
    ┌─────────────┴─────────────┐
    │                           │
    ▼                           ▼
(Test 2)                    (Test 3)
HOD NOTIFIED            STUDENT NOTIFIED
Awaiting Approval       Request Forwarded
    │                           
    │         HOD reviews
    │                
    ├─────────────┬─────────────┐
    │             │             │
(Test 4)      (Test 5)      Final
Approved      Rejected      Status
    │             │             │
    └──────┬──────┴──────┬──────┘
           │
           ▼
    STUDENT NOTIFIED
    ✓ Approved / ✗ Rejected

ALT SCENARIO: Staff rejects immediately
    │
(Test 6)
STUDENT NOTIFIED
✗ Rejected by Staff
${colors.reset}
  `);

  log.section('CONCLUSION');
  if (testResults.failed === 0) {
    log.success(`All notification flows are working correctly! ✓`);
    console.log(`
${colors.green}
The system will properly notify:
- ✓ Staff when student submits request
- ✓ HOD when staff forwards request
- ✓ Student when staff forwards request
- ✓ Student when HOD approves/rejects
- ✓ Student when staff rejects
${colors.reset}
    `);
  } else {
    log.error(`Some tests failed. Please review Firebase configuration and FCM tokens.`);
    console.log(`
${colors.red}
Issues found:
- Check that Firebase is properly initialized
- Verify FCM tokens are stored in database
- Check notification service error logs
- Ensure all user roles have fcmToken field
${colors.reset}
    `);
  }
}

/**
 * Main test runner
 */
async function runAllTests() {
  console.log(`
${colors.magenta}
╔═════════════════════════════════════════════════╗
║   NOTIFICATION FLOW TEST SUITE                  ║
║   Testing Student → Staff → HOD notification    ║
║   flow for OD and Leave requests                ║
╚═════════════════════════════════════════════════╝
${colors.reset}
  `);

  log.info('Starting notification flow tests...\n');

  // Run all tests
  await testStudentSubmitNotifiesStaff();
  await testStaffForwardNotifiesHOD();
  await testStaffForwardNotifiesStudent();
  await testHODApprovalNotifiesStudent();
  await testHODRejectionNotifiesStudent();
  await testStaffRejectionNotifiesStudent();

  // Print summary
  printSummary();

  process.exit(testResults.failed === 0 ? 0 : 1);
}

// Run tests
runAllTests().catch((error) => {
  log.error(`Critical error: ${error.message}`);
  process.exit(1);
});
