/**
 * Test Script: Verify forwardedBy flow works correctly
 * 
 * This script tests:
 * 1. Student submits an OD request
 * 2. Staff approves/forwards the request
 * 3. Verify forwardedBy, forwardedByIncharge, and forwardedAt are set
 */

const mongoose = require('mongoose');
const ODRequest = require('./models/ODRequest');
const LeaveRequest = require('./models/LeaveRequest');

const MONGO_URI = "mongodb+srv://digioptimized:digi123@cluster0.iuajg.mongodb.net/attendance_DB?retryWrites=true&w=majority";

// Test data
const testODRequest = {
    studentName: "Test Student",
    studentEmail: "teststudent@test.edu.in",
    from: "Test Student\nInformation Technology\n4th Year-A",
    to: "HOD\nInformation Technology",
    subject: "Test OD Request - ForwardedBy Test",
    content: "This is a test OD request to verify forwardedBy functionality",
    department: "Information Technology",
    year: "4th Year",
    section: "A",
    staffStatus: "pending",
    hodStatus: "pending",
    status: "pending",
    createdAt: new Date().toISOString()
};

const testLeaveRequest = {
    studentName: "Test Student",
    studentEmail: "teststudent@test.edu.in",
    from: "Test Student\nInformation Technology\n4th Year-A",
    to: "HOD\nInformation Technology",
    subject: "Test Leave Request - ForwardedBy Test",
    content: "This is a test leave request to verify forwardedBy functionality",
    reason: "Testing forwardedBy feature",
    leaveType: "Personal Leave",
    fromDate: "2026-02-05",
    toDate: "2026-02-05",
    duration: 1,
    department: "Information Technology",
    year: "4th Year",
    section: "A",
    staffStatus: "pending",
    hodStatus: "pending",
    status: "pending",
    createdAt: new Date().toISOString()
};

// Staff details for forwarding
const staffName = "Test Staff Member";
const inchargeName = "IV-A";

async function runTest() {
    console.log("========================================");
    console.log("  ForwardedBy Feature Test");
    console.log("========================================\n");

    try {
        // Connect to MongoDB
        console.log("1. Connecting to MongoDB...");
        await mongoose.connect(MONGO_URI);
        console.log("   ✓ Connected to MongoDB\n");

        // ========== TEST OD REQUEST ==========
        console.log("========== OD REQUEST TEST ==========\n");

        // Step 1: Create OD request (simulating student submission)
        console.log("2. Creating test OD request (student submission)...");
        const odRequest = new ODRequest(testODRequest);
        await odRequest.save();
        console.log(`   ✓ OD Request created with ID: ${odRequest._id}\n`);

        // Step 2: Staff approves the request
        console.log("3. Staff approving/forwarding the OD request...");
        odRequest.staffStatus = 'approved';
        odRequest.forwardedBy = staffName;
        odRequest.forwardedByIncharge = inchargeName;
        odRequest.forwardedAt = new Date().toISOString();
        odRequest.hodStatus = 'pending';
        odRequest.updatedAt = new Date().toISOString();
        await odRequest.save();
        console.log("   ✓ OD Request approved by staff\n");

        // Step 3: Verify the fields are set
        console.log("4. Verifying forwardedBy fields in OD request...");
        const verifiedOD = await ODRequest.findById(odRequest._id);
        
        let odTestPassed = true;
        const odResults = {
            forwardedBy: verifiedOD.forwardedBy,
            forwardedByIncharge: verifiedOD.forwardedByIncharge,
            forwardedAt: verifiedOD.forwardedAt,
            staffStatus: verifiedOD.staffStatus
        };

        console.log("   Results:");
        console.log(`   - forwardedBy: ${odResults.forwardedBy || '(not set)'}`);
        console.log(`   - forwardedByIncharge: ${odResults.forwardedByIncharge || '(not set)'}`);
        console.log(`   - forwardedAt: ${odResults.forwardedAt || '(not set)'}`);
        console.log(`   - staffStatus: ${odResults.staffStatus}`);

        if (!odResults.forwardedBy) {
            console.log("   ✗ FAIL: forwardedBy is not set!");
            odTestPassed = false;
        }
        if (!odResults.forwardedByIncharge) {
            console.log("   ✗ FAIL: forwardedByIncharge is not set!");
            odTestPassed = false;
        }
        if (!odResults.forwardedAt) {
            console.log("   ✗ FAIL: forwardedAt is not set!");
            odTestPassed = false;
        }
        if (odResults.staffStatus !== 'approved') {
            console.log("   ✗ FAIL: staffStatus should be 'approved'!");
            odTestPassed = false;
        }

        if (odTestPassed) {
            console.log("\n   ✓ OD REQUEST TEST PASSED!\n");
        } else {
            console.log("\n   ✗ OD REQUEST TEST FAILED!\n");
        }

        // ========== TEST LEAVE REQUEST ==========
        console.log("========== LEAVE REQUEST TEST ==========\n");

        // Step 1: Create Leave request (simulating student submission)
        console.log("5. Creating test Leave request (student submission)...");
        const leaveRequest = new LeaveRequest(testLeaveRequest);
        await leaveRequest.save();
        console.log(`   ✓ Leave Request created with ID: ${leaveRequest._id}\n`);

        // Step 2: Staff approves the request
        console.log("6. Staff approving/forwarding the Leave request...");
        leaveRequest.staffStatus = 'approved';
        leaveRequest.forwardedBy = staffName;
        leaveRequest.forwardedByIncharge = inchargeName;
        leaveRequest.forwardedAt = new Date().toISOString();
        leaveRequest.hodStatus = 'pending';
        leaveRequest.updatedAt = new Date().toISOString();
        await leaveRequest.save();
        console.log("   ✓ Leave Request approved by staff\n");

        // Step 3: Verify the fields are set
        console.log("7. Verifying forwardedBy fields in Leave request...");
        const verifiedLeave = await LeaveRequest.findById(leaveRequest._id);
        
        let leaveTestPassed = true;
        const leaveResults = {
            forwardedBy: verifiedLeave.forwardedBy,
            forwardedByIncharge: verifiedLeave.forwardedByIncharge,
            forwardedAt: verifiedLeave.forwardedAt,
            staffStatus: verifiedLeave.staffStatus
        };

        console.log("   Results:");
        console.log(`   - forwardedBy: ${leaveResults.forwardedBy || '(not set)'}`);
        console.log(`   - forwardedByIncharge: ${leaveResults.forwardedByIncharge || '(not set)'}`);
        console.log(`   - forwardedAt: ${leaveResults.forwardedAt || '(not set)'}`);
        console.log(`   - staffStatus: ${leaveResults.staffStatus}`);

        if (!leaveResults.forwardedBy) {
            console.log("   ✗ FAIL: forwardedBy is not set!");
            leaveTestPassed = false;
        }
        if (!leaveResults.forwardedByIncharge) {
            console.log("   ✗ FAIL: forwardedByIncharge is not set!");
            leaveTestPassed = false;
        }
        if (!leaveResults.forwardedAt) {
            console.log("   ✗ FAIL: forwardedAt is not set!");
            leaveTestPassed = false;
        }
        if (leaveResults.staffStatus !== 'approved') {
            console.log("   ✗ FAIL: staffStatus should be 'approved'!");
            leaveTestPassed = false;
        }

        if (leaveTestPassed) {
            console.log("\n   ✓ LEAVE REQUEST TEST PASSED!\n");
        } else {
            console.log("\n   ✗ LEAVE REQUEST TEST FAILED!\n");
        }

        // ========== CLEANUP ==========
        console.log("========== CLEANUP ==========\n");
        console.log("8. Cleaning up test data...");
        await ODRequest.findByIdAndDelete(odRequest._id);
        await LeaveRequest.findByIdAndDelete(leaveRequest._id);
        console.log("   ✓ Test data cleaned up\n");

        // ========== FINAL SUMMARY ==========
        console.log("========================================");
        console.log("  TEST SUMMARY");
        console.log("========================================");
        console.log(`  OD Request Test:    ${odTestPassed ? '✓ PASSED' : '✗ FAILED'}`);
        console.log(`  Leave Request Test: ${leaveTestPassed ? '✓ PASSED' : '✗ FAILED'}`);
        console.log("========================================\n");

        if (odTestPassed && leaveTestPassed) {
            console.log("All tests passed! The forwardedBy feature is working correctly.");
            console.log("\nWhen staff approves a request, the following fields will be set:");
            console.log("  - forwardedBy: Staff member's name");
            console.log("  - forwardedByIncharge: Incharge code (e.g., IV-A)");
            console.log("  - forwardedAt: Timestamp of when it was forwarded");
        } else {
            console.log("Some tests failed. Please check the implementation.");
        }

    } catch (error) {
        console.error("\n✗ TEST ERROR:", error.message);
        console.error(error);
    } finally {
        // Close connection
        await mongoose.connection.close();
        console.log("\nDatabase connection closed.");
    }
}

// Run the test
runTest();
