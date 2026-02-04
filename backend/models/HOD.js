const mongoose = require('mongoose');

const hodSchema = new mongoose.Schema({
    name: {
        type: String,
        required: true,
    },
    Name: String, // Alternative field name
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
        default: 'hod',
    },
    department: {
        type: String,
        required: true,
    },
    phoneNumber: String,
}, {
    collection: 'HOD', // Use existing collection name
    timestamps: false,
    strict: false,
});

module.exports = mongoose.model('HOD', hodSchema);
