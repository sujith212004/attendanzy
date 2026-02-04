require('dotenv').config();
const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const connectDB = require('./config/database');

// Initialize express app
const app = express();

// Connect to MongoDB
connectDB();

// Middleware
app.use(cors({
    origin: '*', // Allow all origins (configure this properly in production)
    credentials: true,
}));

app.use(express.json({ limit: '10mb' })); // For parsing application/json with larger payloads
app.use(express.urlencoded({ extended: true, limit: '10mb' })); // For parsing application/x-www-form-urlencoded

// Logging middleware
if (process.env.NODE_ENV === 'development') {
    app.use(morgan('dev'));
}

// Routes
app.use('/api/auth', require('./routes/auth'));
app.use('/api/od-requests', require('./routes/odRequests'));
app.use('/api/leave-requests', require('./routes/leaveRequests'));

// Health check route
app.get('/api/health', (req, res) => {
    res.status(200).json({
        success: true,
        message: 'Attendanzy Backend Server is running',
        timestamp: new Date().toISOString(),
    });
});

// Root route
app.get('/', (req, res) => {
    res.status(200).json({
        success: true,
        message: 'Welcome to Attendanzy Backend API',
        version: '1.0.0',
        endpoints: {
            auth: '/api/auth',
            odRequests: '/api/od-requests',
            leaveRequests: '/api/leave-requests',
            health: '/api/health',
        },
    });
});

// 404 handler
app.use((req, res, next) => {
    res.status(404).json({
        success: false,
        message: 'Route not found',
    });
});

// Error handling middleware
app.use((err, req, res, next) => {
    console.error('Error:', err.stack);

    res.status(err.status || 500).json({
        success: false,
        message: err.message || 'Internal Server Error',
        error: process.env.NODE_ENV === 'development' ? err : {},
    });
});

// Start server
const PORT = process.env.PORT || 5000;

app.listen(PORT, () => {
    console.log('');
    console.log('═══════════════════════════════════════════════════════');
    console.log('🚀 Attendanzy Backend Server');
    console.log('═══════════════════════════════════════════════════════');
    console.log(`📡 Server running on port: ${PORT}`);
    console.log(`🌍 Environment: ${process.env.NODE_ENV || 'development'}`);
    console.log(`🔗 API URL: http://localhost:${PORT}`);
    console.log(`💚 Health Check: http://localhost:${PORT}/api/health`);
    console.log('═══════════════════════════════════════════════════════');
    console.log('');
    console.log('Available Endpoints:');
    console.log('  POST   /api/auth/login');
    console.log('  POST   /api/auth/change-password');
    console.log('  GET    /api/auth/profile');
    console.log('  POST   /api/od-requests');
    console.log('  GET    /api/od-requests/student/:email');
    console.log('  GET    /api/od-requests/staff');
    console.log('  GET    /api/od-requests/hod');
    console.log('  POST   /api/leave-requests');
    console.log('  GET    /api/leave-requests/student/:email');
    console.log('  GET    /api/leave-requests/staff');
    console.log('  GET    /api/leave-requests/hod');
    console.log('═══════════════════════════════════════════════════════');
    console.log('');
});

// Handle unhandled promise rejections
process.on('unhandledRejection', (err) => {
    console.error('❌ Unhandled Promise Rejection:', err);
    // Close server & exit process
    process.exit(1);
});
