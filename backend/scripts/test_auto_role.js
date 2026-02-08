const { pool } = require('../config/pg');
const authController = require('../controllers/authController');

// Mock Request and Response
const mockReq = (body, query) => ({ body: body || {}, query: query || {} });
const mockRes = () => {
    const res = {};
    res.status = (code) => {
        res.statusCode = code;
        return res;
    };
    res.json = (data) => {
        res.data = data;
        return res;
    };
    return res;
};

async function testAutoRoleDetection() {
    console.log('🔍 Testing AUTO ROLE DETECTION...\n');

    try {
        // Get real student from cse_2_a
        const studentResult = await pool.query('SELECT email, password, department FROM cse_2_a LIMIT 1');
        if (studentResult.rows.length > 0) {
            const student = studentResult.rows[0];
            console.log(`📚 Testing Student Login (NO ROLE PROVIDED):`);
            console.log(`   Email: ${student.email}`);
            console.log(`   Password: ${student.password}`);
            console.log(`   Department: ${student.department || 'Not provided'}`);

            const req = mockReq({
                email: student.email,
                password: student.password,
                // NO ROLE - system should detect it
                department: student.department
            });
            const res = mockRes();

            await authController.login(req, res);

            if (res.statusCode === 200 && res.data.success) {
                console.log(`   ✅ LOGIN SUCCESS`);
                console.log(`   🎯 Detected Role: ${res.data.user.role}`);
                console.log(`   📋 User Data:`, JSON.stringify(res.data.user, null, 2));
                console.log();
            } else {
                console.log(`   ❌ LOGIN FAILED: ${res.data.message}\n`);
            }
        }

        // Get real staff
        const staffResult = await pool.query('SELECT email, password, department FROM staff LIMIT 1');
        if (staffResult.rows.length > 0) {
            const staff = staffResult.rows[0];
            console.log(`👨‍🏫 Testing Staff Login (NO ROLE PROVIDED):`);
            console.log(`   Email: ${staff.email}`);
            console.log(`   Password: ${staff.password}`);
            console.log(`   Department: ${staff.department || 'Not provided'}`);

            const req = mockReq({
                email: staff.email,
                password: staff.password,
                // NO ROLE - system should detect it
                department: staff.department
            });
            const res = mockRes();

            await authController.login(req, res);

            if (res.statusCode === 200 && res.data.success) {
                console.log(`   ✅ LOGIN SUCCESS`);
                console.log(`   🎯 Detected Role: ${res.data.user.role}`);
                console.log(`   📋 User Data:`, JSON.stringify(res.data.user, null, 2));
                console.log();
            } else {
                console.log(`   ❌ LOGIN FAILED: ${res.data.message}\n`);
            }
        }

        // Get real HOD
        const hodResult = await pool.query('SELECT email, password, department FROM hod LIMIT 1');
        if (hodResult.rows.length > 0) {
            const hod = hodResult.rows[0];
            console.log(`👔 Testing HOD Login (NO ROLE PROVIDED):`);
            console.log(`   Email: ${hod.email}`);
            console.log(`   Password: ${hod.password}`);
            console.log(`   Department: ${hod.department || 'Not provided'}`);

            const req = mockReq({
                email: hod.email,
                password: hod.password,
                // NO ROLE - system should detect it
                department: hod.department
            });
            const res = mockRes();

            await authController.login(req, res);

            if (res.statusCode === 200 && res.data.success) {
                console.log(`   ✅ LOGIN SUCCESS`);
                console.log(`   🎯 Detected Role: ${res.data.user.role}`);
                console.log(`   📋 User Data:`, JSON.stringify(res.data.user, null, 2));
                console.log();
            } else {
                console.log(`   ❌ LOGIN FAILED: ${res.data.message}\n`);
            }
        }

    } catch (error) {
        console.error('❌ Test Error:', error.message);
    } finally {
        await pool.end();
        console.log('✅ Tests completed.');
        process.exit(0);
    }
}

testAutoRoleDetection();
