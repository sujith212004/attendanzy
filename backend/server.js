require('dotenv').config();
const express = require('express');
const morgan = require('morgan');
const connectDB = require('./config/database');

// Security middleware
let security;
try {
    security = require('./middleware/security');
} catch (err) {
    console.warn('Security middleware not found, using basic security');
    security = null;
}

// Initialize express app
const app = express();

// Connect to MongoDB
connectDB();

// ============================================
// Security Middleware (Production)
// ============================================
if (security && process.env.NODE_ENV === 'production') {
    // Helmet for security headers
    app.use(security.helmet());
    
    // Rate limiting
    app.use(security.rateLimiter());
    
    // CORS with whitelist
    app.use(security.cors());
    
    // Prevent NoSQL injection
    app.use(security.mongoSanitize());
    
    // Prevent XSS attacks
    app.use(security.xss());
    
    // Prevent HTTP Parameter Pollution
    app.use(security.hpp());
    
    // Security headers
    app.use(security.securityHeaders);
    
    // Input validation
    app.use(security.validateInput);
    
    // Audit logging
    app.use(security.auditLog);
    
    console.log('🔒 Production security middleware enabled');
} else {
    // Development CORS - allow all origins
    const cors = require('cors');
    app.use(cors({
        origin: '*',
        credentials: true,
    }));
    console.log('⚠️  Development mode - relaxed security');
}

// Body parsers with size limits
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Logging middleware
if (process.env.NODE_ENV === 'development') {
    app.use(morgan('dev'));
} else {
    app.use(morgan('combined'));
}

// Routes
app.use('/api/auth', require('./routes/auth'));
app.use('/api/od-requests', require('./routes/odRequests'));
app.use('/api/leave-requests', require('./routes/leaveRequests'));
app.use('/api/notifications', require('./routes/notifications'));

// Health check route
app.get('/api/health', (req, res) => {
    res.status(200).json({
        success: true,
        message: 'Attendanzy Backend Server is running',
        timestamp: new Date().toISOString(),
    });
});

// Database status route
app.get('/api/db-status', (req, res) => {
    const mongoose = require('mongoose');
    const dbState = {
        0: 'disconnected',
        1: 'connected',
        2: 'connecting',
        3: 'disconnecting'
    };
    
    res.status(200).json({
        success: true,
        database: {
            state: dbState[mongoose.connection.readyState] || 'unknown',
            host: mongoose.connection.host || 'N/A',
            name: mongoose.connection.name || 'N/A',
        },
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
            notifications: '/api/notifications',
            health: '/api/health',
            dbStatus: '/api/db-status',
            testOD: '/api/od-requests/student/test@example.com (for testing)',
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
