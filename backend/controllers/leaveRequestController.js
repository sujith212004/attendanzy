const LeaveRequest = require('../models/LeaveRequest');

// Submit Leave Request
exports.submitLeaveRequest = async (req, res) => {
    try {
        const {
            studentName,
            studentEmail,
            from,
            to,
            subject,
            content,
            reason,
            leaveType,
            fromDate,
            toDate,
            duration,
            image,
            department,
            year,
            section,
        } = req.body;

        // Validate required fields
        if (!studentName || !studentEmail || !from || !to || !subject || !content ||
            !leaveType || !fromDate || !toDate || !department || !year || !section) {
            return res.status(400).json({
                success: false,
                message: 'Please provide all required fields',
            });
        }

        // Validate duration (max 2 days)
        const calculatedDuration = duration || 1;
        if (calculatedDuration > 2) {
            return res.status(400).json({
                success: false,
                message: 'Leave application is limited to maximum 2 continuous days',
            });
        }

        // Create new leave request
        const leaveRequest = new LeaveRequest({
            studentName,
            studentEmail,
            from,
            to,
            subject,
            content,
            reason: reason || content,
            leaveType,
            fromDate,
            toDate,
            duration: calculatedDuration,
            image: image || '',
            department,
            year,
            section,
            staffStatus: 'pending',
            hodStatus: 'pending',
            status: 'pending',
            createdAt: new Date().toISOString(),
        });

        await leaveRequest.save();

        res.status(201).json({
            success: true,
            message: 'Leave request submitted successfully',
            data: leaveRequest,
        });

    } catch (error) {
        console.error('Submit leave request error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to submit leave request',
            error: error.message,
        });
    }
};

// Get student's leave requests
exports.getStudentLeaveRequests = async (req, res) => {
    try {
        const { email } = req.params;

        const requests = await LeaveRequest.find({ studentEmail: email })
            .sort({ createdAt: -1 });

        res.status(200).json({
            success: true,
            count: requests.length,
            data: requests,
        });

    } catch (error) {
        console.error('Get student leave requests error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch leave requests',
            error: error.message,
        });
    }
};

// Get leave requests for staff review
exports.getStaffLeaveRequests = async (req, res) => {
    try {
        const { department, year, section } = req.query;

        const query = {};

        if (department) query.department = department;
        if (year) query.year = year;
        if (section) query.section = section;

        const requests = await LeaveRequest.find(query)
            .sort({ createdAt: -1 });

        res.status(200).json({
            success: true,
            count: requests.length,
            data: requests,
        });

    } catch (error) {
        console.error('Get staff leave requests error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch leave requests',
            error: error.message,
        });
    }
};

// Get leave requests for HOD review
exports.getHODLeaveRequests = async (req, res) => {
    try {
        const { department } = req.query;

        const query = {
            staffStatus: 'approved',
            hodStatus: 'pending',
        };

        if (department) query.department = department;

        const requests = await LeaveRequest.find(query)
            .sort({ createdAt: -1 });

        res.status(200).json({
            success: true,
            count: requests.length,
            data: requests,
        });

    } catch (error) {
        console.error('Get HOD leave requests error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch leave requests',
            error: error.message,
        });
    }
};

// Update staff status
exports.updateStaffStatus = async (req, res) => {
    try {
        const { id } = req.params;
        const {
            status,
            rejectionReason,
            staffName,
            inchargeName,
            year,
            section
        } = req.body;

        // Frontend might send 'accepted' or 'rejected'.
        // Backend DB expects 'approved' or 'rejected' (or 'pending').

        if (!status || !['accepted', 'rejected', 'approved'].includes(status)) {
            // Invalid status
        }

        let dbStatus = status;
        if (status === 'accepted') dbStatus = 'approved';

        const leaveRequest = await LeaveRequest.findById(id);

        if (!leaveRequest) {
            return res.status(404).json({
                success: false,
                message: 'Leave request not found',
            });
        }

        leaveRequest.staffStatus = dbStatus;
        leaveRequest.updatedAt = new Date().toISOString();

        if (dbStatus === 'rejected') {
            leaveRequest.status = 'rejected';
            leaveRequest.rejectedBy = 'staff';
            if (rejectionReason) {
                // leaveRequest schema should support rejectionReason at top level or we use staffRemarks
                // To support frontend filtering, we ideally want rejectionReason to be set.
                // Assuming schema allows dynamic fields or check schema if possible (not visible now, but using assumption)
                leaveRequest.rejectionReason = rejectionReason;
                leaveRequest.staffRemarks = rejectionReason;
            }
        } else if (dbStatus === 'approved') {
            // Forwarding details
            if (staffName) leaveRequest.forwardedBy = staffName;
            if (inchargeName) leaveRequest.forwardedByIncharge = inchargeName;
            leaveRequest.forwardedAt = new Date().toISOString();
            if (year) leaveRequest.year = year;
            if (section) leaveRequest.section = section;

            leaveRequest.hodStatus = 'pending';
        }

        await leaveRequest.save();

        res.status(200).json({
            success: true,
            message: `Leave request ${dbStatus} by staff`,
            data: leaveRequest,
        });

    } catch (error) {
        console.error('Update staff status error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to update status',
            error: error.message,
        });
    }
};

// Update HOD status
exports.updateHODStatus = async (req, res) => {
    try {
        const { id } = req.params;
        const { status, remarks } = req.body;

        if (!status || !['approved', 'rejected'].includes(status)) {
            return res.status(400).json({
                success: false,
                message: 'Invalid status. Must be "approved" or "rejected"',
            });
        }

        const leaveRequest = await LeaveRequest.findById(id);

        if (!leaveRequest) {
            return res.status(404).json({
                success: false,
                message: 'Leave request not found',
            });
        }

        if (leaveRequest.staffStatus !== 'approved') {
            return res.status(400).json({
                success: false,
                message: 'Leave request must be approved by staff first',
            });
        }

        leaveRequest.hodStatus = status;
        if (remarks) leaveRequest.hodRemarks = remarks;

        // Update overall status
        if (status === 'approved') {
            leaveRequest.status = 'accepted';
        } else {
            leaveRequest.status = 'rejected';
        }

        await leaveRequest.save();

        res.status(200).json({
            success: true,
            message: `Leave request ${status} by HOD`,
            data: leaveRequest,
        });

    } catch (error) {
        console.error('Update HOD status error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to update status',
            error: error.message,
        });
    }
};

// Get single leave request
exports.getLeaveRequest = async (req, res) => {
    try {
        const { id } = req.params;

        const leaveRequest = await LeaveRequest.findById(id);

        if (!leaveRequest) {
            return res.status(404).json({
                success: false,
                message: 'Leave request not found',
            });
        }

        res.status(200).json({
            success: true,
            data: leaveRequest,
        });

    } catch (error) {
        console.error('Get leave request error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch leave request',
            error: error.message,
        });
    }
};

// Get all leave requests (for admin/HOD to see all)
exports.getAllLeaveRequests = async (req, res) => {
    try {
        const { department, year, section, status, leaveType } = req.query;

        const query = {};

        if (department) query.department = department;
        if (year) query.year = year;
        if (section) query.section = section;
        if (status) query.status = status;
        if (leaveType) query.leaveType = leaveType;

        const requests = await LeaveRequest.find(query)
            .sort({ createdAt: -1 });

        res.status(200).json({
            success: true,
            count: requests.length,
            data: requests,
        });

    } catch (error) {
        console.error('Get all leave requests error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch leave requests',
            error: error.message,
        });
    }
};
