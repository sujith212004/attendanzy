const LeaveRequest = require('../models/LeaveRequest');
const { notifyStaffOnNewRequest, notifyHODOnForward, notifyStudentOnStatusChange, notifyStaffOnHODDecision } = require('../services/notificationService');
const QRCode = require('qrcode');
const PDFDocument = require('pdfkit');
const fs = require('fs');
const path = require('path');

/**
 * Helper to generate Secure Leave ID and PDF (Exact Image Match Layout)
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

    const qrBuffer = await QRCode.toBuffer(verificationUrl, { margin: 1, width: 250 });

    const lettersDir = path.join(__dirname, '../letters');
    if (!fs.existsSync(lettersDir)) {
        fs.mkdirSync(lettersDir, { recursive: true });
    }

    const pdfPath = path.join(lettersDir, `${leaveId}.pdf`);
    if (fs.existsSync(pdfPath)) {
        try { fs.unlinkSync(pdfPath); } catch (e) { }
    }

    const doc = new PDFDocument({ margin: 40, size: 'A4' });
    const stream = fs.createWriteStream(pdfPath);
    doc.pipe(stream);

    const logoPath = path.join(__dirname, '../assets/logo.jpg');

    // --- Header Section (Matching Image) ---
    if (fs.existsSync(logoPath)) {
        doc.image(logoPath, 50, 45, { width: 70 });
    }

    doc.fillColor('#1F2937').font('Helvetica-Bold').fontSize(18).text('AGNI COLLEGE OF TECHNOLOGY', 130, 60);
    doc.font('Helvetica-Bold').fontSize(8.5).text('An Autonomous Institution | Affiliated to Anna University', 130, 82, { align: 'center', width: 400 });
    doc.font('Helvetica').fontSize(8.5).text('OMR, Thalambur, Chennai - 603103', 130, 94, { align: 'center', width: 400 });

    // Double lines below header
    doc.strokeColor('#D1D5DB').lineWidth(0.5).moveTo(50, 52).lineTo(545, 52).stroke();
    doc.strokeColor('#D1D5DB').lineWidth(1.5).moveTo(50, 115).lineTo(545, 115).stroke();
    doc.strokeColor('#D1D5DB').lineWidth(0.5).moveTo(50, 119).lineTo(545, 119).stroke();

    // --- Title ---
    doc.y = 135;
    doc.fillColor('#111827').font('Helvetica-Bold').fontSize(14).text('STUDENT LEAVE APPROVAL MEMORANDUM', 50, 135, { align: 'center' });

    // --- Data Table (Grid) ---
    const tableTop = 165;
    const col1Width = 130;
    const tableWidth = 495;
    const rowHeight = 22;
    const rows = [
        ['Reference ID:', leaveId],
        ['Student Name:', leaveRequest.studentName],
        ['Register Number:', leaveRequest.studentEmail.split('@')[0].toUpperCase()],
        ['Department:', leaveRequest.department],
        ['Year / Section:', `${leaveRequest.year} / ${leaveRequest.section}`],
        ['Leave Type:', leaveRequest.leaveType],
        ['Leave Period:', `${leaveRequest.fromDate} to ${leaveRequest.toDate}`],
        ['Total Days:', `${leaveRequest.duration} Day(s)`]
    ];

    rows.forEach((row, i) => {
        const y = tableTop + (i * rowHeight);

        // Background for labels
        doc.fillColor('#F9FAFB').rect(50, y, col1Width, rowHeight).fill();

        // Borders
        doc.strokeColor('#D1D5DB').lineWidth(0.5)
            .rect(50, y, tableWidth, rowHeight).stroke();

        // Text
        doc.fillColor('#374151').font('Helvetica').fontSize(10).text(row[0], 65, y + 7);
        doc.fillColor('#111827').font('Helvetica-Bold').fontSize(10).text(row[1], 50 + col1Width + 15, y + 7);
    });

    // --- Reason Section ---
    const reasonTop = tableTop + (rows.length * rowHeight) + 25;
    doc.strokeColor('#D1D5DB').lineWidth(0.5).dash(2, { space: 2 }).moveTo(50, reasonTop).lineTo(180, reasonTop).stroke().undash();
    doc.fillColor('#4B5563').font('Helvetica-BoldOblique').fontSize(10).text('Reason for Leave', 185, reasonTop - 5, { width: 175, align: 'center' });
    doc.strokeColor('#D1D5DB').lineWidth(0.5).dash(2, { space: 2 }).moveTo(365, reasonTop).lineTo(545, reasonTop).stroke().undash();

    const reasonBoxY = reasonTop + 15;
    const reasonContent = leaveRequest.content || leaveRequest.reason || 'No specific reason provided.';

    doc.strokeColor('#9CA3AF').lineWidth(0.5).rect(50, reasonBoxY, tableWidth, 50).stroke();
    doc.strokeColor('#E5E7EB').lineWidth(1).rect(55, reasonBoxY + 5, tableWidth - 10, 40).stroke();
    doc.fillColor('#111827').font('Helvetica').fontSize(10.5).text(reasonContent, 65, reasonBoxY + 18, { width: 465, align: 'center' });

    // --- Digital Approval Workflow ---
    const approvalTop = reasonBoxY + 75;
    doc.strokeColor('#D1D5DB').lineWidth(0.5).dash(2, { space: 2 }).moveTo(50, approvalTop).lineTo(150, approvalTop).stroke().undash();
    doc.fillColor('#4B5563').font('Helvetica-Bold').fontSize(10).text('DIGITAL APPROVAL WORKFLOW', 155, approvalTop - 5, { width: 235, align: 'center' });
    doc.strokeColor('#D1D5DB').lineWidth(0.5).dash(2, { space: 2 }).moveTo(395, approvalTop).lineTo(545, approvalTop).stroke().undash();

    const approvalBoxY = approvalTop + 15;
    const approvalBoxHeight = 100;
    doc.strokeColor('#D1D5DB').lineWidth(0.5).rect(50, approvalBoxY, tableWidth, approvalBoxHeight).stroke();

    // Approval Text Section
    const textStartX = 65;
    const labelWidth = 110;

    doc.fillColor('#4B5563').font('Helvetica').fontSize(10).text('Staff Forwarded By:', textStartX, approvalBoxY + 20);
    doc.fillColor('#111827').font('Helvetica-Bold').fontSize(11).text(leaveRequest.forwardedBy || 'Department Staff', textStartX + labelWidth, approvalBoxY + 20);

    doc.fillColor('#4B5563').font('Helvetica').fontSize(10).text('HOD Status:', textStartX, approvalBoxY + 50);
    doc.fillColor('#059669').font('Helvetica-Bold').fontSize(22).text('APPROVED', textStartX + labelWidth, approvalBoxY + 45, { underline: true });

    doc.fillColor('#4B5563').font('Helvetica').fontSize(10).text('Approved Timestamp:', textStartX, approvalBoxY + 80);
    doc.fillColor('#111827').font('Helvetica').fontSize(10).text(new Date().toLocaleString('en-IN', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' }), textStartX + labelWidth, approvalBoxY + 80);

    // QR Code Section (Vertical line and QR)
    doc.strokeColor('#D1D5DB').lineWidth(0.5).moveTo(430, approvalBoxY).lineTo(430, approvalBoxY + approvalBoxHeight).stroke();

    try {
        doc.image(qrBuffer, 445, approvalBoxY + 10, { width: 85 });
        doc.fillColor('#6B7280').font('Helvetica-Oblique').fontSize(8).text('Scan to Verify', 445, approvalBoxY + 82, { width: 85, align: 'center' });
    } catch (e) { }

    // --- Footer ---
    doc.y = 780;
    doc.strokeColor('#D1D5DB').lineWidth(0.5).dash(1, { space: 1 }).moveTo(70, 785).lineTo(150, 785).stroke().undash();
    doc.fillColor('#6B7280').font('Helvetica').fontSize(7.5).text(`Secure Verification URL: ${verificationUrl}`, 155, 782, { width: 320, align: 'center' });
    doc.strokeColor('#D1D5DB').lineWidth(0.5).dash(1, { space: 1 }).moveTo(480, 785).lineTo(540, 785).stroke().undash();

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
    } catch (error) { res.status(500).json({ success: false, message: 'Failed to submit', error: error.message }); }
};

exports.getStudentLeaveRequests = async (req, res) => {
    try {
        const { email } = req.params;
        const requests = await LeaveRequest.find({ studentEmail: email }).sort({ createdAt: -1 });
        res.status(200).json({ success: true, count: requests.length, requests: requests });
    } catch (error) { res.status(500).json({ success: false, message: 'Failed to fetch', error: error.message }); }
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
    } catch (error) { res.status(500).json({ success: false, message: 'Failed to fetch', error: error.message }); }
};

exports.getHODLeaveRequests = async (req, res) => {
    try {
        const { department } = req.query;
        const query = { staffStatus: 'approved' };
        if (department) query.department = department;
        const requests = await LeaveRequest.find(query).sort({ createdAt: -1 });
        res.status(200).json({ success: true, count: requests.length, data: requests });
    } catch (error) { res.status(500).json({ success: false, message: 'Failed to fetch', error: error.message }); }
};

exports.updateStaffStatus = async (req, res) => {
    try {
        const { id } = req.params;
        const { status, rejectionReason, staffName, inchargeName, year, section } = req.body;
        let dbStatus = status === 'accepted' ? 'approved' : status;
        const leaveRequest = await LeaveRequest.findById(id);
        if (!leaveRequest) return res.status(404).json({ success: false, message: 'Not found' });
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
        res.status(200).json({ success: true, message: `Updated`, data: leaveRequest });
    } catch (error) { res.status(500).json({ success: false, message: 'Update failed', error: error.message }); }
};

exports.updateHODStatus = async (req, res) => {
    try {
        const { id } = req.params;
        const { status, remarks } = req.body;
        const leaveRequest = await LeaveRequest.findById(id);
        if (!leaveRequest) return res.status(404).json({ success: false, message: 'Not found' });
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
        res.status(200).json({ success: true, message: `Updated`, data: leaveRequest });
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
        if (existing.status !== 'pending' && existing.staffStatus !== 'pending') return res.status(400).json({ success: false, message: 'Cannot edit' });
        const updates = { updatedAt: new Date().toISOString() };
        ['subject', 'content', 'reason', 'leaveType', 'fromDate', 'toDate', 'duration', 'image'].forEach(f => { if (updateData[f] !== undefined) updates[f] = updateData[f]; });
        const leaveRequest = await LeaveRequest.findByIdAndUpdate(id, updates, { new: true });
        res.status(200).json({ success: true, message: 'Updated', data: leaveRequest });
    } catch (error) { res.status(500).json({ success: false, message: 'Update failed', error: error.message }); }
};

exports.verifyLeave = async (req, res) => {
    try {
        const { leaveId } = req.params;
        const leave = await LeaveRequest.findOne({ leaveId });
        if (!leave) return res.status(404).send('<h1 style="color:#ef4444;text-align:center;padding:50px;font-family:sans-serif;">INVALID RECORD ❌</h1>');
        res.send(`<html><head><title>Verify</title><meta name="viewport" content="width=device-width, initial-scale=1.0"><style>body{font-family:sans-serif;background:#f9fafb;margin:0;padding:20px;}.container{max-width:500px;margin:0 auto;background:white;border-radius:15px;box-shadow:0 10px 30px rgba(0,0,0,0.05);overflow:hidden;border:1px solid #e5e7eb;}.header{background:#059669;color:white;padding:20px;text-align:center;}.content{padding:30px;}.field{margin-bottom:15px;}.label{font-size:11px;color:#6b7280;text-transform:uppercase;font-weight:bold;}.value{font-size:15px;color:#111827;}</style></head><body><div class="container"><div class="header"><h3>ACT Verification Portal</h3></div><div class="content"><div style="text-align:center;margin-bottom:20px;color:#059669;font-weight:bold;">✓ VALID LEAVE RECORD</div><div class="field"><div class="label">ID</div><div class="value">${leave.leaveId}</div></div><div class="field"><div class="label">Student</div><div class="value">${leave.studentName}</div></div><div class="field"><div class="label">Duration</div><div class="value">${leave.duration} Day(s)</div></div><div class="field"><div class="label">Dates</div><div class="value">${leave.fromDate} to ${leave.toDate}</div></div></div><div style="text-align:center;padding:15px;background:#f3f4f6;font-size:10px;color:#9ca3af;">Attendanzy Institutional Security</div></div></body></html>`);
    } catch (e) { res.status(500).send("Error"); }
};

exports.downloadLeavePDF = async (req, res) => {
    try {
        let { id } = req.params;
        if (id && id.includes('ObjectId("')) id = id.match(/ObjectId\("([0-9a-fA-F]+)"\)/)[1];
        else if (id && id.startsWith('"')) id = id.slice(1, -1);
        const leave = await LeaveRequest.findById(id);
        if (!leave) return res.status(404).json({ success: false, message: 'Not found' });
        if (leave.status === 'accepted') await generateLeavePDFHelper(leave);
        res.download(path.join(__dirname, '../letters', `${leave.leaveId}.pdf`), `Leave_${leave.studentName.replace(/\s+/g, '_')}.pdf`);
    } catch (error) { res.status(500).json({ success: false, message: 'Download failed', error: error.message }); }
};
