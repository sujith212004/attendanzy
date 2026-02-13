const ODRequest = require('../models/ODRequest');
const { notifyStaffOnNewRequest, notifyHODOnForward, notifyStudentOnStatusChange, notifyStaffOnHODDecision } = require('../services/notificationService');

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

        // Send notification to staff
        try {
            await notifyStaffOnNewRequest(odRequest, 'OD');
        } catch (notifError) {
            console.error('Notification error:', notifError);
        }

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
            requests: requests,
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

        // Save staff details for history/display
        if (staffName) odRequest.staffName = staffName;
        if (inchargeName) odRequest.forwardedByIncharge = inchargeName;

        if (dbStatus === 'rejected') {
            odRequest.status = 'rejected';
            odRequest.rejectedBy = 'staff';
            if (rejectionReason) {
                odRequest.rejectionReason = rejectionReason;
                odRequest.staffRemarks = rejectionReason; // Keep both for safety
            }

            // Notify student about rejection
            try {
                await notifyStudentOnStatusChange(odRequest, 'OD', 'rejected', 'staff');
            } catch (notifError) {
                console.error('Student rejection notification error:', notifError);
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
            // IMPORTANT: Status remains 'pending' overall until HOD approves
            odRequest.status = 'pending';

            // Notify HOD about forwarded request
            try {
                await notifyHODOnForward(odRequest, 'OD');
            } catch (notifError) {
                console.error('HOD notification error:', notifError);
            }

            // Notify student that request is forwarded
            try {
                await notifyStudentOnStatusChange(odRequest, 'OD', 'forwarded', 'staff');
            } catch (notifError) {
                console.error('Student notification error:', notifError);
            }
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

        console.log(`\n========== HOD STATUS UPDATE START ==========`);
        console.log(`Request ID: ${id}`);
        console.log(`New Status: ${status}`);
        console.log(`Remarks: ${remarks || 'None'}`);

        if (!status || !['approved', 'rejected'].includes(status)) {
            console.error(`❌ Invalid status provided: ${status}`);
            console.log(`========== HOD STATUS UPDATE END ==========\n`);
            return res.status(400).json({
                success: false,
                message: 'Invalid status. Must be "approved" or "rejected"',
            });
        }

        const odRequest = await ODRequest.findById(id);

        if (!odRequest) {
            console.error(`❌ OD request not found: ${id}`);
            console.log(`========== HOD STATUS UPDATE END ==========\n`);
            return res.status(404).json({
                success: false,
                message: 'OD request not found',
            });
        }

        console.log(`Found OD Request for student: ${odRequest.studentEmail}`);
        console.log(`Current staffStatus: ${odRequest.staffStatus}`);
        console.log(`Current hodStatus: ${odRequest.hodStatus}`);

        if (odRequest.staffStatus !== 'approved') {
            console.error(`❌ Request not approved by staff yet`);
            console.log(`========== HOD STATUS UPDATE END ==========\n`);
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
            console.log(`✅ Setting overall status to 'accepted'`);
        } else {
            odRequest.status = 'rejected';
            console.log(`❌ Setting overall status to 'rejected'`);
        }

        await odRequest.save();
        console.log(`✅ OD request updated in database`);

        // Notify student about HOD decision
        console.log(`\nAttempting to notify student about HOD decision...`);
        try {
            const notificationResult = await notifyStudentOnStatusChange(odRequest, 'OD', status, 'hod');
            if (notificationResult.success) {
                console.log(`✅ Student notification sent successfully`);
            } else {
                console.error(`❌ Student notification failed: ${notificationResult.message || notificationResult.error}`);
            }
        } catch (notifError) {
            console.error('❌ Student HOD notification error:', notifError);
        }

        console.log(`========== HOD STATUS UPDATE END ==========\n`);

        res.status(200).json({
            success: true,
            message: `OD request ${status} by HOD`,
            data: odRequest,
        });

    } catch (error) {
        console.error('❌ Update HOD status error:', error);
        console.log(`========== HOD STATUS UPDATE END ==========\n`);
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

// Delete OD request
exports.deleteODRequest = async (req, res) => {
    try {
        const { id } = req.params;

        const odRequest = await ODRequest.findByIdAndDelete(id);

        if (!odRequest) {
            return res.status(404).json({
                success: false,
                message: 'OD request not found',
            });
        }

        res.status(200).json({
            success: true,
            message: 'OD request deleted successfully',
        });

    } catch (error) {
        console.error('Delete OD request error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to delete OD request',
            error: error.message,
        });
    }
};

// Update OD request (edit)
exports.updateODRequest = async (req, res) => {
    try {
        const { id } = req.params;
        const updateData = req.body;

        // Don't allow editing if already processed
        const existing = await ODRequest.findById(id);
        if (!existing) {
            return res.status(404).json({
                success: false,
                message: 'OD request not found',
            });
        }

        if (existing.status !== 'pending' && existing.staffStatus !== 'pending') {
            return res.status(400).json({
                success: false,
                message: 'Cannot edit a processed OD request',
            });
        }

        // Update allowed fields
        const allowedUpdates = ['subject', 'content', 'from', 'to', 'image'];
        const updates = {};
        allowedUpdates.forEach(field => {
            if (updateData[field] !== undefined) {
                updates[field] = updateData[field];
            }
        });
        updates.updatedAt = new Date().toISOString();

        const odRequest = await ODRequest.findByIdAndUpdate(
            id,
            updates,
            { new: true }
        );

        res.status(200).json({
            success: true,
            message: 'OD request updated successfully',
            data: odRequest,
        });

    } catch (error) {
        console.error('Update OD request error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to update OD request',
            error: error.message,
        });
    }
};
