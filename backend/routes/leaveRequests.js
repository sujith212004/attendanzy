const express = require('express');
const router = express.Router();
const leaveRequestController = require('../controllers/leaveRequestController');

// @route   POST /api/leave-requests
// @desc    Submit leave request
// @access  Public (Student)
router.post('/', leaveRequestController.submitLeaveRequest);

// @route   GET /api/leave-requests/student/:email
// @desc    Get student's leave requests
// @access  Public (Student)
router.get('/student/:email', leaveRequestController.getStudentLeaveRequests);

// @route   GET /api/leave-requests/staff
// @desc    Get leave requests for staff review
// @access  Public (Staff)
router.get('/staff', leaveRequestController.getStaffLeaveRequests);

// @route   GET /api/leave-requests/hod
// @desc    Get leave requests for HOD review
// @access  Public (HOD)
router.get('/hod', leaveRequestController.getHODLeaveRequests);

// @route   GET /api/leave-requests/all
// @desc    Get all leave requests with filters
// @access  Public (Admin/HOD)
router.get('/all', leaveRequestController.getAllLeaveRequests);

// @route   PUT /api/leave-requests/:id/staff-status
// @desc    Update staff status
// @access  Public (Staff)
router.put('/:id/staff-status', leaveRequestController.updateStaffStatus);

// @route   PUT /api/leave-requests/:id/hod-status
// @desc    Update HOD status
// @access  Public (HOD)
router.put('/:id/hod-status', leaveRequestController.updateHODStatus);

// @route   GET /api/leave-requests/:id
// @desc    Get single leave request
// @access  Public
router.get('/:id', leaveRequestController.getLeaveRequest);

module.exports = router;
