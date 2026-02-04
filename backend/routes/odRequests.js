const express = require('express');
const router = express.Router();
const odRequestController = require('../controllers/odRequestController');

// @route   POST /api/od-requests
// @desc    Submit OD request
// @access  Public (Student)
router.post('/', odRequestController.submitODRequest);

// @route   GET /api/od-requests/student/:email
// @desc    Get student's OD requests
// @access  Public (Student)
router.get('/student/:email', odRequestController.getStudentODRequests);

// @route   GET /api/od-requests/staff
// @desc    Get OD requests for staff review
// @access  Public (Staff)
router.get('/staff', odRequestController.getStaffODRequests);

// @route   GET /api/od-requests/hod
// @desc    Get OD requests for HOD review
// @access  Public (HOD)
router.get('/hod', odRequestController.getHODODRequests);

// @route   GET /api/od-requests/all
// @desc    Get all OD requests with filters
// @access  Public (Admin/HOD)
router.get('/all', odRequestController.getAllODRequests);

// @route   PUT /api/od-requests/:id/staff-status
// @desc    Update staff status
// @access  Public (Staff)
router.put('/:id/staff-status', odRequestController.updateStaffStatus);

// @route   PUT /api/od-requests/:id/hod-status
// @desc    Update HOD status
// @access  Public (HOD)
router.put('/:id/hod-status', odRequestController.updateHODStatus);

// @route   GET /api/od-requests/:id
// @desc    Get single OD request
// @access  Public
router.get('/:id', odRequestController.getODRequest);

module.exports = router;
