const admin = require('firebase-admin');
const User = require('../models/User');

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

        // Find user and get their FCM token
        const user = await User.findOne({ email: userEmail });
        
        if (!user || !user.fcmToken) {
            console.log(`No FCM token found for user: ${userEmail}`);
            return { success: false, message: 'User or FCM token not found' };
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
 */
const notifyStaffOnNewRequest = async (request, requestType) => {
    const title = `New ${requestType} Request`;
    const body = `${request.studentName || request.name} has submitted a ${requestType.toLowerCase()} request`;
    const data = {
        type: 'new_request',
        requestType: requestType,
        requestId: request._id?.toString() || '',
        studentEmail: request.studentEmail || ''
    };

    // Find staff for this department/year/section
    const staffEmail = request.classInChargeEmail || request.staffEmail;
    if (staffEmail) {
        return await sendNotificationToUser(staffEmail, title, body, data);
    }
    return { success: false, message: 'No staff email found' };
};

/**
 * Send notification to HOD when request is forwarded
 */
const notifyHODOnForward = async (request, requestType) => {
    const title = `${requestType} Request Forwarded`;
    const body = `A ${requestType.toLowerCase()} request from ${request.studentName || request.name} needs your approval`;
    const data = {
        type: 'forwarded_request',
        requestType: requestType,
        requestId: request._id?.toString() || '',
        studentEmail: request.studentEmail || ''
    };

    // Find HOD for this department
    const User = require('../models/User');
    const hod = await User.findOne({ 
        department: request.department, 
        role: 'hod' 
    });

    if (hod && hod.email) {
        return await sendNotificationToUser(hod.email, title, body, data);
    }
    return { success: false, message: 'No HOD found for department' };
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
