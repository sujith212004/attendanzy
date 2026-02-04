const ODRequest = require('../models/ODRequest');

// Submit OD Request
exports.submitODRequest = async (req, res) => {
    try {
        const {
            studentName,
            studentEmail,
            from,
            to,
            subject,
            content,
            image,
            department,
            year,
            section,
        } = req.body;

        // Validate required fields
        if (!studentName || !studentEmail || !from || !to || !subject || !content || !department || !year || !section) {
            return res.status(400).json({
                success: false,
                message: 'Please provide all required fields',
            });
        }

        // Create new OD request
        const odRequest = new ODRequest({
            studentName,
            studentEmail,
            from,
            to,
            subject,
            content,
            image: image || '',
            department,
            year,
            section,
            staffStatus: 'pending',
            hodStatus: 'pending',
            status: 'pending',
            createdAt: new Date().toISOString(),
        });

        await odRequest.save();

        res.status(201).json({
            success: true,
            message: 'OD request submitted successfully',
            data: odRequest,
        });

    } catch (error) {
        console.error('Submit OD request error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to submit OD request',
            error: error.message,
        });
    }
};

// Get student's OD requests
exports.getStudentODRequests = async (req, res) => {
    try {
        const { email } = req.params;

        const requests = await ODRequest.find({ studentEmail: email })
            .sort({ createdAt: -1 });

        res.status(200).json({
            success: true,
            count: requests.length,
            data: requests,
        });

    } catch (error) {
        console.error('Get student OD requests error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch OD requests',
            error: error.message,
        });
    }
};

// Get OD requests for staff review
exports.getStaffODRequests = async (req, res) => {
    try {
        const { department, year, section } = req.query;

        const query = {};

        if (department) query.department = department;
        if (year) query.year = year;
        if (section) query.section = section;

        const requests = await ODRequest.find(query)
            .sort({ createdAt: -1 });

        res.status(200).json({
            success: true,
            count: requests.length,
            data: requests,
        });

    } catch (error) {
        console.error('Get staff OD requests error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch OD requests',
            error: error.message,
        });
    }
};

// Get OD requests for HOD review
exports.getHODODRequests = async (req, res) => {
    try {
        const { department } = req.query;

        const query = {
            staffStatus: 'approved',
            hodStatus: 'pending',
        };

        if (department) query.department = department;

        const requests = await ODRequest.find(query)
            .sort({ createdAt: -1 });

        res.status(200).json({
            success: true,
            count: requests.length,
            data: requests,
        });

    } catch (error) {
        console.error('Get HOD OD requests error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch OD requests',
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

        if (!status || !['accepted', 'rejected', 'approved'].includes(status)) {
            // Accommodate 'accepted' as alias for 'approved' if needed, or strictly enforce.
            // Frontend sends 'accepted' or 'rejected'.
            // But let's check what frontend sends.
            // Frontend sends "accepted" or "rejected".
            // Backend previous check was ['approved', 'rejected']
        }

        // Normalize status: frontend sends 'accepted', backend expects 'accepted' or 'approved'?
        // The ODRequest schema has staffStatus enum: ['pending', 'approved', 'rejected']
        // Wait, schema says 'approved', but frontend uses 'accepted'.
        // I should map 'accepted' to 'approved' or update schema.
        // Let's stick to what schema has.
        // Frontend sends "accepted" (line 1312)
        // Schema (viewed earlier): enum: ['pending', 'approved', 'rejected']
        // So I should convert 'accepted' to 'approved'.

        let dbStatus = status;
        if (status === 'accepted') dbStatus = 'approved';

        const odRequest = await ODRequest.findById(id);

        if (!odRequest) {
            return res.status(404).json({
                success: false,
                message: 'OD request not found',
            });
        }

        odRequest.staffStatus = dbStatus;
        odRequest.updatedAt = new Date().toISOString();

        if (dbStatus === 'rejected') {
            odRequest.status = 'rejected';
            odRequest.rejectedBy = 'staff';
            if (rejectionReason) {
                odRequest.rejectionReason = rejectionReason;
                odRequest.staffRemarks = rejectionReason; // Keep both for safety
            }
        } else if (dbStatus === 'approved') {
            // Forwarding details
            if (staffName) odRequest.forwardedBy = staffName;
            if (inchargeName) odRequest.forwardedByIncharge = inchargeName;
            odRequest.forwardedAt = new Date().toISOString();
            // Note: year and section are usually student's, but if staff updates them:
            if (year) odRequest.year = year;
            if (section) odRequest.section = section;

            // Set HOD status to pending so it shows up for HOD
            odRequest.hodStatus = 'pending';
            // Status remains 'pending' overall until HOD approves (becomes 'accepted')
        }

        await odRequest.save();

        res.status(200).json({
            success: true,
            message: `OD request ${dbStatus} by staff`,
            data: odRequest,
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

        const odRequest = await ODRequest.findById(id);

        if (!odRequest) {
            return res.status(404).json({
                success: false,
                message: 'OD request not found',
            });
        }

        if (odRequest.staffStatus !== 'approved') {
            return res.status(400).json({
                success: false,
                message: 'OD request must be approved by staff first',
            });
        }

        odRequest.hodStatus = status;
        if (remarks) odRequest.hodRemarks = remarks;

        // Update overall status
        if (status === 'approved') {
            odRequest.status = 'accepted';
        } else {
            odRequest.status = 'rejected';
        }

        await odRequest.save();

        res.status(200).json({
            success: true,
            message: `OD request ${status} by HOD`,
            data: odRequest,
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

// Get single OD request
exports.getODRequest = async (req, res) => {
    try {
        const { id } = req.params;

        const odRequest = await ODRequest.findById(id);

        if (!odRequest) {
            return res.status(404).json({
                success: false,
                message: 'OD request not found',
            });
        }

        res.status(200).json({
            success: true,
            data: odRequest,
        });

    } catch (error) {
        console.error('Get OD request error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch OD request',
            error: error.message,
        });
    }
};

// Get all OD requests (for admin/HOD to see all)
exports.getAllODRequests = async (req, res) => {
    try {
        const { department, year, section, status } = req.query;

        const query = {};

        if (department) query.department = department;
        if (year) query.year = year;
        if (section) query.section = section;
        if (status) query.status = status;

        const requests = await ODRequest.find(query)
            .sort({ createdAt: -1 });

        res.status(200).json({
            success: true,
            count: requests.length,
            data: requests,
        });

    } catch (error) {
        console.error('Get all OD requests error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch OD requests',
            error: error.message,
        });
    }
};
