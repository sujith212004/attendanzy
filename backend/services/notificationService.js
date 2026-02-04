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
const sendNotificationToUser = async (userEmail, title, body, data = {}) => {
    try {
        if (!firebaseInitialized) {
            console.log('Firebase not initialized. Skipping notification.');
            return { success: false, message: 'Firebase not initialized' };
        }

        // Find user in all collections (User, Staff, HOD) and get their FCM token
        const emailLower = userEmail.toLowerCase();
        console.log(`Looking for user with email: ${emailLower}`);
        
        let user = await User.findOne({ email: emailLower });
        let userType = 'Student';
        
        if (!user) {
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
            console.log(`User not found: ${userEmail}`);
            return { success: false, message: 'User not found' };
        }
        
        console.log(`Found ${userType}: ${user.name || user.Name} (${user.email || user['College Email']})`);
        
        if (!user.fcmToken) {
            console.log(`No FCM token found for ${userType}: ${userEmail}`);
            return { success: false, message: 'FCM token not found' };
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
            token: user.fcmToken
        };

        const response = await admin.messaging().send(message);
        console.log(`Notification sent to ${userEmail}:`, response);
        return { success: true, messageId: response };
    } catch (error) {
        console.error(`Error sending notification to ${userEmail}:`, error);
        return { success: false, error: error.message };
    }
};

/**
 * Send notification to staff when student submits a request
 * Finds ALL staff by department, year, and section and notifies those with FCM tokens
 */
const notifyStaffOnNewRequest = async (request, requestType) => {
    try {
        const title = `New ${requestType} Request`;
        const body = `${request.studentName || request.name} has submitted a ${requestType.toLowerCase()} request`;
        const data = {
            type: 'new_request',
            requestType: requestType,
            requestId: request._id?.toString() || '',
            studentEmail: request.studentEmail || ''
        };

        console.log(`Looking for staff: dept=${request.department}, year=${request.year}, sec=${request.section}`);

        // Find ALL staff for this department/year/section
        const staffList = await Staff.find({
            department: request.department,
            year: request.year,
            sec: request.section
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
            const result = await sendNotificationToUser(staff.email, title, body, data);
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
        const title = `${requestType} Request Forwarded`;
        const body = `A ${requestType.toLowerCase()} request from ${request.studentName || request.name} needs your approval`;
        const data = {
            type: 'forwarded_request',
            requestType: requestType,
            requestId: request._id?.toString() || '',
            studentEmail: request.studentEmail || ''
        };

        // Find HOD for this department in HOD collection
        const hod = await HOD.findOne({ 
            department: request.department
        });

        if (hod && hod.email) {
            console.log(`Notifying HOD ${hod.email} about forwarded ${requestType} request`);
            return await sendNotificationToUser(hod.email, title, body, data);
        }
        
        console.log(`No HOD found for department: ${request.department}`);
        return { success: false, message: 'No HOD found for department' };
    } catch (error) {
        console.error('Error in notifyHODOnForward:', error);
        return { success: false, error: error.message };
    }
};

/**
 * Send notification to student when request is approved/rejected
 */
const notifyStudentOnStatusChange = async (request, requestType, newStatus, approverRole) => {
    const statusText = newStatus.toLowerCase();
    const approverText = approverRole === 'hod' ? 'HOD' : 'Staff';
    
    let title, body;
    
    if (statusText === 'approved' || statusText === 'accepted') {
        title = `${requestType} Request Approved! ✅`;
        body = `Your ${requestType.toLowerCase()} request has been approved by ${approverText}`;
    } else if (statusText === 'rejected') {
        title = `${requestType} Request Rejected ❌`;
        body = `Your ${requestType.toLowerCase()} request has been rejected by ${approverText}`;
    } else if (statusText === 'forwarded') {
        title = `${requestType} Request Forwarded 📤`;
        body = `Your ${requestType.toLowerCase()} request has been forwarded to HOD for approval`;
    } else {
        title = `${requestType} Request Updated`;
        body = `Your ${requestType.toLowerCase()} request status: ${newStatus}`;
    }

    const data = {
        type: 'status_update',
        requestType: requestType,
        requestId: request._id?.toString() || '',
        status: newStatus
    };

    const studentEmail = request.studentEmail || request.email;
    if (studentEmail) {
        return await sendNotificationToUser(studentEmail, title, body, data);
    }
    return { success: false, message: 'No student email found' };
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

module.exports = {
    sendNotificationToUser,
    notifyStaffOnNewRequest,
    notifyHODOnForward,
    notifyStudentOnStatusChange,
    updateFCMToken
};
