const mongoose = require('mongoose');
const readline = require('readline');

// MongoDB connection string - update this with your actual connection string
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/attendanzy';

// Create readline interface for user input
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

// Promisify readline question
const question = (query) => new Promise((resolve) => rl.question(query, resolve));

// Staff Schema (minimal version for this script)
const staffSchema = new mongoose.Schema({
  name: String,
  Name: String,
  email: String,
  'College Email': String,
  department: String,
  year: String,
  sec: String,
}, {
  collection: 'Staff',
  strict: false
});

const Staff = mongoose.model('Staff', staffSchema);

async function updateStaffYearSection() {
  try {
    console.log('🔌 Connecting to MongoDB...');
    await mongoose.connect(MONGODB_URI);
    console.log('✅ Connected to MongoDB\n');

    // Fetch all staff members
    const staffMembers = await Staff.find({}).select('name Name email College\\ Email department year sec');
    
    if (staffMembers.length === 0) {
      console.log('⚠️  No staff members found in the database.');
      await cleanup();
      return;
    }

    console.log(`📋 Found ${staffMembers.length} staff member(s)\n`);
    console.log('Current staff records:');
    console.log('─'.repeat(80));
    
    staffMembers.forEach((staff, index) => {
      const name = staff.name || staff.Name || 'Unknown';
      const email = staff.email || staff['College Email'] || 'Unknown';
      const year = staff.year || 'NOT SET';
      const sec = staff.sec || 'NOT SET';
      
      console.log(`${index + 1}. ${name} (${email})`);
      console.log(`   Department: ${staff.department || 'Unknown'}`);
      console.log(`   Current Year: ${year}, Section: ${sec}`);
      console.log('─'.repeat(80));
    });

    console.log('\n📝 You can now update staff records with their assigned year and section.\n');

    // Interactive update for each staff member
    for (let i = 0; i < staffMembers.length; i++) {
      const staff = staffMembers[i];
      const name = staff.name || staff.Name || 'Unknown';
      const currentYear = staff.year || 'NOT SET';
      const currentSec = staff.sec || 'NOT SET';

      console.log(`\n👤 Staff: ${name}`);
      console.log(`   Current: Year=${currentYear}, Section=${currentSec}`);
      
      const shouldUpdate = await question('   Update this staff member? (y/n): ');
      
      if (shouldUpdate.toLowerCase() === 'y' || shouldUpdate.toLowerCase() === 'yes') {
        const year = await question('   Enter Year (e.g., I, II, III, IV): ');
        const section = await question('   Enter Section (e.g., A, B, C): ');
        
        if (year.trim() && section.trim()) {
          staff.year = year.trim();
          staff.sec = section.trim();
          await staff.save();
          console.log(`   ✅ Updated: ${name} -> Year: ${year.trim()}, Section: ${section.trim()}`);
        } else {
          console.log('   ⚠️  Skipped (empty year or section)');
        }
      } else {
        console.log('   ⏭️  Skipped');
      }
    }

    console.log('\n\n📊 Final Summary:');
    console.log('─'.repeat(80));
    const updatedStaff = await Staff.find({}).select('name Name year sec');
    updatedStaff.forEach((staff, index) => {
      const name = staff.name || staff.Name || 'Unknown';
      const year = staff.year || 'NOT SET';
      const sec = staff.sec || 'NOT SET';
      console.log(`${index + 1}. ${name}: Year=${year}, Section=${sec}`);
    });
    console.log('─'.repeat(80));

    await cleanup();

  } catch (error) {
    console.error('❌ Error:', error.message);
    await cleanup();
    process.exit(1);
  }
}

async function cleanup() {
  rl.close();
  await mongoose.connection.close();
  console.log('\n👋 Database connection closed.');
}

// Alternative: Batch update mode (non-interactive)
async function batchUpdateStaff(updates) {
  try {
    console.log('🔌 Connecting to MongoDB...');
    await mongoose.connect(MONGODB_URI);
    console.log('✅ Connected to MongoDB\n');

    console.log('📝 Batch updating staff records...\n');

    for (const update of updates) {
      const staff = await Staff.findOne({ 
        $or: [
          { email: update.email },
          { 'College Email': update.email }
        ]
      });

      if (staff) {
        staff.year = update.year;
        staff.sec = update.section;
        await staff.save();
        const name = staff.name || staff.Name || 'Unknown';
        console.log(`✅ Updated: ${name} (${update.email}) -> Year: ${update.year}, Section: ${update.section}`);
      } else {
        console.log(`⚠️  Staff not found: ${update.email}`);
      }
    }

    await mongoose.connection.close();
    console.log('\n👋 Database connection closed.');
    console.log('✅ Batch update completed!');

  } catch (error) {
    console.error('❌ Error:', error.message);
    await mongoose.connection.close();
    process.exit(1);
  }
}

// Check command line arguments
const args = process.argv.slice(2);

if (args.length > 0 && args[0] === '--batch') {
  // Example batch update format:
  // node update-staff-year-section.js --batch
  // Then modify the updates array below with your data
  
  const updates = [
    // { email: 'staff1@example.com', year: 'II', section: 'A' },
    // { email: 'staff2@example.com', year: 'III', section: 'B' },
    // Add more staff updates here
  ];

  if (updates.length === 0) {
    console.log('⚠️  No updates defined in batch mode.');
    console.log('Please edit the script and add staff updates to the "updates" array.');
    process.exit(0);
  }

  batchUpdateStaff(updates);
} else {
  // Interactive mode
  console.log('╔════════════════════════════════════════════════════════════════╗');
  console.log('║         Staff Year & Section Update Script                    ║');
  console.log('╚════════════════════════════════════════════════════════════════╝\n');
  console.log('This script will help you assign year and section to staff members.\n');
  
  updateStaffYearSection();
}
