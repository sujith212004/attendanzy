const User = require('../models/User');
const Staff = require('../models/Staff');
const HOD = require('../models/HOD');
const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const nodemailer = require('nodemailer');

// --- Helper Functions ---

// Get Model based on Role
const getModelByRole = (role) => {
    switch (role.toLowerCase()) {
        case 'user': return User;
        case 'staff': return Staff;
        case 'hod': return HOD;
        default: return null;
    }
};

// Send Email
const sendEmail = async (options) => {
    // Create transporter
    // For production, use environment variables for credentials
    // Create transporter
    // For production, use environment variables for credentials
    // Using explicit settings to avoid timeouts on some environments (like Render)
    const transporter = nodemailer.createTransport({
        host: 'smtp.gmail.com',
        port: 587,
        secure: false, // use false for STARTTLS; true for 465
        auth: {
            user: process.env.SMTP_EMAIL,
            pass: process.env.SMTP_PASSWORD,
        },
        // Add timeouts to fail faster if connection is blocked
        connectionTimeout: 10000,
        greetingTimeout: 10000,
        socketTimeout: 10000,
    });

    const message = {
        from: `${process.env.FROM_NAME || 'Attendanzy'} <${process.env.FROM_EMAIL || process.env.SMTP_EMAIL}>`,
        to: options.email,
        subject: options.subject,
        text: options.message,
        // html: options.html // Optional: Add HTML template
    };

    await transporter.sendMail(message);
};

// --- Controllers ---

// Login controller
exports.login = async (req, res) => {
    try {
        const { email, password, role, department } = req.body;

        // Validate input
        if (!email || !password || !role) {
            return res.status(400).json({
                success: false,
                message: 'Please provide email, password, and role',
            });
        }

        // Get Model
        const Model = getModelByRole(role);
        if (!Model) {
            return res.status(400).json({ success: false, message: 'Invalid role' });
        }

        // Find user
        // Select passwordHash explicitly if it exists
        const user = await Model.findOne({
            $or: [
                { email: new RegExp(`^${email}$`, 'i') },
                { 'College Email': new RegExp(`^${email}$`, 'i') }
            ],
            // Only check department if provided and required (e.g. for User/Staff login logic usually)
            // But let's keep it flexible. If department is passed, we can validation it after finding user, 
            // or include it in query if strict. 
            // The original code used department in query. Let's keep it if department is critical for uniqueness?
            // Actually, email should be unique across a role.
            // Let's Find by Email first.
        }).select('+passwordHash');

        if (!user) {
            return res.status(401).json({
                success: false,
                message: 'Invalid credentials',
            });
        }

        // Check Department if provided (Strict check from legacy code)
        if (department && user.department !== department) {
            return res.status(401).json({
                success: false,
                message: 'Department mismatch or invalid credentials',
            });
        }

        // --- Dual Password Check Strategy ---
        let isMatch = false;

        // 1. Check bcrypted hash first (New Secure Way)
        if (user.passwordHash) {
            isMatch = await bcrypt.compare(password, user.passwordHash);
        }

        // 2. If Hash didn't match (or didn't exist), check Plain Text (Legacy Way)
        if (!isMatch) {
            if (user.password === password) {
                isMatch = true;

                // MIGRATION: Secure the account by hashing the plain text password now
                try {
                    const salt = await bcrypt.genSalt(10);
                    user.passwordHash = await bcrypt.hash(password, salt);
                    await user.save();
                    console.log(`[Migration] User ${user.email} migrated to secure password.`);
                } catch (err) {
                    console.warn('[Migration] Failed to save hash:', err.message);
                }
            }
        }

        if (!isMatch) {
            return res.status(401).json({
                success: false,
                message: 'Invalid credentials',
            });
        }

        // Prepare response data
        const userData = {
            email: user.email || user['College Email'] || '',
            name: user.name || user.Name || '',
            role: role.toLowerCase(),
            department: user.department,
            isStaff: role.toLowerCase() === 'staff' || role.toLowerCase() === 'hod',
        };

        if (role.toLowerCase() === 'user') {
            userData.year = user.year || '';
            userData.sec = user.sec || '';
        }

        if (role.toLowerCase() === 'staff') {
            userData.year = user.year || '';
            userData.sec = user.sec || '';
            userData.staffName = user.name || user.Name || '';
            userData.inchargeName = user.inchargeName || user.incharge || '';
        }

        res.status(200).json({
            success: true,
            message: 'Login successful',
            user: userData,
            profile: user,
        });

    } catch (error) {
        console.error('Login error:', error);
        res.status(500).json({
            success: false,
            message: 'Server Error during login',
            error: error.message,
        });
    }
};

// Forgot Password
exports.forgotPassword = async (req, res) => {
    try {
        const { email, role } = req.body;

        const Model = getModelByRole(role);
        if (!Model) {
            return res.status(400).json({ success: false, message: 'Invalid role' });
        }

        const user = await Model.findOne({
            $or: [
                { email: new RegExp(`^${email}$`, 'i') },
                { 'College Email': new RegExp(`^${email}$`, 'i') }
            ],
        });

        if (!user) {
            return res.status(404).json({ success: false, message: 'User not found' });
        }

        // Generate OTP
        // Ensure OTP is a string
        const otp = Math.floor(100000 + Math.random() * 900000).toString();

        // Hash OTP (optional, but good practice. For simplicity with legacy, we might just store it. 
        // But let's try to be secure. Actually, let's store plain OTP for now to ensure simple matching, 
        // implementing "resetPasswordToken" as the OTP)
        // Ideally we hash the token. Let's start simple: Store the OTP directly.

        user.resetPasswordToken = otp; // In production, hash this!
        user.resetPasswordExpire = Date.now() + 10 * 60 * 1000; // 10 Minutes

        await user.save();

        const message = `You are receiving this email because you (or someone else) has requested the reset of a password. \n\n` +
            `Your OTP is: ${otp}\n\n` +
            `This OTP is valid for 10 minutes.`;

        try {
            await sendEmail({
                email: user.email || user['College Email'],
                subject: 'Attendanzy Password Reset OTP',
                message,
            });

            res.status(200).json({ success: true, message: 'Email sent successfully' });
        } catch (err) {
            console.error('Email send error:', err);
            user.resetPasswordToken = undefined;
            user.resetPasswordExpire = undefined;
            await user.save();
            return res.status(500).json({ success: false, message: 'Email could not be sent' });
        }

    } catch (error) {
        console.error('Forgot Password Error:', error);
        res.status(500).json({ success: false, message: 'Server Error' });
    }
};

// Reset Password
exports.resetPassword = async (req, res) => {
    try {
        const { email, role, otp, newPassword } = req.body;

        if (!email || !role || !otp || !newPassword) {
            return res.status(400).json({ success: false, message: 'Please provide all fields' });
        }

        const Model = getModelByRole(role);
        if (!Model) return res.status(400).json({ success: false, message: 'Invalid role' });

        const user = await Model.findOne({
            $or: [
                { email: new RegExp(`^${email}$`, 'i') },
                { 'College Email': new RegExp(`^${email}$`, 'i') }
            ],
            resetPasswordToken: otp,
            resetPasswordExpire: { $gt: Date.now() }
        });

        if (!user) {
            return res.status(400).json({ success: false, message: 'Invalid or expired OTP' });
        }

        // Set new password
        // 1. Set Password Hash
        const salt = await bcrypt.genSalt(10);
        user.passwordHash = await bcrypt.hash(newPassword, salt);

        // 2. Sync Plain Text Password (Legacy Compatibility)
        user.password = newPassword;

        // Clear tokens
        user.resetPasswordToken = undefined;
        user.resetPasswordExpire = undefined;

        await user.save();

        res.status(200).json({ success: true, message: 'Password updated successfully' });

    } catch (error) {
        console.error('Reset Password Error:', error);
        res.status(500).json({ success: false, message: 'Server Error' });
    }
};

// Get user profile (Unchanged mostly, just ensure it works with new fields present but not selected)
exports.getProfile = async (req, res) => {
    try {
        const { email, role } = req.query;

        if (!email || !role) {
            return res.status(400).json({
                success: false,
                message: 'Please provide email and role',
            });
        }

        const Model = getModelByRole(role);
        if (!Model) return res.status(400).json({ success: false, message: 'Invalid role' });

        const user = await Model.findOne({
            $or: [
                { email: new RegExp(`^${email}$`, 'i') },
                { 'College Email': new RegExp(`^${email}$`, 'i') }
            ],
        });

        if (!user) {
            return res.status(404).json({
                success: false,
                message: 'User not found',
            });
        }

        res.status(200).json({
            success: true,
            profile: user,
        });

    } catch (error) {
        console.error('Get profile error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch profile',
            error: error.message,
        });
    }
};
