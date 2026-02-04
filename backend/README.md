# Attendanzy Backend Server

Backend API server for the Attendanzy Attendance Management System built with Node.js, Express, and MongoDB.

## Features

- 🔐 **Authentication**: Login system for Users, Staff, and HOD
- 📝 **OD Request Management**: Submit, review, and approve OD requests
- 🏥 **Leave Request Management**: Submit, review, and approve leave requests (max 2 days)
- 👥 **Role-based Access**: Different endpoints for Students, Staff, and HOD
- 📸 **Image Upload**: Support for proof documents and medical certificates (Base64)
- ✅ **Approval Workflow**: Two-level approval (Staff → HOD)

## Installation

1. Navigate to the backend directory:
```bash
cd backend
```

2. Install dependencies:
```bash
npm install
```

3. Configure environment variables:
   - Copy `.env` file and update if needed
   - Default MongoDB URI is already configured

4. Start the server:
```bash
# Development mode with auto-reload
npm run dev

# Production mode
npm start
```

The server will run on `http://localhost:5000`

## API Endpoints

### Authentication
- `POST /api/auth/login` - Login (User/Staff/HOD)
- `POST /api/auth/change-password` - Change password
- `GET /api/auth/profile` - Get user profile

### OD Requests
- `POST /api/od-requests` - Submit OD request
- `GET /api/od-requests/student/:email` - Get student's OD requests
- `GET /api/od-requests/staff` - Get pending OD requests for staff
- `GET /api/od-requests/hod` - Get pending OD requests for HOD
- `GET /api/od-requests/all` - Get all OD requests (with filters)
- `PUT /api/od-requests/:id/staff-status` - Update staff approval status
- `PUT /api/od-requests/:id/hod-status` - Update HOD approval status
- `GET /api/od-requests/:id` - Get single OD request

### Leave Requests
- `POST /api/leave-requests` - Submit leave request
- `GET /api/leave-requests/student/:email` - Get student's leave requests
- `GET /api/leave-requests/staff` - Get pending leave requests for staff
- `GET /api/leave-requests/hod` - Get pending leave requests for HOD
- `GET /api/leave-requests/all` - Get all leave requests (with filters)
- `PUT /api/leave-requests/:id/staff-status` - Update staff approval status
- `PUT /api/leave-requests/:id/hod-status` - Update HOD approval status
- `GET /api/leave-requests/:id` - Get single leave request

### Health Check
- `GET /api/health` - Server health status

## Project Structure

```
backend/
├── config/
│   └── database.js          # MongoDB connection
├── controllers/
│   ├── authController.js    # Authentication logic
│   ├── odRequestController.js
│   └── leaveRequestController.js
├── models/
│   ├── User.js              # Student model
│   ├── Staff.js             # Staff model
│   ├── HOD.js               # HOD model
│   ├── ODRequest.js         # OD Request model
│   └── LeaveRequest.js      # Leave Request model
├── routes/
│   ├── auth.js              # Auth routes
│   ├── odRequests.js        # OD request routes
│   └── leaveRequests.js     # Leave request routes
├── .env                     # Environment variables
├── .gitignore
├── package.json
├── server.js                # Main server file
└── README.md
```

## Environment Variables

```env
NODE_ENV=development
PORT=5000
MONGODB_URI=your_mongodb_connection_string
JWT_SECRET=your_jwt_secret
JWT_EXPIRE=7d
MAX_FILE_SIZE=5242880
```

## Usage Examples

### Login Request
```bash
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "student@example.com",
    "password": "password123",
    "role": "user",
    "department": "Computer Science"
  }'
```

### Submit OD Request
```bash
curl -X POST http://localhost:5000/api/od-requests \
  -H "Content-Type: application/json" \
  -d '{
    "studentName": "John Doe",
    "studentEmail": "john@example.com",
    "from": "John Doe (CSE, 3-A)",
    "to": "HOD, Computer Science",
    "subject": "OD Request for Hackathon",
    "content": "Request for OD to attend hackathon...",
    "department": "Computer Science",
    "year": "3",
    "section": "A",
    "image": "base64_encoded_image_string"
  }'
```

### Submit Leave Request
```bash
curl -X POST http://localhost:5000/api/leave-requests \
  -H "Content-Type: application/json" \
  -d '{
    "studentName": "John Doe",
    "studentEmail": "john@example.com",
    "from": "John Doe (CSE, 3-A)",
    "to": "HOD, Computer Science",
    "subject": "Sick Leave",
    "content": "Request for sick leave...",
    "leaveType": "Sick Leave",
    "fromDate": "2026-02-01",
    "toDate": "2026-02-02",
    "duration": 2,
    "department": "Computer Science",
    "year": "3",
    "section": "A",
    "image": "base64_encoded_medical_certificate"
  }'
```

## Next Steps

To integrate this backend with your Flutter app:

1. Update Flutter app to use HTTP requests instead of direct MongoDB
2. Replace `mongo_dart` package with `http` or `dio` package
3. Update all database operations to API calls
4. Store user session data locally (SharedPreferences)
5. Handle API responses and errors appropriately

## License

ISC
