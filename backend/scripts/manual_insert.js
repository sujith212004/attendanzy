const { Client } = require('pg');

const client = new Client({
    host: 'localhost',
    user: 'tanzy',
    password: 'tanzy123',
    database: 'postgres',
    port: 5432,
});

async function run() {
    try {
        await client.connect();
        console.log('Connected');

        // CSE 2 A
        await client.query(`
        CREATE TABLE IF NOT EXISTS cse_2_a (
            id SERIAL PRIMARY KEY,
            name VARCHAR(100),
            email VARCHAR(100) UNIQUE,
            college_email VARCHAR(100),
            password VARCHAR(100),
            department VARCHAR(50) DEFAULT 'CSE',
            year VARCHAR(10) DEFAULT '2',
            sec VARCHAR(10) DEFAULT 'A',
            roll_number VARCHAR(20)
        );
    `);
        await client.query(`
        INSERT INTO cse_2_a (name, email, password, department, year, sec, roll_number)
        VALUES ('Test Student', 'student@test.com', 'password123', 'CSE', '2', 'A', 'CSE2A001')
        ON CONFLICT (email) DO NOTHING;
    `);
        console.log('Inserted Student');

        // Staff
        await client.query(`
        CREATE TABLE IF NOT EXISTS staff (
            id SERIAL PRIMARY KEY,
            name VARCHAR(100),
            email VARCHAR(100) UNIQUE,
            college_email VARCHAR(100),
            password VARCHAR(100),
            department VARCHAR(50),
            incharge_name VARCHAR(100)
        );
    `);
        await client.query(`
        INSERT INTO staff (name, email, password, department, incharge_name)
        VALUES ('Test Staff', 'staff@test.com', 'password123', 'CSE', 'Class Incharge')
        ON CONFLICT (email) DO NOTHING;
    `);
        console.log('Inserted Staff');

        // HOD
        await client.query(`
        CREATE TABLE IF NOT EXISTS hod (
            id SERIAL PRIMARY KEY,
            name VARCHAR(100),
            email VARCHAR(100) UNIQUE,
            college_email VARCHAR(100),
            password VARCHAR(100),
            department VARCHAR(50)
        );
    `);
        await client.query(`
        INSERT INTO hod (name, email, password, department)
        VALUES ('Test HOD', 'hod@test.com', 'password123', 'CSE')
        ON CONFLICT (email) DO NOTHING;
    `);
        console.log('Inserted HOD');

    } catch (e) {
        console.error(e);
    } finally {
        await client.end();
        console.log('Disconnected');
    }
}

run();
