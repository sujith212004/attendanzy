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

        // Try to update in User (profile) collection first
        let result = await User.findOneAndUpdate(
            { email: emailLower },
            updateData,
            { new: true }
        );

        // If not found in User, try Staff collection
        if (!result) {
            result = await Staff.findOneAndUpdate(
                { $or: [{ email: emailLower }, { 'College Email': emailLower }] },
                updateData,
                { new: true }
            );
        }

        // If not found in Staff, try HOD collection
        if (!result) {
            result = await HOD.findOneAndUpdate(
                { $or: [{ email: emailLower }, { 'College Email': emailLower }] },
                updateData,
                { new: true }
            );
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

module.exports = router;
