# Staff Year & Section Update Script

This script updates staff records in the MongoDB database to assign them to specific years and sections, which is required for the staff OD and Leave request management features to work correctly.

## Problem

Staff members cannot see OD or Leave requests because their profiles are missing `year` and `sec` (section) field assignments in the database.

## Prerequisites

- Node.js installed
- MongoDB running and accessible
- MongoDB connection string

## Setup

1. **Set MongoDB Connection String**

   You can set the connection string in one of two ways:

   **Option A: Environment Variable (Recommended)**
   ```bash
   # Windows (PowerShell)
   $env:MONGODB_URI="mongodb://localhost:27017/attendanzy"
   
   # Windows (CMD)
   set MONGODB_URI=mongodb://localhost:27017/attendanzy
   
   # Linux/Mac
   export MONGODB_URI="mongodb://localhost:27017/attendanzy"
   ```

   **Option B: Edit the Script**
   
   Open `update-staff-year-section.js` and modify line 5:
   ```javascript
   const MONGODB_URI = 'mongodb://localhost:27017/attendanzy';
   ```

2. **Install Dependencies**

   The script uses `mongoose` which should already be installed in your backend. If not:
   ```bash
   cd backend
   npm install mongoose
   ```

## Usage

### Interactive Mode (Recommended)

This mode allows you to update each staff member one by one with prompts:

```bash
cd backend
node scripts/update-staff-year-section.js
```

**Example Session:**
```
╔════════════════════════════════════════════════════════════════╗
║         Staff Year & Section Update Script                    ║
╚════════════════════════════════════════════════════════════════╝

🔌 Connecting to MongoDB...
✅ Connected to MongoDB

📋 Found 3 staff member(s)

Current staff records:
────────────────────────────────────────────────────────────────────────────────
1. John Doe (john.doe@college.edu)
   Department: CSE
   Current Year: NOT SET, Section: NOT SET
────────────────────────────────────────────────────────────────────────────────
2. Jane Smith (jane.smith@college.edu)
   Department: ECE
   Current Year: II, Section: A
────────────────────────────────────────────────────────────────────────────────

👤 Staff: John Doe
   Current: Year=NOT SET, Section=NOT SET
   Update this staff member? (y/n): y
   Enter Year (e.g., I, II, III, IV): II
   Enter Section (e.g., A, B, C): A
   ✅ Updated: John Doe -> Year: II, Section: A

👤 Staff: Jane Smith
   Current: Year=II, Section=A
   Update this staff member? (y/n): n
   ⏭️  Skipped
```

### Batch Mode

For updating multiple staff members at once, edit the script and add your updates to the `updates` array (around line 120):

```javascript
const updates = [
  { email: 'john.doe@college.edu', year: 'II', section: 'A' },
  { email: 'jane.smith@college.edu', year: 'III', section: 'B' },
  { email: 'bob.johnson@college.edu', year: 'IV', section: 'C' },
];
```

Then run:
```bash
node scripts/update-staff-year-section.js --batch
```

## Year and Section Format

- **Year**: Use Roman numerals (I, II, III, IV) or any format that matches your student records
- **Section**: Use single letters (A, B, C, etc.) or any format that matches your student records

**Important:** The year and section values you assign to staff MUST match exactly with the year and section values in your student OD/Leave requests for the filtering to work correctly.

## Verification

After running the script, you can verify the updates in MongoDB:

### Using MongoDB Compass
1. Connect to your database
2. Navigate to the `Staff` collection
3. Check that staff records now have `year` and `sec` fields populated

### Using MongoDB Shell
```bash
mongosh
use attendanzy
db.Staff.find({}, {name: 1, email: 1, year: 1, sec: 1})
```

### Test in the Application
1. Login as a staff member whose profile was updated
2. Navigate to OD Request Management or Leave Request Management
3. You should now see requests from students in the assigned year and section
4. If you still see an error, check the debug info displayed in the error message

## Troubleshooting

### Error: "Cannot connect to MongoDB"
- Verify MongoDB is running
- Check your connection string is correct
- Ensure network connectivity to MongoDB server

### Error: "No staff members found"
- Verify you're connected to the correct database
- Check that the `Staff` collection exists and has documents

### Staff still can't see requests after update
1. **Verify year/section match**: The year and section assigned to staff must EXACTLY match the year and section in student requests
2. **Check student requests exist**: Verify there are actual OD/Leave requests in the database with matching year/section
3. **Clear app cache**: Have the staff member logout and login again to refresh their profile data
4. **Check debug logs**: The error screen shows debug info with the loaded year/section values

## Example: Complete Update Flow

```bash
# 1. Set connection string
$env:MONGODB_URI="mongodb://localhost:27017/attendanzy"

# 2. Navigate to backend directory
cd c:\Users\sujit\Documents\projects\Attendanzy\Attendanzy\backend

# 3. Run the script
node scripts/update-staff-year-section.js

# 4. Follow the prompts to update each staff member

# 5. Verify in MongoDB
mongosh
use attendanzy
db.Staff.find({}, {name: 1, year: 1, sec: 1})

# 6. Test in the application
# - Login as staff
# - Navigate to OD/Leave Management
# - Verify requests are displayed
```

## Notes

- The script uses `strict: false` in the Staff schema to allow flexible updates
- Existing year/section values are preserved if you skip updating a staff member
- The script shows a summary of all staff records before and after updates
- You can run the script multiple times safely - it will show current values and allow updates
