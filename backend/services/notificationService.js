const admin = require('firebase-admin');
const User = require('../models/User');
const Staff = require('../models/Staff');
const HOD = require('../models/HOD');

// Initialize Firebase Admin (only once)
let firebaseInitialized = false;

const initializeFirebase = () => {
    if (firebaseInitialized) return;

    try {
        // Use service account from environment variable or file
        const serviceAccount = process.env.FIREBASE_SERVICE_ACCOUNT
            ? JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT)
            : require('../config/firebase-service-account.json');

        admin.initializeApp({
            credential: admin.credential.cert(serviceAccount)
        });
        firebaseInitialized = true;
        console.log('Firebase Admin initialized successfully');
    } catch (error) {
        console.error('Firebase Admin initialization failed:', error.message);
        console.log('Notifications will not work until Firebase is configured.');
    }
};

// Initialize on module load
initializeFirebase();

/**
 * Send notification to a specific user by email
 * @param {string} userEmail - The email of the user to send notification to
 * @param {string} title - Notification title
 * @param {string} body - Notification body
 * @param {object} data - Additional data to send with notification
 */
/**
 * Send notification directly to an FCM token
 * @param {string} token - The FCM token
 * @param {string} title - Notification title
 * @param {string} body - Notification body
 * @param {object} data - Additional data
 */
const sendNotificationToToken = async (token, title, body, data = {}) => {
    try {
        if (!firebaseInitialized) {
            console.log('Firebase not initialized. Skipping notification.');
            return { success: false, message: 'Firebase not initialized' };
        }

        const message = {
            notification: {
                title: title,
                body: body
            },
            data: {
                ...data,
                click_action: 'FLUTTER_NOTIFICATION_CLICK'
            },
            token: token
        };

        const response = await admin.messaging().send(message);
        return { success: true, messageId: response };
    } catch (error) {
        console.error('Error sending notification to token:', error);
        return { success: false, error: error.message };
    }
};

/**
 * Send notification to a specific user by email
 * @param {string} userEmail - The email of the user to send notification to
 * @param {string} title - Notification title
 * @param {string} body - Notification body
 * @param {object} data - Additional data to send with notification
 */
const sendNotificationToUser = async (userEmail, title, body, data = {}) => {
    try {
        console.log(`[NOTIF-DEBUG] sendNotificationToUser called for: ${userEmail}`);

        // Find user in all collections (User, Staff, HOD) and get their FCM token
        const emailLower = userEmail.toLowerCase().trim();

        // Escape regex special chars for safety
        const escapeRegExp = (string) => string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
        const emailRegex = new RegExp(`^${escapeRegExp(emailLower)}$`, 'i');

        console.log(`[NOTIF-DEBUG] Searching for user in 'users' collection...`);
        let user = await User.findOne({ email: emailRegex });
        let userType = 'Student';

        if (!user) {
            console.log(`[NOTIF-DEBUG] Not found in 'users', searching 'staff'...`);
            user = await Staff.findOne({
                $or: [
                    { email: emailLower },
                    { 'College Email': emailLower },
                    { email: new RegExp(`^${emailLower}$`, 'i') },
                    { 'College Email': new RegExp(`^${emailLower}$`, 'i') }
                ]
            });
            userType = 'Staff';
        }

        if (!user) {
            console.log(`[NOTIF-DEBUG] Not found in 'staff', searching 'hod'...`);
            user = await HOD.findOne({
                $or: [
                    { email: emailLower },
                    { 'College Email': emailLower },
                    { email: new RegExp(`^${emailLower}$`, 'i') },
                    { 'College Email': new RegExp(`^${emailLower}$`, 'i') }
                ]
            });
            userType = 'HOD';
        }

        if (!user) {
            console.log(`[NOTIF-DEBUG] ❌ User completely not found: ${userEmail}`);
            return { success: false, message: 'User not found in any collection' };
        }

        console.log(`[NOTIF-DEBUG] ✅ Found ${userType}: ${user.name || user.Name} (${user.email || user['College Email']})`);

        if (!user.fcmToken) {
            console.log(`[NOTIF-DEBUG] ❌ No FCM token found for user: ${userEmail}`);
            return { success: false, message: 'FCM token not found for user' };
        }

        console.log(`[NOTIF-DEBUG] Token found (len: ${user.fcmToken.length}). Sending to Firebase...`);
        const result = await sendNotificationToToken(user.fcmToken, title, body, data);

        if (result.success) {
            console.log(`[NOTIF-DEBUG] ✅ Notification successfully handed to Firebase. MsgID: ${result.messageId}`);
        } else {
            console.error(`[NOTIF-DEBUG] ❌ Firebase sending failed: ${result.error}`);
        }

        return result;
    } catch (error) {
        console.error(`[NOTIF-DEBUG] ❌ Exception in sendNotificationToUser:`, error);
        return { success: false, error: error.message };
    }
};

/**
 * Send notification to staff when student submits a request
 * Finds ALL staff by department, year, and section and notifies those with FCM tokens
 */
const notifyStaffOnNewRequest = async (request, requestType) => {
    try {
        const studentName = request.studentName || request.name || 'A student';
        const title = `New ${requestType} Request Received`;
        const body = `${studentName} (${request.year}, ${request.section}) has submitted a ${requestType.toLowerCase()} request. Please review and take action.`;
        const data = {
            type: 'new_request',
            requestType: requestType,
            requestId: request._id?.toString() || '',
            studentEmail: request.studentEmail || ''
        };

        console.log(`Looking for staff: dept=${request.department}, year=${request.year}, sec=${request.section}`);

        // Find ALL staff for this department/year/section
        // Escape special regex characters to prevent errors
        const escapeRegExp = (string) => string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

        const staffList = await Staff.find({
            department: new RegExp(`^${escapeRegExp(request.department.trim())}$`, 'i'),
            year: new RegExp(`^${escapeRegExp(request.year.trim())}$`, 'i'),
            sec: new RegExp(`^${escapeRegExp(request.section.trim())}$`, 'i')
        });

        if (!staffList || staffList.length === 0) {
            console.log(`No staff found for dept=${request.department}, year=${request.year}, sec=${request.section}`);
            return { success: false, message: 'No staff found for this class' };
        }

        console.log(`Found ${staffList.length} staff members for this class`);

        // Filter staff with FCM tokens
        const staffWithTokens = staffList.filter(s => s.fcmToken);

        if (staffWithTokens.length === 0) {
            console.log(`No staff have FCM tokens registered. Staff found: ${staffList.map(s => s.email).join(', ')}`);
            return { success: false, message: 'No staff have FCM tokens registered' };
        }

        // Send notification to ALL staff with FCM tokens
        const results = [];
        for (const staff of staffWithTokens) {
            console.log(`Notifying staff ${staff.name} (${staff.email}) about new ${requestType} request`);
            // Use token directly to avoid redundant lookup
            const result = await sendNotificationToToken(staff.fcmToken, title, body, data);
            results.push({ email: staff.email, ...result });
        }

        const successCount = results.filter(r => r.success).length;
        console.log(`Notifications sent: ${successCount}/${staffWithTokens.length} successful`);

        return {
            success: successCount > 0,
            message: `Notified ${successCount} of ${staffWithTokens.length} staff members`,
            results
        };
    } catch (error) {
        console.error('Error in notifyStaffOnNewRequest:', error);
        return { success: false, error: error.message };
    }
};

/**
 * Send notification to HOD when request is forwarded
 */
const notifyHODOnForward = async (request, requestType) => {
    try {
        console.log(`\n========== HOD FORWARD NOTIFICATION START ==========`);
        console.log(`Request Type: ${requestType}`);
        console.log(`Department: ${request.department}`);
        console.log(`Request ID: ${request._id}`);

        const studentName = request.studentName || request.name || 'A student';
        const title = `${requestType} Request - Awaiting Approval`;
        const body = `A ${requestType.toLowerCase()} request from ${studentName} (${request.year}, ${request.section}) has been forwarded by Staff and requires your approval.`;
        const data = {
            type: 'forwarded_request',
            requestType: requestType,
            requestId: request._id?.toString() || '',
            studentEmail: request.studentEmail || ''
        };

        console.log(`Searching for HOD in department: ${request.department}`);

        // Find HOD for this department in HOD collection
        const hod = await HOD.findOne({
            department: request.department
        });

        if (!hod) {
            console.error(`❌ No HOD found for department: ${request.department}`);
            console.log(`========== HOD FORWARD NOTIFICATION END ==========\n`);
            return { success: false, message: 'No HOD found for department' };
        }

        console.log(`Found HOD: ${hod.name || hod.Name} (${hod.email || hod['College Email']})`);

        if (!hod.email && !hod['College Email']) {
            console.error(`❌ HOD found but has no email address`);
            console.log(`========== HOD FORWARD NOTIFICATION END ==========\n`);
            return { success: false, message: 'HOD has no email' };
        }

        const hodEmail = hod.email || hod['College Email'];
        console.log(`Sending notification to HOD: ${hodEmail}`);
        console.log(`Notification Title: ${title}`);
        console.log(`Notification Body: ${body}`);

        const result = await sendNotificationToUser(hodEmail, title, body, data);

        if (result.success) {
            console.log(`✅ HOD NOTIFICATION SUCCESS`);
            console.log(`Message ID: ${result.messageId}`);
        } else {
            console.error(`❌ HOD NOTIFICATION FAILED: ${result.message || result.error}`);
        }

        console.log(`========== HOD FORWARD NOTIFICATION END ==========\n`);
        return result;
    } catch (error) {
        console.error(`❌ Error in notifyHODOnForward:`, error);
        console.log(`========== HOD FORWARD NOTIFICATION END ==========\n`);
        return { success: false, error: error.message };
    }
};

/**
 * Send notification to student when request is approved/rejected
 */
const notifyStudentOnStatusChange = async (request, requestType, newStatus, approverRole) => {
    try {
        console.log(`\n========== STUDENT NOTIFICATION START ==========`);
        console.log(`Request Type: ${requestType}`);
        console.log(`New Status: ${newStatus}`);
        console.log(`Approver Role: ${approverRole}`);
        console.log(`Request ID: ${request._id}`);

        const statusText = newStatus.toLowerCase();
        const studentName = request.studentName || request.name || 'Student';
        const studentEmail = request.studentEmail || request.email;

        if (!studentEmail) {
            console.error(`❌ NOTIFICATION FAILED: No student email found for request ${request._id}`);
            console.log(`========== STUDENT NOTIFICATION END ==========\n`);
            return { success: false, message: 'No student email found' };
        }

        console.log(`Student Email: ${studentEmail}`);
        console.log(`Student Name: ${studentName}`);

        let title, body;

        if (approverRole === 'hod') {
            if (statusText === 'approved' || statusText === 'accepted') {
                title = `${requestType} Request Accepted`;
                body = `Hi ${studentName}, your ${requestType.toLowerCase()} request has been accepted by HOD. You're good to go!`;
            } else if (statusText === 'rejected') {
                title = `${requestType} Request Rejected`;
                body = `Hi ${studentName}, your ${requestType.toLowerCase()} request has been rejected by HOD. Please contact your department for more details.`;
            } else {
                title = `${requestType} Request Update`;
                body = `Hi ${studentName}, your ${requestType.toLowerCase()} request status has been updated by HOD.`;
            }
        } else {
            // Staff actions
            if (statusText === 'approved' || statusText === 'accepted' || statusText === 'forwarded') {
                title = `${requestType} Request Forwarded`;
                body = `Hi ${studentName}, your ${requestType.toLowerCase()} request has been forwarded to HOD for final approval.`;
            } else if (statusText === 'rejected') {
                title = `${requestType} Request Rejected`;
                body = `Hi ${studentName}, your ${requestType.toLowerCase()} request has been rejected by Staff. Please contact your class incharge for details.`;
            } else {
                title = `${requestType} Request Update`;
                body = `Hi ${studentName}, your ${requestType.toLowerCase()} request status has been updated by Staff.`;
            }
        }

        console.log(`Notification Title: ${title}`);
        console.log(`Notification Body: ${body}`);

        const data = {
            type: approverRole === 'hod' ? 'hod_decision' : 'status_update',
            requestType: requestType,
            requestId: request._id?.toString() || '',
            status: newStatus,
            approverRole: approverRole
        };

        console.log(`Sending notification to student...`);
        const result = await sendNotificationToUser(studentEmail, title, body, data);

        if (result.success) {
            console.log(`✅ NOTIFICATION SUCCESS: Student notified successfully`);
            console.log(`Message ID: ${result.messageId}`);
        } else {
            console.error(`❌ NOTIFICATION FAILED: ${result.message || result.error}`);
        }

        console.log(`========== STUDENT NOTIFICATION END ==========\n`);
        return result;
    } catch (error) {
        console.error(`❌ NOTIFICATION ERROR: ${error.message}`);
        console.error(error);
        console.log(`========== STUDENT NOTIFICATION END ==========\n`);
        return { success: false, error: error.message };
    }
};

/**
 * Update user's FCM token
 */
const updateFCMToken = async (email, fcmToken) => {
    try {
        const result = await User.findOneAndUpdate(
            { email: email },
            { fcmToken: fcmToken, fcmTokenUpdatedAt: new Date() },
            { new: true }
        );
        return { success: !!result };
    } catch (error) {
        console.error('Error updating FCM token:', error);
        return { success: false, error: error.message };
    }
};

/**
 * Send notification to staff when HOD approves/rejects a request
 */
const notifyStaffOnHODDecision = async (request, requestType, status) => {
    try {
        const studentName = request.studentName || request.name || 'Student';
        const title = `${requestType} Request ${status} by HOD`;
        const body = `HOD has ${status.toLowerCase()} the ${requestType.toLowerCase()} request from ${studentName} (${request.year}, ${request.section}).`;

        const data = {
            type: 'hod_decision',
            requestType: requestType,
            requestId: request._id?.toString() || '',
            studentEmail: request.studentEmail || '',
            status: status
        };

        console.log(`Notifying staff about HOD decision for: dept=${request.department}, year=${request.year}, sec=${request.section}`);

        // Find ALL staff for this department/year/section (Case Insensitive)
        // Escape special regex characters to prevent errors
        const escapeRegExp = (string) => string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

        const staffList = await Staff.find({
            department: new RegExp(`^${escapeRegExp(request.department.trim())}$`, 'i'),
            year: new RegExp(`^${escapeRegExp(request.year.trim())}$`, 'i'),
            sec: new RegExp(`^${escapeRegExp(request.section.trim())}$`, 'i')
        });

        if (!staffList || staffList.length === 0) {
            console.log(`No staff found to notify about HOD decision (Dept: ${request.department}, Year: ${request.year}, Sec: ${request.section}).`);
            return { success: false, message: 'No staff found' };
        }

        const staffWithTokens = staffList.filter(s => s.fcmToken);

        if (staffWithTokens.length === 0) {
            console.log(`Found ${staffList.length} staff members, but none have FCM tokens.`);
            return { success: false, message: 'No staff have FCM tokens' };
        }

        console.log(`Found ${staffWithTokens.length} staff members with FCM tokens.`);

        const results = [];
        for (const staff of staffWithTokens) {
            console.log(`Notifying staff ${staff.name} about HOD decision`);
            // Use token directly to avoid redundant lookup
            const result = await sendNotificationToToken(staff.fcmToken, title, body, data);
            results.push({ email: staff.email, ...result });
        }

        return { success: true, results };
    } catch (error) {
        console.error('Error in notifyStaffOnHODDecision:', error);
        return { success: false, error: error.message };
    }
};

module.exports = {
    sendNotificationToUser,
    notifyStaffOnNewRequest,
    notifyHODOnForward,
    notifyStudentOnStatusChange,
    notifyStaffOnHODDecision,
    updateFCMToken
};
