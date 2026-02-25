const LeaveRequest = require('../models/LeaveRequest');
const { notifyStaffOnNewRequest, notifyHODOnForward, notifyStudentOnStatusChange, notifyStaffOnHODDecision } = require('../services/notificationService');
const QRCode = require('qrcode');
const PDFDocument = require('pdfkit');
const fs = require('fs');
const path = require('path');

/**
 * Helper to generate Secure Leave ID and PDF
 * @param {Object} leaveRequest - The Leave Request document
 * @returns {Promise<Object>} - { leaveId, pdfPath, verificationUrl }
 */
const generateLeavePDFHelper = async (leaveRequest) => {
    // Generate Secure Leave ID if not exists
    if (!leaveRequest.leaveId) {
        const timestamp = new Date();
        const dateStr = timestamp.toISOString().replace(/[-:T.Z]/g, "").substring(0, 8);
        const randomStr = Math.random().toString(36).substring(2, 5).toUpperCase();
        leaveRequest.leaveId = `ATZ-${dateStr}-${randomStr}`;
    }

    const leaveId = leaveRequest.leaveId;
    const baseUrl = process.env.RENDER_EXTERNAL_URL || `http://localhost:${process.env.PORT || 5000}`;
    const verificationUrl = `${baseUrl}/api/leave-requests/verify/${leaveId}`;
    leaveRequest.verificationUrl = verificationUrl;

    // Generate QR Code as Buffer (safer for PDFKit)
    console.log(`Generating QR Code for: ${verificationUrl}`);
    const qrBuffer = await QRCode.toBuffer(verificationUrl, {
        margin: 1,
        width: 200
    });

    // Create Letter Directory if not exists
    const lettersDir = path.join(__dirname, '../letters');
    if (!fs.existsSync(lettersDir)) {
        fs.mkdirSync(lettersDir, { recursive: true });
    }

    // Generate PDF
    const pdfPath = path.join(lettersDir, `${leaveId}.pdf`);
    const doc = new PDFDocument({ margin: 50 });
    const stream = fs.createWriteStream(pdfPath);
    doc.pipe(stream);

    // PDF Design System
    const accentColor = '#2ecc71'; // Green for Leave
    const textColor = '#1F2937';
    const logoPath = path.join(__dirname, '../assets/logo.jpg');

    // Header (Agni College of Technology Branding)
    if (fs.existsSync(logoPath)) {
        doc.image(logoPath, 260, 40, { width: 70 });
        doc.moveDown(4.5);
    }

    doc.fillColor(accentColor).font('Helvetica-Bold').fontSize(22).text('AGNI COLLEGE OF TECHNOLOGY', { align: 'center' });
    doc.fillColor(textColor).font('Helvetica-Bold').fontSize(11).text('An AUTONOMOUS Institution', { align: 'center' });
    doc.fillColor(textColor).font('Helvetica').fontSize(10).text('Affiliated to Anna University | Chennai - 603103', { align: 'center' });
    doc.moveDown(1);
    doc.strokeColor('#EEEEEE').lineWidth(1).moveTo(50, doc.y).lineTo(550, doc.y).stroke();
    doc.moveDown(1.5);

    // Document Title
    doc.fillColor(accentColor).font('Helvetica-Bold').fontSize(16).text('OFFICIAL LEAVE APPROVAL', { align: 'center' });
    doc.moveDown(1);

    // Certificate of Authenticity Ribbon
    doc.rect(50, doc.y, 500, 30).fill('#F3F4F6');
    doc.fillColor('#4B5563').font('Helvetica-Bold').fontSize(11).text('OFFICIAL DOCUMENT • PROTECTED BY SECURE QR VERIFICATION', 60, doc.y + 9, { align: 'center' });
    doc.moveDown(2.5);

    // Main Content
    const leftMargin = 60;
    const labelWidth = 100;

    // Helper to render field
    const renderField = (label, value) => {
        const currentY = doc.y;
        doc.fillColor('#6B7280').font('Helvetica').fontSize(11).text(label, leftMargin, currentY);
        doc.fillColor(textColor).font('Helvetica-Bold').fontSize(11).text(value, leftMargin + labelWidth, currentY);
        doc.moveDown(1.2);
    };

    doc.fillColor(accentColor).font('Helvetica-Bold').fontSize(13).text('STUDENT INFORMATION', 50);
    doc.moveDown(0.8);
    renderField('Student Name:', leaveRequest.studentName);
    renderField('Register No / Email:', leaveRequest.studentEmail);
    renderField('Department:', leaveRequest.department || 'N/A');
    renderField('Year/Section:', `${leaveRequest.year} Year - ${leaveRequest.section}`);

    doc.moveDown(1.5);
    doc.fillColor(accentColor).font('Helvetica-Bold').fontSize(13).text('LEAVE DETAILS', 50);
    doc.moveDown(0.8);
    renderField('Subject:', leaveRequest.subject);
    renderField('Leave Type:', leaveRequest.leaveType || 'General');
    renderField('Duration:', `${leaveRequest.fromDate} to ${leaveRequest.toDate} (${leaveRequest.duration} Day[s])`);

    // Reason with wrapping
    const reasonY = doc.y;
    doc.fillColor('#6B7280').font('Helvetica').fontSize(11).text('Reason:', leftMargin, reasonY);
    doc.fillColor(textColor).font('Helvetica').fontSize(11).text(leaveRequest.reason || leaveRequest.content, leftMargin + labelWidth, reasonY, { width: 380, align: 'justify' });

    // QR Code Integration (Floating)
    try {
        doc.image(qrBuffer, 410, 160, { width: 120 });
        doc.fillColor('#6B7280').font('Helvetica').fontSize(8).text('SCAN TO VERIFY', 410, 285, { width: 120, align: 'center' });
    } catch (imgError) {
        console.error('QR Image error:', imgError);
    }

    // Approval Section
    doc.y = 580;
    doc.fillColor(accentColor).font('Helvetica-Bold').fontSize(14).text('APPROVAL STATUS: VERIFIED ✅', 50);
    doc.fillColor('#059669').font('Helvetica-Bold').fontSize(12).text('Digitally Approved by Head of Department (HOD)', 50);

    doc.moveDown(0.8);
    doc.fillColor('#6B7280').font('Helvetica').fontSize(9);
    doc.text(`Forwarded by: ${leaveRequest.forwardedBy || 'Department Staff'}`, 50);
    doc.text(`Official ID: ${leaveId}`, 50);
    doc.text(`Generated On: ${new Date().toLocaleString()}`, 50);

    // Security Footer
    doc.rect(50, 715, 500, 45).fill('#F0FDF4');
    doc.fillColor('#166534').font('Helvetica-Bold').fontSize(9).text('SECURITY WARNING:', 60, 725, { continued: true });
    doc.font('Helvetica').fontSize(9).text(' This document is digitally verified. Any modification to names, dates, or content will be detectable via scanning. Verify authenticity by scanning the QR code or visiting the portal.', { width: 460 });

    doc.fillColor(accentColor).fontSize(8).text(verificationUrl, 50, 770, { align: 'center' });

    doc.end();

    return new Promise((resolve, reject) => {
        stream.on('finish', () => {
            console.log(`✅ Leave PDF Generated: ${pdfPath}`);
            const baseUrl = process.env.RENDER_EXTERNAL_URL || `http://localhost:${process.env.PORT || 5000}`;
            leaveRequest.pdfUrl = `${baseUrl}/api/leave-requests/${leaveRequest._id}/download`;
            resolve({ leaveId, pdfPath, verificationUrl });
        });
        stream.on('error', reject);
    });
};

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

        // Send notification to staff
        try {
            await notifyStaffOnNewRequest(leaveRequest, 'Leave');
        } catch (notifError) {
            console.error('Notification error:', notifError);
        }

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
            requests: requests,
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

        // Only fetch requests that have been approved by staff
        // Don't filter by hodStatus - let frontend handle filtering by status
        const query = {
            staffStatus: 'approved',
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
            return res.status(400).json({
                success: false,
                message: 'Invalid status. Must be "accepted", "rejected", or "approved"',
            });
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

            // Notify student about rejection
            try {
                await notifyStudentOnStatusChange(leaveRequest, 'Leave', 'rejected', 'staff');
            } catch (notifError) {
                console.error('Student rejection notification error:', notifError);
            }
        } else if (dbStatus === 'approved') {
            // Forwarding details
            if (staffName) leaveRequest.forwardedBy = staffName;
            if (inchargeName) leaveRequest.forwardedByIncharge = inchargeName;
            leaveRequest.forwardedAt = new Date().toISOString();
            if (year) leaveRequest.year = year;
            if (section) leaveRequest.section = section;

            leaveRequest.hodStatus = 'pending';
            // IMPORTANT: Status remains 'pending' overall until HOD approves
            leaveRequest.status = 'pending';

            // Notify HOD about forwarded request
            try {
                await notifyHODOnForward(leaveRequest, 'Leave');
            } catch (notifError) {
                console.error('HOD notification error:', notifError);
            }

            // Notify student that request is forwarded
            try {
                await notifyStudentOnStatusChange(leaveRequest, 'Leave', 'forwarded', 'staff');
            } catch (notifError) {
                console.error('Student notification error:', notifError);
            }
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

        console.log(`\n========== HOD STATUS UPDATE (LEAVE) START ==========`);
        console.log(`Request ID: ${id}`);
        console.log(`New Status: ${status}`);
        console.log(`Remarks: ${remarks || 'None'}`);

        if (!status || !['approved', 'rejected'].includes(status)) {
            console.error(`❌ Invalid status provided: ${status}`);
            console.log(`========== HOD STATUS UPDATE (LEAVE) END ==========\n`);
            return res.status(400).json({
                success: false,
                message: 'Invalid status. Must be "approved" or "rejected"',
            });
        }

        const leaveRequest = await LeaveRequest.findById(id);

        if (!leaveRequest) {
            console.error(`❌ Leave request not found: ${id}`);
            console.log(`========== HOD STATUS UPDATE (LEAVE) END ==========\n`);
            return res.status(404).json({
                success: false,
                message: 'Leave request not found',
            });
        }

        console.log(`Found Leave Request for student: ${leaveRequest.studentEmail}`);
        console.log(`Current staffStatus: ${leaveRequest.staffStatus}`);
        console.log(`Current hodStatus: ${leaveRequest.hodStatus}`);

        if (leaveRequest.staffStatus !== 'approved') {
            console.error(`❌ Request not approved by staff yet`);
            console.log(`========== HOD STATUS UPDATE (LEAVE) END ==========\n`);
            return res.status(400).json({
                success: false,
                message: 'Leave request must be approved by staff first',
            });
        }

        leaveRequest.hodStatus = status;
        if (remarks) leaveRequest.hodRemarks = remarks;

        // Update overall status - Treat 'approved' or 'accepted' as approval
        const isApproved = status && (status.toLowerCase() === 'approved' || status.toLowerCase() === 'accepted');

        if (isApproved) {
            leaveRequest.status = 'accepted';
            console.log(`✅ Setting overall status to 'accepted' (from HOD status: ${status})`);

            // Use the helper for PDF generation
            try {
                await generateLeavePDFHelper(leaveRequest);
            } catch (pdfError) {
                console.error('❌ PDF Generation Error:', pdfError);
                // We still save the approval status even if PDF fails
            }
        } else if (status && status.toLowerCase() === 'rejected') {
            leaveRequest.status = 'rejected';
            console.log(`❌ Setting overall status to 'rejected'`);
        } else {
            console.log(`ℹ️ Status updated to '${status}', no overall status change or PDF generation triggered.`);
        }

        await leaveRequest.save();
        console.log(`✅ Leave request updated in database`);

        // Notify student about HOD decision
        console.log(`\nAttempting to notify student about HOD decision...`);
        try {
            const notificationResult = await notifyStudentOnStatusChange(leaveRequest, 'Leave', status, 'hod');
            if (notificationResult.success) {
                console.log(`✅ Student notification sent successfully`);
            } else {
                console.error(`❌ Student notification failed: ${notificationResult.message || notificationResult.error}`);
            }
        } catch (notifError) {
            console.error('❌ Student HOD notification error:', notifError);
        }

        console.log(`========== HOD STATUS UPDATE (LEAVE) END ==========\n`);

        res.status(200).json({
            success: true,
            message: `Leave request ${status} by HOD`,
            data: leaveRequest,
        });

    } catch (error) {
        console.error('❌ Update HOD status error:', error);
        console.log(`========== HOD STATUS UPDATE (LEAVE) END ==========\n`);
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

// Delete leave request
exports.deleteLeaveRequest = async (req, res) => {
    try {
        const { id } = req.params;

        const leaveRequest = await LeaveRequest.findByIdAndDelete(id);

        if (!leaveRequest) {
            return res.status(404).json({
                success: false,
                message: 'Leave request not found',
            });
        }

        res.status(200).json({
            success: true,
            message: 'Leave request deleted successfully',
        });

    } catch (error) {
        console.error('Delete leave request error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to delete leave request',
            error: error.message,
        });
    }
};

// Update leave request (edit)
exports.updateLeaveRequest = async (req, res) => {
    try {
        const { id } = req.params;
        const updateData = req.body;

        // Don't allow editing if already processed
        const existing = await LeaveRequest.findById(id);
        if (!existing) {
            return res.status(404).json({
                success: false,
                message: 'Leave request not found',
            });
        }

        if (existing.status !== 'pending' && existing.staffStatus !== 'pending') {
            return res.status(400).json({
                success: false,
                message: 'Cannot edit a processed leave request',
            });
        }

        // Update allowed fields
        const allowedUpdates = ['subject', 'content', 'reason', 'leaveType', 'fromDate', 'toDate', 'duration', 'image'];
        const updates = {};
        allowedUpdates.forEach(field => {
            if (updateData[field] !== undefined) {
                updates[field] = updateData[field];
            }
        });
        updates.updatedAt = new Date().toISOString();

        const leaveRequest = await LeaveRequest.findByIdAndUpdate(
            id,
            updates,
            { new: true }
        );

        res.status(200).json({
            success: true,
            message: 'Leave request updated successfully',
            data: leaveRequest,
        });

    } catch (error) {
        console.error('Update leave request error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to update leave request',
            error: error.message,
        });
    }
};

// Verify Leave Request
exports.verifyLeave = async (req, res) => {
    try {
        const { leaveId } = req.params;
        const leave = await LeaveRequest.findOne({ leaveId });

        if (!leave) {
            return res.status(404).send(`
                <div style="font-family: sans-serif; text-align: center; padding: 50px;">
                    <h1 style="color: red;">INVALID DOCUMENT ❌</h1>
                    <p>No matching leave record found in Attendanzy database.</p>
                </div>
            `);
        }

        res.send(`
            <html>
                <head>
                    <title>Attendanzy Verification</title>
                    <meta name="viewport" content="width=device-width, initial-scale=1.0">
                    <style>
                        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f4f7f6; color: #333; margin: 0; padding: 20px; }
                        .card { max-width: 500px; margin: 0 auto; background: white; padding: 30px; border-radius: 15px; box-shadow: 0 10px 25px rgba(0,0,0,0.1); }
                        .header { text-align: center; border-bottom: 2px solid #eee; padding-bottom: 20px; margin-bottom: 20px; }
                        .status { display: inline-block; padding: 10px 20px; border-radius: 50px; font-weight: bold; font-size: 14px; background: #e7f9ed; color: #2ecc71; margin-bottom: 20px; }
                        .field { margin-bottom: 15px; border-bottom: 1px solid #f9f9f9; padding-bottom: 8px; }
                        .label { font-size: 12px; color: #888; text-transform: uppercase; letter-spacing: 1px; }
                        .value { font-size: 16px; font-weight: 500; color: #2c3e50; }
                        .footer { text-align: center; margin-top: 30px; font-size: 12px; color: #aaa; }
                        .success-icon { font-size: 40px; color: #2ecc71; margin-bottom: 10px; }
                    </style>
                </head>
                <body>
                    <div class="card">
                        <div class="header">
                            <div class="success-icon">✅</div>
                            <h2 style="margin: 0; color: #1a1a1a;">Attendanzy Verification</h2>
                            <p style="color: #666; font-size: 14px; margin-top: 5px;">ID: ${leave.leaveId}</p>
                        </div>
                        
                        <div style="text-align: center;">
                            <div class="status">VALID DOCUMENT OFFICIAL</div>
                        </div>

                        <div class="field">
                            <div class="label">Student Name</div>
                            <div class="value">${leave.studentName}</div>
                        </div>
                        <div class="field">
                            <div class="label">Register No / Email</div>
                            <div class="value">${leave.studentEmail}</div>
                        </div>
                        <div class="field">
                            <div class="label">Duration</div>
                            <div class="value">${leave.fromDate} to ${leave.toDate} (${leave.duration} Day[s])</div>
                        </div>
                        <div class="field">
                            <div class="label">Reason</div>
                            <div class="value">${leave.reason || leave.content}</div>
                        </div>
                        <div class="field">
                            <div class="label">Approved By</div>
                            <div class="value">HOD (via ${leave.forwardedBy})</div>
                        </div>
                        <div class="field">
                            <div class="label">Verification Timestamp</div>
                            <div class="value">${leave.updatedAt || 'Recently Approved'}</div>
                        </div>

                        <div class="footer">
                            Attendanzy Secure Verification System &copy; 2026
                        </div>
                    </div>
                </body>
            </html>
        `);

    } catch (error) {
        console.error('Verification error:', error);
        res.status(500).send("Internal Server Error");
    }
};

// Download Leave PDF
exports.downloadLeavePDF = async (req, res) => {
    try {
        let { id } = req.params;

        // Harden: Sanitize ID if it contains MongoDB wrappers like ObjectId("hex")
        if (id && id.includes('ObjectId("')) {
            const match = id.match(/ObjectId\("([0-9a-fA-F]+)"\)/);
            if (match) id = match[1];
        } else if (id && id.startsWith('"') && id.endsWith('"')) {
            id = id.slice(1, -1);
        }

        const leave = await LeaveRequest.findById(id);

        if (!leave) {
            return res.status(404).json({
                success: false,
                message: `Leave request record not found for database ID: ${id}`,
            });
        }

        if (!leave.leaveId) {
            // Fail-safe: If status is accepted but ID/PDF missing, generate now!
            if (leave.status === 'accepted') {
                console.log(`⚡ On-the-fly regeneration for Leave ${id}`);
                await generateLeavePDFHelper(leave);
                await leave.save();
            } else {
                return res.status(404).json({
                    success: false,
                    message: `Leave PDF not yet generated for this request. Status is: ${leave.status}. Secure ID (leaveId) is missing.`,
                });
            }
        }

        const lettersDir = path.join(__dirname, '../letters');
        const pdfPath = path.join(lettersDir, `${leave.leaveId}.pdf`);

        // Fail-safe: If record has ID but file is missing on disk
        if (!fs.existsSync(pdfPath)) {
            console.log(`⚡ PDF file missing on disk, regenerating: ${pdfPath}`);
            await generateLeavePDFHelper(leave);
            await leave.save();
        }

        if (!fs.existsSync(pdfPath)) {
            return res.status(404).json({
                success: false,
                message: `Failed to generate or find PDF file on server.`,
            });
        }

        res.download(pdfPath, `Leave_${leave.studentName.replace(/\s+/g, '_')}.pdf`);

    } catch (error) {
        console.error('Download error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to download PDF',
            error: error.message,
        });
    }
};
