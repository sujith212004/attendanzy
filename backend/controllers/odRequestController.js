const ODRequest = require('../models/ODRequest');
const { notifyStaffOnNewRequest, notifyHODOnForward, notifyStudentOnStatusChange, notifyStaffOnHODDecision } = require('../services/notificationService');
const QRCode = require('qrcode');
const PDFDocument = require('pdfkit');
const fs = require('fs');
const path = require('path');



const generateODPDFHelper = async (odRequest) => {
    // Generate Secure OD ID if not exists
    if (!odRequest.odId) {
        const timestamp = new Date();
        const dateStr = timestamp.toISOString().replace(/[-:T.Z]/g, "").substring(0, 8);
        const randomStr = Math.random().toString(36).substring(2, 5).toUpperCase();
        odRequest.odId = `ATZ-OD-${dateStr}-${randomStr}`;
    }

    const odId = odRequest.odId;
    const baseUrl = process.env.RENDER_EXTERNAL_URL || `http://localhost:${process.env.PORT || 5000}`;
    const verificationUrl = `${baseUrl}/api/od-requests/verify/${odId}`;
    odRequest.verificationUrl = verificationUrl;

    // Generate QR Code as Buffer
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
    const pdfPath = path.join(lettersDir, `${odId}.pdf`);
    const doc = new PDFDocument({ margin: 50 });
    const stream = fs.createWriteStream(pdfPath);
    doc.pipe(stream);

    // PDF Design System - Professional Institutional Layout
    const accentColor = '#2563EB'; // Formal Blue for OD
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
    doc.fillColor(secondaryTextColor).font('Helvetica-Bold').fontSize(9).text(`REF NO: ${odId}`, 50, 125);
    doc.text(`ISSUE DATE: ${new Date().toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' }).toUpperCase()}`, 400, 125, { align: 'right' });

    // --- Document Title ---
    doc.moveDown(2);
    doc.fillColor(textColor).font('Helvetica-Bold').fontSize(14).text('OFFICIAL ON-DUTY (OD) APPROVAL LETTER', { align: 'center', underline: true });
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
    doc.fillColor(textColor).font('Helvetica-Bold').fontSize(10).text(odRequest.studentName.toUpperCase(), leftCol + labelWidth, currentY);

    doc.fillColor(secondaryTextColor).font('Helvetica').fontSize(10).text('Register No:', rightCol, currentY);
    doc.fillColor(textColor).font('Helvetica-Bold').fontSize(10).text(odRequest.studentEmail.split('@')[0].toUpperCase(), rightCol + labelWidth, currentY);

    doc.moveDown(1.5);

    // Row 2
    currentY = doc.y;
    doc.fillColor(secondaryTextColor).font('Helvetica').fontSize(10).text('Department:', leftCol, currentY);
    doc.fillColor(textColor).font('Helvetica-Bold').fontSize(10).text(odRequest.department || 'N/A', leftCol + labelWidth, currentY);

    doc.fillColor(secondaryTextColor).font('Helvetica').fontSize(10).text('Year & Section:', rightCol, currentY);
    doc.fillColor(textColor).font('Helvetica-Bold').fontSize(10).text(`${odRequest.year} Year / ${odRequest.section}`, rightCol + labelWidth, currentY);

    doc.moveDown(2.5);

    // --- OD Details ---
    doc.fillColor(accentColor).font('Helvetica-Bold').fontSize(11).text('ON-DUTY SPECIFICATIONS', 50);
    doc.moveDown(0.5);
    doc.strokeColor('#F3F4FB').lineWidth(1).moveTo(50, doc.y).lineTo(545, doc.y).stroke();
    doc.moveDown(0.8);

    // Row 3
    currentY = doc.y;
    doc.fillColor(secondaryTextColor).font('Helvetica').fontSize(10).text('Effective From:', leftCol, currentY);
    doc.fillColor(textColor).font('Helvetica-Bold').fontSize(10).text(odRequest.from, leftCol + labelWidth, currentY);

    doc.fillColor(secondaryTextColor).font('Helvetica').fontSize(10).text('Effective To:', rightCol, currentY);
    doc.fillColor(textColor).font('Helvetica-Bold').fontSize(10).text(odRequest.to, rightCol + labelWidth, currentY);

    doc.moveDown(1.5);

    // Row 4
    currentY = doc.y;
    doc.fillColor(secondaryTextColor).font('Helvetica').fontSize(10).text('Activity Subject:', leftCol, currentY);
    doc.fillColor(textColor).font('Helvetica-Bold').fontSize(10).text(odRequest.subject, leftCol + labelWidth, currentY, { width: 340 });

    doc.moveDown(2);

    // Narrative Description
    doc.fillColor(secondaryTextColor).font('Helvetica-Bold').fontSize(10).text('Detailed Description:', 50);
    doc.moveDown(0.3);
    doc.fillColor(textColor).font('Helvetica').fontSize(10).text(odRequest.content || odRequest.reason, 70, doc.y, { width: 475, align: 'justify' });

    doc.moveDown(3);

    // --- Digital Verification Column (Floating Bottom Right) ---
    const bottomAuditY = 620;

    // Approval Section
    doc.fillColor(accentColor).font('Helvetica-Bold').fontSize(11).text('AUTHORIZATION & VERIFICATION', 50, bottomAuditY);
    doc.strokeColor('#E5E7EB').lineWidth(0.5).moveTo(50, bottomAuditY + 15).lineTo(545, bottomAuditY + 15).stroke();

    doc.y = bottomAuditY + 30;
    doc.fillColor(textColor).font('Helvetica-Bold').fontSize(10).text('STATUS: DIGITALLY AUTHORIZED', 70);
    doc.fillColor(secondaryTextColor).font('Helvetica').fontSize(9).text(`Verified by: Head of Department (HOD)`, 70, doc.y + 2);
    doc.text(`Forwarded by: ${odRequest.forwardedBy || 'Department Staff'}`, 70, doc.y + 2);
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
            console.log(`✅ OD PDF Generated: ${pdfPath}`);
            const baseUrl = process.env.RENDER_EXTERNAL_URL || `http://localhost:${process.env.PORT || 5000}`;
            odRequest.pdfUrl = `${baseUrl}/api/od-requests/${odRequest._id}/download`;
            resolve({ odId, pdfPath, verificationUrl });
        });
        stream.on('error', reject);
    });
};

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

        // Only fetch requests that have been approved by staff
        // Don't filter by hodStatus - let frontend handle filtering by status
        const query = {
            staffStatus: 'approved',
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

        // Update overall status - Treat 'approved' or 'accepted' as approval
        const isApproved = status && (status.toLowerCase() === 'approved' || status.toLowerCase() === 'accepted');

        if (isApproved) {
            odRequest.status = 'accepted';
            console.log(`✅ Setting overall status to 'accepted' (from HOD status: ${status})`);

            // Use the helper for PDF generation
            try {
                await generateODPDFHelper(odRequest);
            } catch (pdfError) {
                console.error('❌ PDF Generation Error:', pdfError);
                // We still save the approval status even if PDF fails
            }
        } else if (status && status.toLowerCase() === 'rejected') {
            odRequest.status = 'rejected';
            console.log(`❌ Setting overall status to 'rejected'`);
        } else {
            console.log(`ℹ️ Status updated to '${status}', no overall status change or PDF generation triggered.`);
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

// Verify OD Authenticity
exports.verifyOD = async (req, res) => {
    try {
        const { odId } = req.params;
        const od = await ODRequest.findOne({ odId });

        if (!od) {
            return res.status(404).send(`
                <div style="font-family: sans-serif; text-align: center; padding: 50px;">
                    <h1 style="color: red;">INVALID DOCUMENT ❌</h1>
                    <p>No matching OD record found in Attendanzy database.</p>
                </div>
            `);
        }

        res.send(`
            <html>
                <head>
                    <title>Attendanzy Verification - OD</title>
                    <meta name="viewport" content="width=device-width, initial-scale=1.0">
                    <style>
                        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f0f4f8; color: #333; margin: 0; padding: 20px; }
                        .card { max-width: 500px; margin: 0 auto; background: white; padding: 30px; border-radius: 15px; box-shadow: 0 10px 25px rgba(0,0,0,0.1); border-top: 5px solid #3b82f6; }
                        .header { text-align: center; border-bottom: 2px solid #eee; padding-bottom: 20px; margin-bottom: 20px; }
                        .status { display: inline-block; padding: 10px 20px; border-radius: 50px; font-weight: bold; font-size: 14px; background: #e0f2fe; color: #0369a1; margin-bottom: 20px; }
                        .field { margin-bottom: 15px; border-bottom: 1px solid #f9f9f9; padding-bottom: 8px; }
                        .label { font-size: 12px; color: #888; text-transform: uppercase; letter-spacing: 1px; }
                        .value { font-size: 16px; font-weight: 500; color: #1e293b; }
                        .footer { text-align: center; margin-top: 30px; font-size: 12px; color: #aaa; }
                        .success-icon { font-size: 40px; color: #3b82f6; margin-bottom: 10px; }
                    </style>
                </head>
                <body>
                    <div class="card">
                        <div class="header">
                            <div class="success-icon">🛡️</div>
                            <h2 style="margin: 0; color: #1a1a1a;">Attendanzy Verification</h2>
                            <p style="color: #666; font-size: 14px; margin-top: 5px;">OD ID: ${od.odId}</p>
                        </div>
                        
                        <div style="text-align: center;">
                            <div class="status">VALID ON-DUTY OFFICIAL</div>
                        </div>

                        <div class="field">
                            <div class="label">Student Name</div>
                            <div class="value">${od.studentName}</div>
                        </div>
                        <div class="field">
                            <div class="label">Email</div>
                            <div class="value">${od.studentEmail}</div>
                        </div>
                        <div class="field">
                            <div class="label">Duration</div>
                            <div class="value">${od.from} to ${od.to}</div>
                        </div>
                        <div class="field">
                            <div class="label">Subject</div>
                            <div class="value">${od.subject}</div>
                        </div>
                        <div class="field">
                            <div class="label">Approved By</div>
                            <div class="value">HOD (via ${od.forwardedBy})</div>
                        </div>
                        <div class="field">
                            <div class="label">Timestamp</div>
                            <div class="value">${od.updatedAt || 'Recently Approved'}</div>
                        </div>

                        <div class="footer">
                            Attendanzy Secure Verification System &copy; 2026
                        </div>
                    </div>
                </body>
            </html>
        `);

    } catch (error) {
        console.error('OD Verification error:', error);
        res.status(500).send("Internal Server Error");
    }
};

// Download OD PDF
exports.downloadODPDF = async (req, res) => {
    try {
        let { id } = req.params;

        // Harden: Sanitize ID if it contains MongoDB wrappers like ObjectId("hex")
        if (id && id.includes('ObjectId("')) {
            const match = id.match(/ObjectId\("([0-9a-fA-F]+)"\)/);
            if (match) id = match[1];
        } else if (id && id.startsWith('"') && id.endsWith('"')) {
            id = id.slice(1, -1);
        }

        const od = await ODRequest.findById(id);

        if (!od) {
            return res.status(404).json({
                success: false,
                message: `OD request record not found for database ID: ${id}`,
            });
        }

        if (!od.odId) {
            // Fail-safe: If status is accepted but ID/PDF missing, generate now!
            if (od.status === 'accepted') {
                console.log(`⚡ On-the-fly regeneration for OD ${id}`);
                await generateODPDFHelper(od);
                await od.save();
            } else {
                return res.status(404).json({
                    success: false,
                    message: `OD PDF not yet generated for this request. Status is: ${od.status}. Secure ID (odId) is missing.`,
                });
            }
        }

        const lettersDir = path.join(__dirname, '../letters');
        const pdfPath = path.join(lettersDir, `${od.odId}.pdf`);

        // Fail-safe: If record has ID but file is missing on disk
        if (!fs.existsSync(pdfPath)) {
            console.log(`⚡ PDF file missing on disk, regenerating: ${pdfPath}`);
            await generateODPDFHelper(od);
            await od.save();
        }

        if (!fs.existsSync(pdfPath)) {
            return res.status(404).json({
                success: false,
                message: `Failed to generate or find PDF file on server.`,
            });
        }

        res.download(pdfPath, `OD_Request_${od.studentName.replace(/\s+/g, '_')}.pdf`);

    } catch (error) {
        console.error('OD Download error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to download PDF',
            error: error.message,
        });
    }
};
