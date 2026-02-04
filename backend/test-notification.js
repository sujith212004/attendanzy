/**
 * Test script to verify Firebase push notifications are working
 * 
 * Usage: node test-notification.js <email>
 * Example: node test-notification.js student@example.com
 */

require('dotenv').config();
const mongoose = require('mongoose');

// MongoDB connection
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/attendance_DB';

// User schema (simplified)
const userSchema = new mongoose.Schema({
    name: String,
    Name: String,
    email: { type: String, lowercase: true },
    'College Email': String,
    fcmToken: String,
    role: String,
    department: String,
}, { strict: false });

const UserProfile = mongoose.model('TestUserProfile', userSchema, 'profile');
const Staff = mongoose.model('TestStaff', userSchema, 'Staff');
const HOD = mongoose.model('TestHOD', userSchema, 'HOD');

// Firebase Admin setup
const admin = require('firebase-admin');

async function initFirebase() {
    try {
        const serviceAccount = require('./config/firebase-service-account.json');
        admin.initializeApp({
            credential: admin.credential.cert(serviceAccount)
        });
        console.log('✅ Firebase Admin initialized successfully');
        return true;
    } catch (error) {
        console.error('❌ Firebase initialization failed:', error.message);
        return false;
    }
}

async function testNotification(email) {
    console.log('\n========================================');
    console.log('🔔 NOTIFICATION TEST');
    console.log('========================================\n');

    // Connect to MongoDB
    try {
        await mongoose.connect(MONGODB_URI);
        console.log('✅ Connected to MongoDB');
    } catch (error) {
        console.error('❌ MongoDB connection failed:', error.message);
        process.exit(1);
    }

    // Initialize Firebase
    const firebaseReady = await initFirebase();
    if (!firebaseReady) {
        console.log('\n⚠️  Make sure firebase-service-account.json is in backend/config/');
        process.exit(1);
    }

    // Find user in all collections
    const emailLower = email.toLowerCase();
    let user = await UserProfile.findOne({ email: emailLower });
    let userType = 'Student';
    
    if (!user) {
        user = await Staff.findOne({ 
            $or: [{ email: emailLower }, { 'College Email': emailLower }] 
        });
        userType = 'Staff';
    }
    
    if (!user) {
        user = await HOD.findOne({ 
            $or: [{ email: emailLower }, { 'College Email': emailLower }] 
        });
        userType = 'HOD';
    }
    
    if (!user) {
        console.log(`\n❌ User not found: ${email}`);
        console.log('\nSearched in: profile, Staff, HOD collections');
        console.log('\nAvailable users with FCM tokens:');
        const profileTokens = await UserProfile.find({ fcmToken: { $exists: true, $ne: null } }).select('email name fcmToken');
        const staffTokens = await Staff.find({ fcmToken: { $exists: true, $ne: null } }).select('email name Name fcmToken');
        const hodTokens = await HOD.find({ fcmToken: { $exists: true, $ne: null } }).select('email name Name fcmToken');
        const allUsers = [...profileTokens, ...staffTokens, ...hodTokens];
        if (allUsers.length === 0) {
            console.log('  No users have FCM tokens yet.');
            console.log('  Users need to login on the app first to register their device.');
        } else {
            allUsers.forEach(u => {
                console.log(`  - ${u.email || u['College Email']} (${u.name || u.Name})`);
            });
        }
        await mongoose.disconnect();
        process.exit(1);
    }

    console.log(`\n✅ ${userType} found: ${user.name || user.Name} (${user.email || user['College Email']})`);
    
    if (!user.fcmToken) {
        console.log('❌ User does not have an FCM token');
        console.log('   The user needs to login on the app to register their device.');
        await mongoose.disconnect();
        process.exit(1);
    }

    console.log(`✅ FCM Token exists: ${user.fcmToken.substring(0, 30)}...`);

    // Send test notification
    console.log('\n📤 Sending test notification...\n');

    const message = {
        notification: {
            title: '🧪 Test Notification',
            body: 'If you see this, notifications are working!'
        },
        data: {
            type: 'test',
            timestamp: new Date().toISOString()
        },
        token: user.fcmToken
    };

    try {
        const response = await admin.messaging().send(message);
        console.log('========================================');
        console.log('✅ NOTIFICATION SENT SUCCESSFULLY!');
        console.log('========================================');
        console.log(`Message ID: ${response}`);
        console.log('\n📱 Check the device for the notification!');
    } catch (error) {
        console.log('========================================');
        console.log('❌ NOTIFICATION FAILED');
        console.log('========================================');
        console.log(`Error: ${error.message}`);
        
        if (error.code === 'messaging/invalid-registration-token') {
            console.log('\n⚠️  The FCM token is invalid. User needs to re-login on the app.');
        } else if (error.code === 'messaging/registration-token-not-registered') {
            console.log('\n⚠️  The device is not registered. User needs to re-login on the app.');
        }
    }

    await mongoose.disconnect();
    console.log('\n✅ Test complete');
}

// Get email from command line
const email = process.argv[2];

if (!email) {
    console.log('Usage: node test-notification.js <email>');
    console.log('Example: node test-notification.js student@example.com');
    console.log('\nOr run without email to see all users with FCM tokens:');
    console.log('  node test-notification.js list');
    
    if (process.argv[2] === 'list') {
        // List all users with tokens
        mongoose.connect(MONGODB_URI).then(async () => {
            const users = await User.find({ fcmToken: { $exists: true, $ne: null } }).select('email name');
            console.log('\nUsers with FCM tokens:');
            users.forEach(u => console.log(`  - ${u.email}`));
            await mongoose.disconnect();
        });
    }
    process.exit(0);
}

testNotification(email);
