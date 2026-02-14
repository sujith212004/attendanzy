const mongoose = require('mongoose');

const staffSchema = new mongoose.Schema({
    name: {
        type: String,
        required: true,
    },
    Name: String, // Alternative field name in existing data
    email: {
        type: String,
        required: true,
        unique: true,
        lowercase: true,
    },
    'College Email': String, // Alternative field name
    password: {
        type: String,
        required: true,
    },
    role: {
        type: String,
        default: 'staff',
    },
    department: {
        type: String,
        required: true,
    },
    year: String,
    sec: String,
    staffName: String,
    inchargeName: String,
    incharge: String,
    phoneNumber: String,
    fcmToken: {
        type: String,
        default: null,
    },
    fcmTokenUpdatedAt: {
        type: Date,
        default: null,
    },
    passwordHash: {
        type: String,
        select: false,
    },
    resetPasswordToken: String,
    resetPasswordExpire: Date,
}, {
    collection: 'Staff', // Use existing collection name
    timestamps: false,
    strict: false, // Allow flexible schema for existing data
});

module.exports = mongoose.model('Staff', staffSchema);
