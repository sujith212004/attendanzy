const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');

// @route   POST /api/auth/login
// @desc    Login user (User/Staff/HOD)
// @access  Public
router.post('/login', authController.login);

// @route   POST /api/auth/change-password
// @desc    Change user password
// @access  Public (should be protected in production)
router.post('/change-password', authController.changePassword);

// @route   GET /api/auth/profile
// @desc    Get user profile
// @access  Public (should be protected in production)
router.get('/profile', authController.getProfile);

module.exports = router;
