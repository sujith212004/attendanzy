const { Pool } = require('pg');

const pool = new Pool({
    host: 'localhost',
    user: 'tanzy',
    password: 'tanzy123',
    database: 'postgres',
    port: 5432,
});

module.exports = {
    query: (text, params) => pool.query(text, params),
    pool,
};
