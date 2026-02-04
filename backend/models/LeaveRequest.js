const mongoose = require('mongoose');

const leaveRequestSchema = new mongoose.Schema({
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
    reason: {
        type: String,
        required: true,
    },
    leaveType: {
        type: String,
        required: true,
        enum: ['Sick Leave', 'Emergency Leave', 'Personal Leave', 'Medical Leave', 'Family Leave', 'Other'],
    },
    fromDate: {
        type: String,
        required: true,
    },
    toDate: {
        type: String,
        required: true,
    },
    duration: {
        type: Number,
        required: true,
        max: 2, // Maximum 2 continuous days
    },
    image: {
        type: String, // Base64 encoded medical certificate
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
    collection: 'leave_requests',
    timestamps: false,
    strict: false,
});

module.exports = mongoose.model('LeaveRequest', leaveRequestSchema);
