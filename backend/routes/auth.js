const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');

// @route   POST /api/auth/login
// @desc    Login user (User/Staff/HOD)
// @access  Public
// @route   POST /api/auth/login
// @desc    Login user (User/Staff/HOD)
// @access  Public
router.post('/login', authController.login);

// @route   POST /api/auth/forgot-password
// @desc    Forgot Password
router.post('/forgot-password', authController.forgotPassword);

// @route   POST /api/auth/reset-password
// @desc    Reset Password
router.post('/reset-password', authController.resetPassword);

// @route   POST /api/auth/change-password (LEGACY)
// @desc    Change user password (authenticated generally, or known old password)
// NOTE: Replaced by reset-password for email flow, but keeping if specific change-password is needed authenticated
// For now, removing or keeping? Let's generic "change-password" isn't in new plan, but let's keep it safe or just ignore.
// Actually, let's keep it commented out or remove if not used. 
// But wait, the controller removed `changePassword`. So we must remove this route or it will crash.
// Removing `change-password` route as per plan (implicit replacement).

// @route   GET /api/auth/profile
// @desc    Get user profile
// @access  Public (should be protected in production)
router.get('/profile', authController.getProfile);

module.exports = router;
