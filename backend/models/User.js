const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
    name: {
        type: String,
        required: true,
    },
    email: {
        type: String,
        required: true,
        unique: true,
        lowercase: true,
    },
    password: {
        type: String,
        required: true,
    },
    role: {
        type: String,
        enum: ['user', 'staff', 'hod'],
        default: 'user',
    },
    department: {
        type: String,
        required: true,
    },
    year: {
        type: String,
    },
    sec: {
        type: String,
    },
    rollNumber: String,
    phoneNumber: String,
    fcmToken: {
        type: String,
        default: null,
    },
    fcmTokenUpdatedAt: {
        type: Date,
        default: null,
    },
    createdAt: {
        type: Date,
        default: Date.now,
    },
}, {
    collection: 'profile', // Use existing collection name
    timestamps: false,
});

module.exports = mongoose.model('User', userSchema);
