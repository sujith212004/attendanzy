const User = require('../models/User');
const Staff = require('../models/Staff');
const HOD = require('../models/HOD');

// Login controller
// Login controller
const { pool } = require('../config/pg');

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

        let user = null;
        let query = '';
        const lowerRole = role.toLowerCase();

        if (lowerRole === 'staff') {
            // Check Staff table
            query = `
                SELECT * FROM staff 
                WHERE LOWER(email) = LOWER($1)
                AND password = $2
                AND department = $3
            `;
            const result = await pool.query(query, [email, password, department]);
            user = result.rows[0];

        } else if (lowerRole === 'hod') {
            // Check HOD table
            query = `
                SELECT * FROM hod 
                WHERE LOWER(email) = LOWER($1)
                AND password = $2
                AND department = $3
            `;
            const result = await pool.query(query, [email, password, department]);
            user = result.rows[0];

        } else if (lowerRole === 'user') {
            // Check Student tables (dynamic cse_*, etc.)
            // First, find all valid student tables
            // Note: In a real scenario with year/sec, we could target specific table
            const tablesResult = await pool.query(`
                SELECT table_name 
                FROM information_schema.tables 
                WHERE table_schema = 'public' 
                AND table_name LIKE 'cse_%' 
            `); // Assuming student tables start with department prefix like cse_

            // Iterate through possible student tables to find the user
            // Optimization: If department is 'CSE', only check 'cse_%' tables.
            // Map department to table prefix if needed.

            const studentTables = tablesResult.rows.map(r => r.table_name);

            for (const table of studentTables) {
                query = `
                    SELECT *, '${table}' as source_table FROM "${table}" 
                    WHERE LOWER(email) = LOWER($1)
                    AND password = $2
                    -- AND department = $3 -- Table implies dept usually, but can check if column exists
                `;

                try {
                    const result = await pool.query(query, [email, password]);
                    if (result.rows.length > 0) {
                        user = result.rows[0];
                        // Normalize year/sec from table name if needed or assume columns exist
                        break;
                    }
                } catch (err) {
                    // Ignore errors (e.g. column mismatch) and continue to next table
                    // console.warn(`Skipping table ${table} due to error: ${err.message}`);
                }
            }
        } else {
            return res.status(400).json({
                success: false,
                message: 'Invalid role',
            });
        }

        if (!user) {
            return res.status(401).json({
                success: false,
                message: 'Invalid credentials. Please check your email, password, role, and department.',
            });
        }

        // Prepare user data for response
        const userData = {
            email: user.email || user.college_email || '',
            name: user.name || '',
            role: lowerRole,
            department: user.department || department, // Fallback to input dept if table doesn't have it
            isStaff: lowerRole === 'staff' || lowerRole === 'hod',
        };

        // Add year and section for users and staff
        if (lowerRole === 'user') {
            userData.year = user.year || '';
            userData.sec = user.sec || '';
            userData.rollNumber = user.roll_number || '';
        }

        if (lowerRole === 'staff') {
            userData.year = user.year || ''; // Staff table might have these or not
            userData.sec = user.sec || '';
            userData.staffName = user.name || '';
            userData.inchargeName = user.incharge_name || '';
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

        let user = null;
        const lowerRole = role.toLowerCase();
        let query = '';

        if (lowerRole === 'staff') {
            query = `SELECT * FROM staff WHERE LOWER(email) = LOWER($1)`;
            const result = await pool.query(query, [email]);
            user = result.rows[0];

        } else if (lowerRole === 'hod') {
            query = `SELECT * FROM hod WHERE LOWER(email) = LOWER($1)`;
            const result = await pool.query(query, [email]);
            user = result.rows[0];

        } else if (lowerRole === 'user') {
            // Check all student tables
            const tablesResult = await pool.query(`
                SELECT table_name 
                FROM information_schema.tables 
                WHERE table_schema = 'public' 
                AND table_name LIKE 'cse_%' 
            `);

            const studentTables = tablesResult.rows.map(r => r.table_name);

            for (const table of studentTables) {
                query = `SELECT *, '${table}' as source_table FROM "${table}" WHERE LOWER(email) = LOWER($1)`;
                try {
                    const result = await pool.query(query, [email]);
                    if (result.rows.length > 0) {
                        user = result.rows[0];
                        break;
                    }
                } catch (err) {
                    // Continue to next table
                }
            }
        } else {
            return res.status(400).json({
                success: false,
                message: 'Invalid role',
            });
        }

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
