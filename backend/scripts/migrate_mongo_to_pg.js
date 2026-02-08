const mongoose = require('mongoose');
const { pool } = require('../config/pg');
const User = require('../models/User');
const Staff = require('../models/Staff');
const HOD = require('../models/HOD');
require('dotenv').config();

// Connect to MongoDB
const connectDB = async () => {
    try {
        await mongoose.connect(process.env.MONGO_URI);
        console.log('MongoDB Connected');
    } catch (err) {
        console.error('MongoDB Connection Error:', err.message);
        process.exit(1);
    }
};

const migrate = async () => {
    await connectDB();

    try {
        // Fetch all users from different collections
        const users = await User.find({});
        const staff = await Staff.find({});
        const hods = await HOD.find({});

        const allUsers = [
            ...users.map(u => ({ ...u.toObject(), role: 'user', department: u.department })),
            ...staff.map(u => ({ ...u.toObject(), role: 'staff', department: u.department })),
            ...hods.map(u => ({ ...u.toObject(), role: 'hod', department: u.department }))
        ];

        console.log(`Found ${allUsers.length} users to migrate.`);

        for (const user of allUsers) {
            const email = user.email || user['College Email'];
            if (!email) {
                console.warn(`Skipping user without email: ${user._id}`);
                continue;
            }

            const query = `
                INSERT INTO users (
                    name, email, college_email, password, role, department, 
                    year, sec, roll_number, phone_number, incharge_name, fcm_token
                ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
                ON CONFLICT (email) DO NOTHING;
            `;

            const values = [
                user.name || user.Name,
                email,
                user['College Email'] || null,
                user.password,
                user.role,
                user.department,
                user.year || null,
                user.sec || null,
                user.rollNumber || null,
                user.phoneNumber || null,
                user.inchargeName || user.incharge || null,
                user.fcmToken || null
            ];

            await pool.query(query, values);
            console.log(`Migrated: ${email}`);
        }

        console.log('Migration completed successfully.');
        process.exit(0);
    } catch (error) {
        console.error('Migration error:', error);
        process.exit(1);
    }
};

migrate();
