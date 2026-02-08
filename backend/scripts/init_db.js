const { pool } = require('../config/pg');

const createTableQuery = `
  CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    college_email VARCHAR(255),
    password VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL,
    department VARCHAR(100) NOT NULL,
    year VARCHAR(20),
    sec VARCHAR(20),
    roll_number VARCHAR(50),
    phone_number VARCHAR(20),
    incharge_name VARCHAR(255),
    fcm_token VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
  );
`;

const initDB = async () => {
    try {
        await pool.query(createTableQuery);
        console.log('✅ Users table created successfully');
        process.exit(0);
    } catch (err) {
        console.error('❌ Error creating table:', err);
        process.exit(1);
    }
};

initDB();
