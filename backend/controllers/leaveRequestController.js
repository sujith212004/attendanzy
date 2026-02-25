const LeaveRequest = require('../models/LeaveRequest');
const { notifyStaffOnNewRequest, notifyHODOnForward, notifyStudentOnStatusChange, notifyStaffOnHODDecision } = require('../services/notificationService');
const QRCode = require('qrcode');
const PDFDocument = require('pdfkit');
const fs = require('fs');
const path = require('path');

/**
 * Helper to generate Secure Leave ID and PDF (Strict One-Page Memorandum Style)
 */
const generateLeavePDFHelper = async (leaveRequest) => {
    if (!leaveRequest.leaveId) {
        const timestamp = new Date();
        const dateStr = timestamp.toISOString().replace(/[-:T.Z]/g, "").substring(0, 8);
        const randomStr = Math.random().toString(36).substring(2, 5).toUpperCase();
        leaveRequest.leaveId = `ATZ-LV-${dateStr}-${randomStr}`;
    }

    const leaveId = leaveRequest.leaveId;
    const baseUrl = process.env.RENDER_EXTERNAL_URL || `http://localhost:${process.env.PORT || 5000}`;
    const verificationUrl = `${baseUrl}/api/leave-requests/verify/${leaveId}`;
    leaveRequest.verificationUrl = verificationUrl;

    const qrBuffer = await QRCode.toBuffer(verificationUrl, {
        margin: 1,
        width: 300,
        errorCorrectionLevel: 'H' // High error correction for logo overlay
    });

    const lettersDir = path.join(__dirname, '../letters');
    if (!fs.existsSync(lettersDir)) {
        fs.mkdirSync(lettersDir, { recursive: true });
    }

    const pdfPath = path.join(lettersDir, `${leaveId}.pdf`);
    if (fs.existsSync(pdfPath)) {
        try { fs.unlinkSync(pdfPath); } catch (e) { }
    }

    const doc = new PDFDocument({ margin: 40, size: 'A4' }); // Slightly tighter margins for 1-page safety
    const stream = fs.createWriteStream(pdfPath);
    doc.pipe(stream);

    const textColor = '#111827';
    const accentColor = '#059669';
    const logoPath = path.join(__dirname, '../assets/logo.jpg');

    // --- Background Watermark ---
    if (fs.existsSync(logoPath)) {
        doc.save();
        doc.opacity(0.05);
        doc.image(logoPath, 147, 280, { width: 300 });
        doc.restore();
    }

    // --- Institutional Letterhead (Top Header) ---
    if (fs.existsSync(logoPath)) {
        doc.image(logoPath, 45, 40, { width: 60 });
    }

    doc.fillColor(textColor).font('Helvetica-Bold').fontSize(18).text('AGNI COLLEGE OF TECHNOLOGY', 115, 42);
    doc.font('Helvetica-Bold').fontSize(8.5).text('An AUTONOMOUS Institution | ISO 9001:2015 Certified', 115, 62);
    doc.font('Helvetica').fontSize(8.5).text('Affiliated to Anna University | Approved by AICTE', 115, 74);
    doc.text('OMR, Thalambur, Chennai - 603 103, Tamil Nadu, India', 115, 86);
    doc.strokeColor('#000000').lineWidth(1.5).moveTo(40, 110).lineTo(555, 110).stroke();

    // Ref and Date
    doc.y = 130;
    const today = new Date().toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
    doc.font('Helvetica-Bold').fontSize(10).text(`Ref No: LV/${leaveId}`, 45, 130);
    doc.text(`Date: ${today}`, 440, 130, { align: 'right' });

    doc.moveDown(3);

    // --- "From" Section ---
    doc.font('Helvetica-Bold').fontSize(11).text('FROM:', 45);
    doc.moveDown(0.3);
    doc.font('Helvetica').fontSize(11);
    const fromText = leaveRequest.from || `${leaveRequest.studentName}\nDepartment of ${leaveRequest.department}\n${leaveRequest.year}-${leaveRequest.section}`;
    doc.text(fromText, 75, doc.y, { lineGap: 3 });

    doc.moveDown(2);

    // --- "To" Section ---
    doc.font('Helvetica-Bold').fontSize(11).text('TO:', 45);
    doc.moveDown(0.3);
    doc.font('Helvetica').fontSize(11);
    const toText = leaveRequest.to || `The Head of Department,\nDepartment of ${leaveRequest.department},\nAgni College of Technology.`;
    doc.text(toText, 75, doc.y, { lineGap: 3 });

    doc.moveDown(3);

    // --- Subject Line ---
    doc.font('Helvetica-Bold').fontSize(11.5).text(`Subject: ${leaveRequest.subject.toUpperCase()} - REGARDING.`, 45, doc.y, { underline: true });

    doc.moveDown(4);

    // --- Body Section ---
    doc.font('Helvetica').fontSize(12).text('Respected Sir/Madam,', 45);
    doc.moveDown(1.5);

    const mainContent = leaveRequest.content || leaveRequest.reason || 'Requested leave authorization.';
    doc.text(mainContent, 45, doc.y, { align: 'justify', lineGap: 5, width: 505 });

    doc.moveDown(5);
    doc.text('Thanking you,', 45);

    doc.moveDown(4);
    doc.font('Helvetica-Bold').text('Yours obediently,', 380);
    doc.moveDown(0.4);
    doc.text(leaveRequest.studentName.toUpperCase(), 380);

    // --- High-Fidelity Digital Authorization Area (Sticky Footer) ---
    const bottomBlockY = 665;
    doc.strokeColor('#111827').lineWidth(2).moveTo(40, bottomBlockY - 20).lineTo(555, bottomBlockY - 20).stroke();

    doc.fillColor(accentColor).font('Helvetica-Bold').fontSize(14).text('SECURE DIGITAL AUTHORIZATION', 45, bottomBlockY);

    doc.y = bottomBlockY + 30;
    doc.fillColor('#374151').font('Helvetica').fontSize(9.5).text('This document is electronically generated and officially verified by the Agni College of Technology institutional portal. Validity can be verified by scanning the Doc-Verify QR code.', 45, doc.y, { width: 380, lineGap: 2 });

    doc.moveDown(1);
    doc.fillColor(textColor).font('Helvetica-Bold').fontSize(9);
    doc.text(`VERIFIED BY: ${leaveRequest.forwardedBy || 'Department Staff'}`, 45);
    doc.text(`AUTHORIZED BY: HEAD OF DEPARTMENT`, 45);
    doc.text(`TIMESTAMP: ${new Date().toLocaleString('en-IN')}`, 45);

    // --- Branded QR Code ---
    try {
        const qrX = 460;
        const qrY = bottomBlockY + 5;
        const qrSize = 85;

        doc.image(qrBuffer, qrX, qrY, { width: qrSize });

        // Add Attendanzy branding box in the center of QR
        const boxSize = 20;
        doc.save();
        doc.fillColor('white').rect(qrX + (qrSize / 2) - (boxSize / 2), qrY + (qrSize / 2) - (boxSize / 2), boxSize, boxSize).fill();
        doc.fillColor(accentColor).font('Helvetica-Bold').fontSize(6).text('ATZ', qrX + (qrSize / 2) - (boxSize / 2), qrY + (qrSize / 2) - 2, { width: boxSize, align: 'center' });
        doc.restore();

        doc.fillColor('#6B7280').font('Helvetica-Bold').fontSize(7).text('DOC-VERIFY QR', qrX, qrY + qrSize + 5, { width: qrSize, align: 'center' });
    } catch (e) { }

    // Security Footer
    doc.strokeColor('#E5E7EB').lineWidth(1).moveTo(40, 805).lineTo(555, 805).stroke();
    doc.fillColor('#9CA3AF').font('Helvetica').fontSize(8).text('System generated secure document | ACT-Attendanzy Portal | CID: ' + (leaveRequest._id.toString().substring(0, 8)), 40, 812, { width: 515, align: 'center' });

    doc.end();

    return new Promise((resolve, reject) => {
        stream.on('finish', () => {
            const baseUrl = process.env.RENDER_EXTERNAL_URL || `http://localhost:${process.env.PORT || 5000}`;
            leaveRequest.pdfUrl = `${baseUrl}/api/leave-requests/${leaveRequest._id}/download`;
            resolve({ leaveId, pdfPath, verificationUrl });
        });
        stream.on('error', reject);
    });
};

// --- API Methods ---

exports.submitLeaveRequest = async (req, res) => {
    try {
        const { studentName, studentEmail, from, to, subject, content, reason, leaveType, fromDate, toDate, duration, image, department, year, section } = req.body;
        if (!studentName || !studentEmail || !from || !to || !subject || !content || !leaveType || !fromDate || !toDate || !department || !year || !section) {
            return res.status(400).json({ success: false, message: 'Please provide all required fields' });
        }
        const calculatedDuration = duration || 1;
        if (calculatedDuration > 2) {
            return res.status(400).json({ success: false, message: 'Leave application is limited to maximum 2 continuous days' });
        }
        const leaveRequest = new LeaveRequest({ studentName, studentEmail, from, to, subject, content, reason: reason || content, leaveType, fromDate, toDate, duration: calculatedDuration, image: image || '', department, year, section, staffStatus: 'pending', hodStatus: 'pending', status: 'pending', createdAt: new Date().toISOString() });
        await leaveRequest.save();
        try { await notifyStaffOnNewRequest(leaveRequest, 'Leave'); } catch (notifError) { console.error('Notification error:', notifError); }
        res.status(201).json({ success: true, message: 'Leave request submitted successfully', data: leaveRequest });
    } catch (error) {
        console.error('Submit leave request error:', error);
        res.status(500).json({ success: false, message: 'Failed to submit leave request', error: error.message });
    }
};

exports.getStudentLeaveRequests = async (req, res) => {
    try {
        const { email } = req.params;
        const requests = await LeaveRequest.find({ studentEmail: email }).sort({ createdAt: -1 });
        res.status(200).json({ success: true, count: requests.length, requests: requests });
    } catch (error) { res.status(500).json({ success: false, message: 'Failed to fetch leave requests', error: error.message }); }
};

exports.getStaffLeaveRequests = async (req, res) => {
    try {
        const { department, year, section } = req.query;
        const query = {};
        if (department) query.department = department;
        if (year) query.year = year;
        if (section) query.section = section;
        const requests = await LeaveRequest.find(query).sort({ createdAt: -1 });
        res.status(200).json({ success: true, count: requests.length, data: requests });
    } catch (error) { res.status(500).json({ success: false, message: 'Failed to fetch leave requests', error: error.message }); }
};

exports.getHODLeaveRequests = async (req, res) => {
    try {
        const { department } = req.query;
        const query = { staffStatus: 'approved' };
        if (department) query.department = department;
        const requests = await LeaveRequest.find(query).sort({ createdAt: -1 });
        res.status(200).json({ success: true, count: requests.length, data: requests });
    } catch (error) { res.status(500).json({ success: false, message: 'Failed to fetch leave requests', error: error.message }); }
};

exports.updateStaffStatus = async (req, res) => {
    try {
        const { id } = req.params;
        const { status, rejectionReason, staffName, inchargeName, year, section } = req.body;
        let dbStatus = status === 'accepted' ? 'approved' : status;
        const leaveRequest = await LeaveRequest.findById(id);
        if (!leaveRequest) return res.status(404).json({ success: false, message: 'Leave request not found' });
        leaveRequest.staffStatus = dbStatus;
        leaveRequest.updatedAt = new Date().toISOString();
        if (dbStatus === 'rejected') {
            leaveRequest.status = 'rejected';
            leaveRequest.rejectedBy = 'staff';
            if (rejectionReason) { leaveRequest.rejectionReason = rejectionReason; leaveRequest.staffRemarks = rejectionReason; }
            try { await notifyStudentOnStatusChange(leaveRequest, 'Leave', 'rejected', 'staff'); } catch (e) { }
        } else if (dbStatus === 'approved') {
            if (staffName) leaveRequest.forwardedBy = staffName;
            if (inchargeName) leaveRequest.forwardedByIncharge = inchargeName;
            leaveRequest.forwardedAt = new Date().toISOString();
            if (year) leaveRequest.year = year;
            if (section) leaveRequest.section = section;
            leaveRequest.hodStatus = 'pending';
            leaveRequest.status = 'pending';
            try { await notifyHODOnForward(leaveRequest, 'Leave'); } catch (e) { }
            try { await notifyStudentOnStatusChange(leaveRequest, 'Leave', 'forwarded', 'staff'); } catch (e) { }
        }
        await leaveRequest.save();
        res.status(200).json({ success: true, message: `Leave request ${dbStatus} by staff`, data: leaveRequest });
    } catch (error) { res.status(500).json({ success: false, message: 'Update failed', error: error.message }); }
};

exports.updateHODStatus = async (req, res) => {
    try {
        const { id } = req.params;
        const { status, remarks } = req.body;
        const leaveRequest = await LeaveRequest.findById(id);
        if (!leaveRequest) return res.status(404).json({ success: false, message: 'Leave request not found' });
        leaveRequest.hodStatus = status;
        if (remarks) leaveRequest.hodRemarks = remarks;
        const isApproved = status && (status.toLowerCase() === 'approved' || status.toLowerCase() === 'accepted');
        if (isApproved) {
            leaveRequest.status = 'accepted';
            try { await generateLeavePDFHelper(leaveRequest); } catch (pdfError) { console.error('PDF Error:', pdfError); }
        } else if (status === 'rejected') {
            leaveRequest.status = 'rejected';
        }
        await leaveRequest.save();
        try { await notifyStudentOnStatusChange(leaveRequest, 'Leave', status, 'hod'); } catch (e) { }
        res.status(200).json({ success: true, message: `Leave request ${status} by HOD`, data: leaveRequest });
    } catch (error) { res.status(500).json({ success: false, message: 'Update failed', error: error.message }); }
};

exports.getLeaveRequest = async (req, res) => {
    try {
        const leaveRequest = await LeaveRequest.findById(req.params.id);
        if (!leaveRequest) return res.status(404).json({ success: false, message: 'Not found' });
        res.status(200).json({ success: true, data: leaveRequest });
    } catch (error) { res.status(500).json({ success: false, message: 'Fetch failed', error: error.message }); }
};

exports.getAllLeaveRequests = async (req, res) => {
    try {
        const { department, year, section, status } = req.query;
        const query = {};
        if (department) query.department = department;
        if (year) query.year = year;
        if (section) query.section = section;
        if (status) query.status = status;
        const requests = await LeaveRequest.find(query).sort({ createdAt: -1 });
        res.status(200).json({ success: true, count: requests.length, data: requests });
    } catch (error) { res.status(500).json({ success: false, message: 'Fetch failed', error: error.message }); }
};

exports.deleteLeaveRequest = async (req, res) => {
    try {
        const leaveRequest = await LeaveRequest.findByIdAndDelete(req.params.id);
        if (!leaveRequest) return res.status(404).json({ success: false, message: 'Not found' });
        res.status(200).json({ success: true, message: 'Deleted' });
    } catch (error) { res.status(500).json({ success: false, message: 'Delete failed', error: error.message }); }
};

exports.updateLeaveRequest = async (req, res) => {
    try {
        const { id } = req.params;
        const updateData = req.body;
        const existing = await LeaveRequest.findById(id);
        if (!existing) return res.status(404).json({ success: false, message: 'Not found' });
        if (existing.status !== 'pending' && existing.staffStatus !== 'pending') {
            return res.status(400).json({ success: false, message: 'Cannot edit processed request' });
        }
        const updates = { updatedAt: new Date().toISOString() };
        ['subject', 'content', 'reason', 'leaveType', 'fromDate', 'toDate', 'duration', 'image'].forEach(f => {
            if (updateData[f] !== undefined) updates[f] = updateData[f];
        });
        const leaveRequest = await LeaveRequest.findByIdAndUpdate(id, updates, { new: true });
        res.status(200).json({ success: true, message: 'Updated', data: leaveRequest });
    } catch (error) { res.status(500).json({ success: false, message: 'Update failed', error: error.message }); }
};

exports.verifyLeave = async (req, res) => {
    try {
        const { leaveId } = req.params;
        const leave = await LeaveRequest.findOne({ leaveId });
        if (!leave) return res.status(404).send('<h1 style="color:#ef4444;text-align:center;padding:50px;font-family:sans-serif;">INVALID DOCUMENT ❌<br><small style="color:#6b7280;">This record does not exist in the institutional database.</small></h1>');

        res.send(`
        <html>
        <head>
            <title>Secure Verification | Attendanzy</title>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body { font-family: 'Inter', -apple-system, sans-serif; background: #f9fafb; margin: 0; padding: 20px; color: #111827; }
                .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 20px; box-shadow: 0 20px 50px rgba(0,0,0,0.05); overflow: hidden; border: 1px solid #e5e7eb; }
                .banner { background: #059669; color: white; padding: 30px; text-align: center; }
                .banner h1 { margin: 0; font-size: 24px; letter-spacing: -0.5px; }
                .content { padding: 40px; }
                .status-badge { display: inline-flex; align-items: center; background: #ecfdf5; color: #059669; padding: 10px 20px; border-radius: 100px; font-weight: 700; font-size: 14px; margin-bottom: 30px; }
                .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 30px; }
                .field { margin-bottom: 25px; }
                .label { font-size: 12px; color: #6b7280; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 5px; }
                .value { font-size: 16px; font-weight: 500; color: #111827; }
                .footer { padding: 20px; background: #f3f4f6; text-align: center; font-size: 12px; color: #9ca3af; border-top: 1px solid #e5e7eb; }
                @media (max-width: 480px) { .grid { grid-template-columns: 1fr; gap: 15px; } }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="banner">
                    <h1>Agni College of Technology</h1>
                </div>
                <div class="content">
                    <div style="text-align: center;">
                        <div class="status-badge">✓ OFFICIALLY VERIFIED LEAVE RECORD</div>
                    </div>
                    <div class="grid">
                        <div class="field"><div class="label">Reference ID</div><div class="value">${leave.leaveId}</div></div>
                        <div class="field"><div class="label">Date Issued</div><div class="value">${new Date(leave.updatedAt).toLocaleDateString()}</div></div>
                        <div class="field"><div class="label">Student Name</div><div class="value">${leave.studentName}</div></div>
                        <div class="field"><div class="label">Register No</div><div class="value">${leave.studentEmail.split('@')[0].toUpperCase()}</div></div>
                        <div class="field"><div class="label">Leave Duration</div><div class="value">${leave.duration} Day(s)</div></div>
                        <div class="field"><div class="label">Valid Dates</div><div class="value">${leave.fromDate} to ${leave.toDate}</div></div>
                        <div class="field" style="grid-column: 1 / -1;"><div class="label">Verified By</div><div class="value">HOD, Dept of ${leave.department}</div></div>
                    </div>
                </div>
                <div class="footer">Attendanzy Secure Document Verification Gateway | ACT-Portal</div>
            </div>
        </body>
        </html>
        `);
    } catch (e) { res.status(500).send("Verification Gateway Error"); }
};

exports.downloadLeavePDF = async (req, res) => {
    try {
        let { id } = req.params;
        if (id && id.includes('ObjectId("')) id = id.match(/ObjectId\("([0-9a-fA-F]+)"\)/)[1];
        else if (id && id.startsWith('"')) id = id.slice(1, -1);
        const leave = await LeaveRequest.findById(id);
        if (!leave) return res.status(404).json({ success: false, message: 'Not found' });

        if (leave.status === 'accepted') {
            await generateLeavePDFHelper(leave);
        } else if (!leave.leaveId || !fs.existsSync(path.join(__dirname, '../letters', `${leave.leaveId}.pdf`))) {
            return res.status(404).json({ success: false, message: 'PDF not available' });
        }

        res.download(path.join(__dirname, '../letters', `${leave.leaveId}.pdf`), `Leave_${leave.studentName.replace(/\s+/g, '_')}.pdf`);
    } catch (error) { res.status(500).json({ success: false, message: 'Download failed', error: error.message }); }
};
