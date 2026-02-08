const { pool } = require('../config/pg');

const testDB = async () => {
    try {
        const res = await pool.query("SELECT to_regclass('public.users') as table_exists;");
        if (res.rows[0].table_exists) {
            console.log('✅ Connection successful. The "users" table exists.');

            // Count users
            const countRes = await pool.query('SELECT COUNT(*) FROM users');
            console.log(`ℹ️  Current user count: ${countRes.rows[0].count}`);
        } else {
            console.log('⚠️  Connection successful, but "users" table does NOT exist yet.');
        }
        process.exit(0);
    } catch (err) {
        console.error('❌ Database connection failed:', err.message);
        process.exit(1);
    }
};

testDB();
