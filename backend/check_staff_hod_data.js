const mongoose = require('mongoose');
const Staff = require('./models/Staff');
const HOD = require('./models/HOD');
require('dotenv').config();

async function checkAndDisplayData() {
    try {
        await mongoose.connect(process.env.MONGO_URI);
        console.log('Connected to MongoDB');

        console.log('\n=== STAFF COLLECTION ===');
        const staffDocs = await Staff.find({}).limit(5);
        staffDocs.forEach((doc, index) => {
            console.log(`\nStaff ${index + 1}:`);
            console.log(`  Name: ${doc.name || doc.Name}`);
            console.log(`  Email: ${doc.email || doc['College Email']}`);
            console.log(`  Department: ${doc.department}`);
            console.log(`  Year: ${doc.year || 'NOT SET'}`);
            console.log(`  Sec: ${doc.sec || 'NOT SET'}`);
            console.log(`  Full Document:`, JSON.stringify(doc.toObject(), null, 2));
        });

        console.log('\n=== HOD COLLECTION ===');
        const hodDocs = await HOD.find({}).limit(5);
        hodDocs.forEach((doc, index) => {
            console.log(`\nHOD ${index + 1}:`);
            console.log(`  Name: ${doc.name || doc.Name}`);
            console.log(`  Email: ${doc.email || doc['College Email']}`);
            console.log(`  Department: ${doc.department}`);
            console.log(`  Year: ${doc.year || 'NOT SET'}`);
            console.log(`  Sec: ${doc.sec || 'NOT SET'}`);
            console.log(`  Full Document:`, JSON.stringify(doc.toObject(), null, 2));
        });

        await mongoose.disconnect();
        console.log('\nDisconnected from MongoDB');
    } catch (error) {
        console.error('Error:', error);
        process.exit(1);
    }
}

checkAndDisplayData();
