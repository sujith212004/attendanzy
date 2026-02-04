const User = require('../models/User');
const Staff = require('../models/Staff');
const HOD = require('../models/HOD');

// Login controller
exports.login = async (req, res) => {
    try {
        const { email, password, role, department } = req.body;

        // Validate input
        if (!email || !password || !role || !department) {
            return res.status(400).json({
                success: false,
                message: 'Please provide email, password, role, and department',
            });
        }

        // Determine which collection to query based on role
        let Model;
        let collectionName;

        if (role.toLowerCase() === 'user') {
            Model = User;
            collectionName = 'profile';
        } else if (role.toLowerCase() === 'staff') {
            Model = Staff;
            collectionName = 'Staff';
        } else if (role.toLowerCase() === 'hod') {
            Model = HOD;
            collectionName = 'HOD';
        } else {
            return res.status(400).json({
                success: false,
                message: 'Invalid role',
            });
        }

        // Find user with case-insensitive email match
        const user = await Model.findOne({
            $or: [
                { email: new RegExp(`^${email}$`, 'i') },
                { 'College Email': new RegExp(`^${email}$`, 'i') }
            ],
            password: password,
            role: role.toLowerCase(),
            department: department,
        });

        if (!user) {
            return res.status(401).json({
                success: false,
                message: 'Invalid credentials. Please check your email, password, role, and department.',
            });
        }

        // Prepare user data for response
        const userData = {
            email: user.email || user['College Email'] || '',
            name: user.name || user.Name || '',
            role: role.toLowerCase(),
            department: user.department,
            isStaff: role.toLowerCase() === 'staff' || role.toLowerCase() === 'hod',
        };

        // Add year and section for users and staff
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

        // Return success response
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
            message: 'Failed to connect to the database',
            error: error.message,
        });
    }
};

// Change password controller
exports.changePassword = async (req, res) => {
    try {
        const { email, oldPassword, newPassword, role } = req.body;

        if (!email || !oldPassword || !newPassword || !role) {
            return res.status(400).json({
                success: false,
                message: 'Please provide all required fields',
            });
        }

        // Determine which model to use
        let Model;
        if (role.toLowerCase() === 'user') {
            Model = User;
        } else if (role.toLowerCase() === 'staff') {
            Model = Staff;
        } else if (role.toLowerCase() === 'hod') {
            Model = HOD;
        } else {
            return res.status(400).json({
                success: false,
                message: 'Invalid role',
            });
        }

        // Find user and verify old password
        const user = await Model.findOne({
            $or: [
                { email: new RegExp(`^${email}$`, 'i') },
                { 'College Email': new RegExp(`^${email}$`, 'i') }
            ],
            password: oldPassword,
        });

        if (!user) {
            return res.status(401).json({
                success: false,
                message: 'Invalid old password',
            });
        }

        // Update password
        user.password = newPassword;
        await user.save();

        res.status(200).json({
            success: true,
            message: 'Password changed successfully',
        });

    } catch (error) {
        console.error('Change password error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to change password',
            error: error.message,
        });
    }
};

// Get user profile
exports.getProfile = async (req, res) => {
    try {
        const { email, role } = req.query;

        if (!email || !role) {
            return res.status(400).json({
                success: false,
                message: 'Please provide email and role',
            });
        }

        let Model;
        if (role.toLowerCase() === 'user') {
            Model = User;
        } else if (role.toLowerCase() === 'staff') {
            Model = Staff;
        } else if (role.toLowerCase() === 'hod') {
            Model = HOD;
        } else {
            return res.status(400).json({
                success: false,
                message: 'Invalid role',
            });
        }

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
