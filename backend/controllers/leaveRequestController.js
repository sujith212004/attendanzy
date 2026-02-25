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

    // PDF Design System - Professional Institutional Layout
    const accentColor = '#059669'; // Formal Green for Leave
    const textColor = '#111827';
    const secondaryTextColor = '#4B5563';
    const logoPath = path.join(__dirname, '../assets/logo.jpg');

    // --- Header Section ---
    if (fs.existsSync(logoPath)) {
        doc.image(logoPath, 50, 45, { width: 60 });
    }

    // Institution Branding
    doc.fillColor(textColor).font('Helvetica-Bold').fontSize(18).text('AGNI COLLEGE OF TECHNOLOGY', 120, 45);
    doc.font('Helvetica-Bold').fontSize(9).text('An AUTONOMOUS Institution | ISO 9001:2015 Certified', 120, 65);
    doc.font('Helvetica').fontSize(8).text('Affiliated to Anna University | Approved by AICTE', 120, 77);
    doc.text('OMR, Thalambur, Chennai - 603 103, Tamil Nadu, India', 120, 89);

    doc.moveDown(2);
    doc.strokeColor('#E5E7EB').lineWidth(0.5).moveTo(50, 110).lineTo(545, 110).stroke();

    // --- Reference & Date ---
    doc.y = 125;
    doc.fillColor(secondaryTextColor).font('Helvetica-Bold').fontSize(9).text(`REF NO: ${leaveId}`, 50, 125);
    doc.text(`ISSUE DATE: ${new Date().toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' }).toUpperCase()}`, 400, 125, { align: 'right' });

    // --- Document Title ---
    doc.moveDown(2);
    doc.fillColor(textColor).font('Helvetica-Bold').fontSize(14).text('OFFICIAL LEAVE APPROVAL LETTER', { align: 'center', underline: true });
    doc.moveDown(2);

    // --- Student Information Grid ---
    doc.fillColor(accentColor).font('Helvetica-Bold').fontSize(11).text('STUDENT PARTICULARS', 50);
    doc.moveDown(0.5);
    doc.strokeColor('#F3F4FB').lineWidth(1).moveTo(50, doc.y).lineTo(545, doc.y).stroke();
    doc.moveDown(0.8);

    const leftCol = 70;
    const rightCol = 320;
    const labelWidth = 100;

    // Row 1
    let currentY = doc.y;
    doc.fillColor(secondaryTextColor).font('Helvetica').fontSize(10).text('Student Name:', leftCol, currentY);
    doc.fillColor(textColor).font('Helvetica-Bold').fontSize(10).text(leaveRequest.studentName.toUpperCase(), leftCol + labelWidth, currentY);

    doc.fillColor(secondaryTextColor).font('Helvetica').fontSize(10).text('Register No:', rightCol, currentY);
    doc.fillColor(textColor).font('Helvetica-Bold').fontSize(10).text(leaveRequest.studentEmail.split('@')[0].toUpperCase(), rightCol + labelWidth, currentY);

    doc.moveDown(1.5);

    // Row 2
    currentY = doc.y;
    doc.fillColor(secondaryTextColor).font('Helvetica').fontSize(10).text('Department:', leftCol, currentY);
    doc.fillColor(textColor).font('Helvetica-Bold').fontSize(10).text(leaveRequest.department || 'N/A', leftCol + labelWidth, currentY);

    doc.fillColor(secondaryTextColor).font('Helvetica').fontSize(10).text('Year & Section:', rightCol, currentY);
    doc.fillColor(textColor).font('Helvetica-Bold').fontSize(10).text(`${leaveRequest.year} Year / ${leaveRequest.section}`, rightCol + labelWidth, currentY);

    doc.moveDown(2.5);

    // --- Leave Details ---
    doc.fillColor(accentColor).font('Helvetica-Bold').fontSize(11).text('LEAVE SPECIFICATIONS', 50);
    doc.moveDown(0.5);
    doc.strokeColor('#F3F4FB').lineWidth(1).moveTo(50, doc.y).lineTo(545, doc.y).stroke();
    doc.moveDown(0.8);

    // Row 3
    currentY = doc.y;
    doc.fillColor(secondaryTextColor).font('Helvetica').fontSize(10).text('Effective From:', leftCol, currentY);
    doc.fillColor(textColor).font('Helvetica-Bold').fontSize(10).text(leaveRequest.fromDate, leftCol + labelWidth, currentY);

    doc.fillColor(secondaryTextColor).font('Helvetica').fontSize(10).text('Effective To:', rightCol, currentY);
    doc.fillColor(textColor).font('Helvetica-Bold').fontSize(10).text(leaveRequest.toDate, rightCol + labelWidth, currentY);

    doc.moveDown(1.5);

    // Row 4
    currentY = doc.y;
    doc.fillColor(secondaryTextColor).font('Helvetica').fontSize(10).text('Total Duration:', leftCol, currentY);
    doc.fillColor(textColor).font('Helvetica-Bold').fontSize(10).text(`${leaveRequest.duration} Day[s]`, leftCol + labelWidth, currentY);

    doc.fillColor(secondaryTextColor).font('Helvetica').fontSize(10).text('Leave Category:', rightCol, currentY);
    doc.fillColor(textColor).font('Helvetica-Bold').fontSize(10).text(leaveRequest.leaveType || 'General', rightCol + labelWidth, currentY);

    doc.moveDown(2);

    // Subject/Reason Block
    doc.fillColor(secondaryTextColor).font('Helvetica-Bold').fontSize(10).text('Subject / Purpose:', 50);
    doc.moveDown(0.3);
    doc.fillColor(textColor).font('Helvetica').fontSize(10).text(leaveRequest.subject, 70, doc.y, { width: 475 });

    doc.moveDown(1.2);
    doc.fillColor(secondaryTextColor).font('Helvetica-Bold').fontSize(10).text('Detailed Reason:', 50);
    doc.moveDown(0.3);
    doc.fillColor(textColor).font('Helvetica').fontSize(10).text(leaveRequest.reason || leaveRequest.content, 70, doc.y, { width: 475, align: 'justify' });

    doc.moveDown(3);

    // --- Digital Verification Column (Floating Bottom Right) ---
    const bottomAuditY = 620;

    // Approval Section
    doc.fillColor(accentColor).font('Helvetica-Bold').fontSize(11).text('AUTHORIZATION & VERIFICATION', 50, bottomAuditY);
    doc.strokeColor('#E5E7EB').lineWidth(0.5).moveTo(50, bottomAuditY + 15).lineTo(545, bottomAuditY + 15).stroke();

    doc.y = bottomAuditY + 30;
    doc.fillColor(textColor).font('Helvetica-Bold').fontSize(10).text('STATUS: DIGITALLY APPROVED', 70);
    doc.fillColor(secondaryTextColor).font('Helvetica').fontSize(9).text(`Verified by: Head of Department (HOD)`, 70, doc.y + 2);
    doc.text(`Forwarded by: ${leaveRequest.forwardedBy || 'Staff In-charge'}`, 70, doc.y + 2);
    doc.text(`Approval Timestamp: ${new Date().toLocaleString('en-IN')}`, 70, doc.y + 2);

    // QR Code
    try {
        doc.image(qrBuffer, 445, bottomAuditY + 25, { width: 85 });
        doc.fillColor(secondaryTextColor).font('Helvetica').fontSize(7).text('SCAN TO VERIFY', 445, bottomAuditY + 115, { width: 85, align: 'center' });
    } catch (qrErr) {
        console.error('QR Error:', qrErr);
    }

    // Signatures
    doc.y = bottomAuditY + 130;
    doc.fillColor(textColor).font('Helvetica-Bold').fontSize(10).text('______________________', 50, doc.y);
    doc.text('Office Seal / Signature', 50, doc.y + 15);

    // --- System Footer ---
    doc.y = 750;
    doc.strokeColor('#E5E7EB').lineWidth(0.5).moveTo(50, doc.y).lineTo(545, doc.y).stroke();
    doc.fillColor(secondaryTextColor).font('Helvetica').fontSize(7.5).text('This is a system-generated document. Unauthorized modification is strictly prohibited. Verification URL: ', 50, 765, { continued: true });
    doc.fillColor(accentColor).text(verificationUrl);

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
