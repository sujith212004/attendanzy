const mongoose = require('mongoose');

const odRequestSchema = new mongoose.Schema({
    studentName: {
        type: String,
        required: true,
    },
    studentEmail: {
        type: String,
        required: true,
    },
    from: {
        type: String,
        required: true,
    },
    to: {
        type: String,
        required: true,
    },
    subject: {
        type: String,
        required: true,
    },
    content: {
        type: String,
        required: true,
    },
    image: {
        type: String, // Base64 encoded image
    },
    department: {
        type: String,
        required: true,
    },
    year: {
        type: String,
        required: true,
    },
    section: {
        type: String,
        required: true,
    },
    staffStatus: {
        type: String,
        enum: ['pending', 'approved', 'rejected'],
        default: 'pending',
    },
    hodStatus: {
        type: String,
        enum: ['pending', 'approved', 'rejected'],
        default: 'pending',
    },
    status: {
        type: String,
        enum: ['pending', 'accepted', 'rejected'],
        default: 'pending',
    },
    staffRemarks: String,
    hodRemarks: String,
    // Forwarding details (set when staff approves)
    forwardedBy: {
        type: String,
    },
    forwardedByIncharge: {
        type: String,
    },
    forwardedAt: {
        type: String,
    },
    // Rejection details
    rejectedBy: {
        type: String,
    },
    rejectionReason: {
        type: String,
    },
    createdAt: {
        type: String,
        default: () => new Date().toISOString(),
    },
    updatedAt: {
        type: String,
    },
}, {
    collection: 'od_requests',
    timestamps: false,
    strict: false,
});

module.exports = mongoose.model('ODRequest', odRequestSchema);
