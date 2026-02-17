const mongoose = require('mongoose');
const Staff = require('./models/Staff');
const HOD = require('./models/HOD');
require('dotenv').config();

async function updateStaffAndHODWithYearSec() {
    try {
        await mongoose.connect(process.env.MONGO_URI);
        console.log('Connected to MongoDB');

        // You'll need to update these values based on your actual data
        // This is just an example - you should customize it for each user

        console.log('\n=== UPDATING STAFF DOCUMENTS ===');
        const staffDocs = await Staff.find({});
        console.log(`Found ${staffDocs.length} staff documents`);

        for (const staff of staffDocs) {
            // Only update if year and sec are not already set
            if (!staff.year || !staff.sec) {
                // You need to set the correct year and section for each staff member
                // For now, I'm setting default values - YOU MUST CHANGE THESE
                staff.year = '4th Year'; // Change this!
                staff.sec = 'A';         // Change this!
                await staff.save();
                console.log(`Updated staff: ${staff.name || staff.Name}`);
            }
        }

        console.log('\n=== UPDATING HOD DOCUMENTS ===');
        const hodDocs = await HOD.find({});
        console.log(`Found ${hodDocs.length} HOD documents`);

        for (const hod of hodDocs) {
            // Only update if year and sec are not already set
            if (!hod.year || !hod.sec) {
                // You need to set the correct year and section for each HOD
                // For now, I'm setting default values - YOU MUST CHANGE THESE
                hod.year = '4th Year'; // Change this!
                hod.sec = 'A';         // Change this!
                await hod.save();
                console.log(`Updated HOD: ${hod.name || hod.Name}`);
            }
        }

        console.log('\n=== UPDATE COMPLETE ===');
        await mongoose.disconnect();
        console.log('Disconnected from MongoDB');
    } catch (error) {
        console.error('Error:', error);
        process.exit(1);
    }
}

updateStaffAndHODWithYearSec();
