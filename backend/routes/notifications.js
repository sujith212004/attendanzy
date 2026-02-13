const express = require('express');
const router = express.Router();
const { updateFCMToken } = require('../services/notificationService');
const User = require('../models/User');
const Staff = require('../models/Staff');
const HOD = require('../models/HOD');

// Update FCM token for a user
router.post('/update-token', async (req, res) => {
    try {
        const { email, fcmToken } = req.body;

        if (!email || !fcmToken) {
            return res.status(400).json({
                success: false,
                message: 'Email and FCM token are required'
            });
        }

        // Update token in database - check all collections
        const emailLower = email.toLowerCase();
        const updateData = {
            fcmToken: fcmToken,
            fcmTokenUpdatedAt: new Date()
        };

        console.log(`Attempting to update FCM token for: ${emailLower}`);

        // Try to update in User (profile) collection first
        let result = await User.findOneAndUpdate(
            { email: emailLower },
            { $set: updateData },
            { new: true }
        );
        if (result) console.log(`Found in User/profile collection`);

        // If not found in User, try Staff collection
        if (!result) {
            result = await Staff.findOneAndUpdate(
                {
                    $or: [
                        { email: emailLower },
                        { 'College Email': emailLower },
                        { email: new RegExp(`^${emailLower}$`, 'i') },
                        { 'College Email': new RegExp(`^${emailLower}$`, 'i') }
                    ]
                },
                { $set: updateData },
                { new: true }
            );
            if (result) console.log(`Found in Staff collection`);
        }

        // If not found in Staff, try HOD collection
        if (!result) {
            result = await HOD.findOneAndUpdate(
                {
                    $or: [
                        { email: emailLower },
                        { 'College Email': emailLower },
                        { email: new RegExp(`^${emailLower}$`, 'i') },
                        { 'College Email': new RegExp(`^${emailLower}$`, 'i') }
                    ]
                },
                { $set: updateData },
                { new: true }
            );
            if (result) console.log(`Found in HOD collection`);
        }

        if (result) {
            console.log(`FCM token updated for ${email}`);
            res.json({
                success: true,
                message: 'FCM token updated successfully'
            });
        } else {
            res.status(404).json({
                success: false,
                message: 'User not found in any collection'
            });
        }
    } catch (error) {
        console.error('Error updating FCM token:', error);
        res.status(500).json({
            success: false,
            message: 'Server error',
            error: error.message
        });
    }
});

// Test notification endpoint
router.post('/test', async (req, res) => {
    try {
        const { email, title, body } = req.body;
        const { sendNotificationToUser } = require('../services/notificationService');

        const result = await sendNotificationToUser(
            email,
            title || 'Test Notification',
            body || 'This is a test notification from Attendanzy'
        );

        res.json(result);
    } catch (error) {
        console.error('Error sending test notification:', error);
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// HOD decision notification endpoint
// Called by Flutter frontend after directly updating MongoDB status
router.post('/hod-decision', (req, res) => {
    try {
        const { studentEmail, studentName, requestType, status } = req.body;

        if (!studentEmail || !requestType || !status) {
            return res.status(400).json({
                success: false,
                message: 'studentEmail, requestType, and status are required'
            });
        }

        console.log(`\n========== HOD DECISION NOTIFICATION (QUEUED) ==========`);
        console.log(`Student: ${studentName || 'Unknown'} (${studentEmail})`);

        // Respond immediately to prevent frontend timeout
        res.json({
            success: true,
            message: 'Notification queued for processing'
        });

        // Background processing
        (async () => {
            try {
                const { sendNotificationToUser } = require('../services/notificationService');

                const statusText = status.toLowerCase();
                let title, body;

                if (statusText === 'approved' || statusText === 'accepted') {
                    title = `${requestType} Request Accepted`;
                    body = `Hi ${studentName || 'Student'}, your ${requestType.toLowerCase()} request has been accepted by HOD. You're good to go!`;
                } else if (statusText === 'rejected') {
                    title = `${requestType} Request Rejected`;
                    body = `Hi ${studentName || 'Student'}, your ${requestType.toLowerCase()} request has been rejected by HOD. Please contact your department for more details.`;
                } else {
                    title = `${requestType} Request Update`;
                    body = `Hi ${studentName || 'Student'}, your ${requestType.toLowerCase()} request status has been updated by HOD.`;
                }

                console.log(`Processing background notification for ${studentEmail}...`);
                const result = await sendNotificationToUser(studentEmail, title, body, {
                    type: 'hod_decision',
                    requestType: requestType,
                    status: status,
                    approverRole: 'hod'
                });

                console.log(`Background Notification result:`, result);
                console.log(`========== HOD DECISION NOTIFICATION END ==========\n`);
            } catch (err) {
                console.error('Error in background HOD notification:', err);
            }
        })();

    } catch (error) {
        console.error('Error queueing HOD decision notification:', error);
        // Only send response if header not sent (though validation checks should cover it)
        if (!res.headersSent) {
            res.status(500).json({
                success: false,
                error: error.message
            });
        }
    }
});

// Generic send notification endpoint
// Used by frontend for retry logic and custom notifications
// Generic send notification endpoint
// Used by frontend for retry logic and custom notifications
router.post('/send-notification', (req, res) => {
    try {
        const { studentEmail, title, body, data } = req.body;

        if (!studentEmail || !title || !body) {
            return res.status(400).json({
                success: false,
                message: 'studentEmail, title, and body are required'
            });
        }

        // Respond immediately
        res.json({
            success: true,
            message: 'Notification queued for processing'
        });

        console.log(`\n========== GENERIC NOTIFICATION (QUEUED) ==========`);
        console.log(`To: ${studentEmail}`);

        // Background processing
        (async () => {
            try {
                const { sendNotificationToUser } = require('../services/notificationService');

                // Add type to data if not present
                const notificationData = data || {};
                if (!notificationData.type) {
                    notificationData.type = 'generic_notification';
                }

                console.log(`Processing background notification for ${studentEmail}...`);
                const result = await sendNotificationToUser(studentEmail, title, body, notificationData);

                console.log(`Background Result: ${result.success ? 'Success' : 'Failed'}`);
                console.log(`========== GENERIC NOTIFICATION END ==========\n`);
            } catch (err) {
                console.error('Error in background generic notification:', err);
            }
        })();

    } catch (error) {
        console.error('Error queueing generic notification:', error);
        if (!res.headersSent) {
            res.status(500).json({
                success: false,
                error: error.message
            });
        }
    }
});

module.exports = router;
