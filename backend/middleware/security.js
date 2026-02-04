const rateLimit = require('express-rate-limit');
const helmet = require('helmet');
const mongoSanitize = require('express-mongo-sanitize');
const xss = require('xss-clean');
const hpp = require('hpp');
const cors = require('cors');

/**
 * Security middleware configuration
 */
const securityMiddleware = {
    /**
     * Helmet - Sets various HTTP headers for security
     */
    helmet: () => helmet({
        contentSecurityPolicy: {
            directives: {
                defaultSrc: ["'self'"],
                styleSrc: ["'self'", "'unsafe-inline'"],
                scriptSrc: ["'self'"],
                imgSrc: ["'self'", "data:", "https:"],
                connectSrc: ["'self'"],
                fontSrc: ["'self'"],
                objectSrc: ["'none'"],
                mediaSrc: ["'self'"],
                frameSrc: ["'none'"],
            },
        },
        crossOriginEmbedderPolicy: false,
        crossOriginResourcePolicy: { policy: "cross-origin" },
        dnsPrefetchControl: { allow: false },
        frameguard: { action: 'deny' },
        hidePoweredBy: true,
        hsts: {
            maxAge: 31536000, // 1 year
            includeSubDomains: true,
            preload: true,
        },
        ieNoOpen: true,
        noSniff: true,
        originAgentCluster: true,
        permittedCrossDomainPolicies: { permittedPolicies: "none" },
        referrerPolicy: { policy: "strict-origin-when-cross-origin" },
        xssFilter: true,
    }),

    /**
     * Rate limiting to prevent brute force and DDoS attacks
     */
    rateLimiter: () => rateLimit({
        windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000, // 15 minutes
        max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 100, // Limit each IP to 100 requests per window
        message: {
            success: false,
            message: 'Too many requests from this IP, please try again later.',
        },
        standardHeaders: true,
        legacyHeaders: false,
        skip: (req) => {
            // Skip rate limiting for health checks
            return req.path === '/api/health';
        },
    }),

    /**
     * Strict rate limiter for authentication routes
     */
    authRateLimiter: () => rateLimit({
        windowMs: 60 * 60 * 1000, // 1 hour
        max: 10, // Limit each IP to 10 login attempts per hour
        message: {
            success: false,
            message: 'Too many login attempts, please try again after an hour.',
        },
        standardHeaders: true,
        legacyHeaders: false,
    }),

    /**
     * CORS configuration
     */
    cors: () => cors({
        origin: (origin, callback) => {
            const allowedOrigins = process.env.ALLOWED_ORIGINS
                ? process.env.ALLOWED_ORIGINS.split(',')
                : ['http://localhost:3000', 'http://10.0.2.2:5000'];
            
            // Allow requests with no origin (mobile apps, Postman, etc.)
            if (!origin || allowedOrigins.includes(origin) || process.env.NODE_ENV === 'development') {
                callback(null, true);
            } else {
                callback(new Error('Not allowed by CORS'));
            }
        },
        credentials: true,
        methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
        allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
        exposedHeaders: ['X-Total-Count', 'X-Page-Count'],
        maxAge: 86400, // 24 hours
    }),

    /**
     * Sanitize data to prevent NoSQL injection
     */
    mongoSanitize: () => mongoSanitize({
        replaceWith: '_',
        onSanitize: ({ req, key }) => {
            console.warn(`[SECURITY] NoSQL injection attempt detected in ${key}`);
        },
    }),

    /**
     * Prevent XSS attacks
     */
    xss: () => xss(),

    /**
     * Prevent HTTP Parameter Pollution
     */
    hpp: () => hpp({
        whitelist: [
            'status',
            'sort',
            'page',
            'limit',
        ],
    }),

    /**
     * Request size limiter
     */
    requestSizeLimiter: {
        json: { limit: '10mb' },
        urlencoded: { extended: true, limit: '10mb' },
    },

    /**
     * Security headers for API responses
     */
    securityHeaders: (req, res, next) => {
        // Remove sensitive headers
        res.removeHeader('X-Powered-By');
        
        // Add security headers
        res.setHeader('X-Content-Type-Options', 'nosniff');
        res.setHeader('X-Frame-Options', 'DENY');
        res.setHeader('X-XSS-Protection', '1; mode=block');
        res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
        res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, proxy-revalidate');
        res.setHeader('Pragma', 'no-cache');
        res.setHeader('Expires', '0');
        
        next();
    },

    /**
     * Input validation middleware
     */
    validateInput: (req, res, next) => {
        // Remove any __proto__ or constructor properties (prototype pollution prevention)
        const sanitizeObject = (obj) => {
            if (obj && typeof obj === 'object') {
                delete obj.__proto__;
                delete obj.constructor;
                delete obj.prototype;
                
                for (const key in obj) {
                    if (key === '__proto__' || key === 'constructor' || key === 'prototype') {
                        delete obj[key];
                    } else if (typeof obj[key] === 'object') {
                        sanitizeObject(obj[key]);
                    }
                }
            }
            return obj;
        };

        if (req.body) req.body = sanitizeObject(req.body);
        if (req.query) req.query = sanitizeObject(req.query);
        if (req.params) req.params = sanitizeObject(req.params);

        next();
    },

    /**
     * Request logging for security audit
     */
    auditLog: (req, res, next) => {
        const startTime = Date.now();
        
        res.on('finish', () => {
            const duration = Date.now() - startTime;
            const logData = {
                timestamp: new Date().toISOString(),
                method: req.method,
                path: req.path,
                statusCode: res.statusCode,
                duration: `${duration}ms`,
                ip: req.ip || req.connection.remoteAddress,
                userAgent: req.get('User-Agent'),
                userId: req.user?.id || 'anonymous',
            };

            // Log security-relevant events
            if (res.statusCode >= 400) {
                console.warn('[SECURITY AUDIT]', JSON.stringify(logData));
            } else if (req.path.includes('/auth/')) {
                console.info('[AUTH AUDIT]', JSON.stringify(logData));
            }
        });

        next();
    },
};

module.exports = securityMiddleware;
