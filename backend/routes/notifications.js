const express = require('express');
const router = express.Router();
const { updateFCMToken } = require('../services/notificationService');
const User = require('../models/User');

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

        // Update token in database
        const result = await User.findOneAndUpdate(
            { email: email.toLowerCase() },
            { 
                fcmToken: fcmToken, 
                fcmTokenUpdatedAt: new Date() 
            },
            { new: true }
        );

        if (result) {
            res.json({ 
                success: true, 
                message: 'FCM token updated successfully' 
            });
        } else {
            res.status(404).json({ 
                success: false, 
                message: 'User not found' 
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

module.exports = router;
