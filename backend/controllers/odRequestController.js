const ODRequest = require('../models/ODRequest');
const { notifyStaffOnNewRequest, notifyHODOnForward, notifyStudentOnStatusChange, notifyStaffOnHODDecision } = require('../services/notificationService');
const QRCode = require('qrcode');
const PDFDocument = require('pdfkit');
const fs = require('fs');
const path = require('path');

/**
 * Helper to generate Secure OD ID and PDF (Exact Image Match Layout)
 */
const generateODPDFHelper = async (odRequest) => {
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

    const qrBuffer = await QRCode.toBuffer(verificationUrl, { margin: 1, width: 250 });

    const lettersDir = path.join(__dirname, '../letters');
    if (!fs.existsSync(lettersDir)) {
        fs.mkdirSync(lettersDir, { recursive: true });
    }

    const pdfPath = path.join(lettersDir, `${odId}.pdf`);
    if (fs.existsSync(pdfPath)) {
        try { fs.unlinkSync(pdfPath); } catch (e) { }
    }

    const doc = new PDFDocument({ margin: 40, size: 'A4' });
    const stream = fs.createWriteStream(pdfPath);
    doc.pipe(stream);

    const logoPath = path.join(__dirname, '../assets/logo.jpg');

    // --- Header Section ---
    if (fs.existsSync(logoPath)) {
        doc.image(logoPath, 50, 45, { width: 70 });
    }

    doc.fillColor('#1F2937').font('Helvetica-Bold').fontSize(18).text('AGNI COLLEGE OF TECHNOLOGY', 130, 60);
    doc.font('Helvetica-Bold').fontSize(8.5).text('An Autonomous Institution | Affiliated to Anna University', 130, 82, { align: 'center', width: 400 });
    doc.font('Helvetica').fontSize(8.5).text('OMR, Thalambur, Chennai - 603103', 130, 94, { align: 'center', width: 400 });

    doc.strokeColor('#D1D5DB').lineWidth(0.5).moveTo(50, 52).lineTo(545, 52).stroke();
    doc.strokeColor('#D1D5DB').lineWidth(1.5).moveTo(50, 115).lineTo(545, 115).stroke();
    doc.strokeColor('#D1D5DB').lineWidth(0.5).moveTo(50, 119).lineTo(545, 119).stroke();

    // --- Title ---
    doc.y = 135;
    doc.fillColor('#111827').font('Helvetica-Bold').fontSize(14).text('STUDENT OD APPROVAL MEMORANDUM', 50, 135, { align: 'center' });

    // --- Data Table ---
    const tableTop = 165;
    const col1Width = 130;
    const tableWidth = 495;
    const rowHeight = 22;
    const rows = [
        ['Reference ID:', odId],
        ['Student Name:', odRequest.studentName],
        ['Register Number:', odRequest.studentEmail.split('@')[0].toUpperCase()],
        ['Department:', odRequest.department],
        ['Year / Section:', `${odRequest.year} / ${odRequest.section}`],
        ['Activity / Sub:', odRequest.subject],
        ['Activity Period:', `${odRequest.from} to ${odRequest.to}`],
        ['Status Title:', 'Official On-Duty (OD)']
    ];

    rows.forEach((row, i) => {
        const y = tableTop + (i * rowHeight);
        doc.fillColor('#F9FAFB').rect(50, y, col1Width, rowHeight).fill();
        doc.strokeColor('#D1D5DB').lineWidth(0.5).rect(50, y, tableWidth, rowHeight).stroke();
        doc.fillColor('#374151').font('Helvetica').fontSize(10).text(row[0], 65, y + 7);
        doc.fillColor('#111827').font('Helvetica-Bold').fontSize(10).text(row[1], 50 + col1Width + 15, y + 7);
    });

    // --- Reason Section ---
    const reasonTop = tableTop + (rows.length * rowHeight) + 25;
    doc.strokeColor('#D1D5DB').lineWidth(0.5).dash(2, { space: 2 }).moveTo(50, reasonTop).lineTo(180, reasonTop).stroke().undash();
    doc.fillColor('#4B5563').font('Helvetica-BoldOblique').fontSize(10).text('Reason for On-Duty', 185, reasonTop - 5, { width: 175, align: 'center' });
    doc.strokeColor('#D1D5DB').lineWidth(0.5).dash(2, { space: 2 }).moveTo(365, reasonTop).lineTo(545, reasonTop).stroke().undash();

    const reasonBoxY = reasonTop + 15;
    const reasonContent = odRequest.content || odRequest.reason || 'No specific reason provided.';

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

    const textStartX = 65;
    const labelWidth = 110;

    doc.fillColor('#4B5563').font('Helvetica').fontSize(10).text('Staff Forwarded By:', textStartX, approvalBoxY + 20);
    doc.fillColor('#111827').font('Helvetica-Bold').fontSize(11).text(odRequest.forwardedBy || 'Department Staff', textStartX + labelWidth, approvalBoxY + 20);

    doc.fillColor('#4B5563').font('Helvetica').fontSize(10).text('HOD Status:', textStartX, approvalBoxY + 50);
    doc.fillColor('#2563EB').font('Helvetica-Bold').fontSize(22).text('APPROVED', textStartX + labelWidth, approvalBoxY + 45, { underline: true });

    doc.fillColor('#4B5563').font('Helvetica').fontSize(10).text('Approved Timestamp:', textStartX, approvalBoxY + 80);
    doc.fillColor('#111827').font('Helvetica').fontSize(10).text(new Date().toLocaleString('en-IN', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' }), textStartX + labelWidth, approvalBoxY + 80);

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
            odRequest.pdfUrl = `${baseUrl}/api/od-requests/${odRequest._id}/download`;
            resolve({ odId, pdfPath, verificationUrl });
        });
        stream.on('error', reject);
    });
};

// --- API Methods ---

exports.submitODRequest = async (req, res) => {
    try {
        const { studentName, studentEmail, from, to, subject, content, image, department, year, section } = req.body;
        if (!studentName || !studentEmail || !from || !to || !subject || !content || !department || !year || !section) {
            return res.status(400).json({ success: false, message: 'Please provide all required fields' });
        }
        const odRequest = new ODRequest({ studentName, studentEmail, from, to, subject, content, image: image || '', department, year, section, staffStatus: 'pending', hodStatus: 'pending', status: 'pending', createdAt: new Date().toISOString() });
        await odRequest.save();
        try { await notifyStaffOnNewRequest(odRequest, 'OD'); } catch (notifError) { console.error('Notification error:', notifError); }
        res.status(201).json({ success: true, message: 'OD request submitted successfully', data: odRequest });
    } catch (error) { res.status(500).json({ success: false, message: 'Submission failed', error: error.message }); }
};

exports.getStudentODRequests = async (req, res) => {
    try {
        const { email } = req.params;
        const requests = await ODRequest.find({ studentEmail: email }).sort({ createdAt: -1 });
        res.status(200).json({ success: true, count: requests.length, requests: requests });
    } catch (error) { res.status(500).json({ success: false, message: 'Fetch failed', error: error.message }); }
};

exports.getStaffODRequests = async (req, res) => {
    try {
        const { department, year, section } = req.query;
        const query = {};
        if (department) query.department = department;
        if (year) query.year = year;
        if (section) query.section = section;
        const requests = await ODRequest.find(query).sort({ createdAt: -1 });
        res.status(200).json({ success: true, count: requests.length, data: requests });
    } catch (error) { res.status(500).json({ success: false, message: 'Fetch failed', error: error.message }); }
};

exports.getHODODRequests = async (req, res) => {
    try {
        const { department } = req.query;
        const query = { staffStatus: 'approved' };
        if (department) query.department = department;
        const requests = await ODRequest.find(query).sort({ createdAt: -1 });
        res.status(200).json({ success: true, count: requests.length, data: requests });
    } catch (error) { res.status(500).json({ success: false, message: 'Fetch failed', error: error.message }); }
};

exports.updateStaffStatus = async (req, res) => {
    try {
        const { id } = req.params;
        const { status, rejectionReason, staffName, inchargeName, year, section } = req.body;
        let dbStatus = status === 'accepted' ? 'approved' : status;
        const odRequest = await ODRequest.findById(id);
        if (!odRequest) return res.status(404).json({ success: false, message: 'Not found' });
        odRequest.staffStatus = dbStatus;
        odRequest.updatedAt = new Date().toISOString();
        if (staffName) odRequest.staffName = staffName;
        if (dbStatus === 'rejected') {
            odRequest.status = 'rejected';
            odRequest.rejectedBy = 'staff';
            if (rejectionReason) { odRequest.rejectionReason = rejectionReason; odRequest.staffRemarks = rejectionReason; }
            try { await notifyStudentOnStatusChange(odRequest, 'OD', 'rejected', 'staff'); } catch (e) { }
        } else if (dbStatus === 'approved') {
            if (staffName) odRequest.forwardedBy = staffName;
            if (inchargeName) odRequest.forwardedByIncharge = inchargeName;
            odRequest.forwardedAt = new Date().toISOString();
            if (year) odRequest.year = year;
            if (section) odRequest.section = section;
            odRequest.hodStatus = 'pending';
            odRequest.status = 'pending';
            try { await notifyHODOnForward(odRequest, 'OD'); } catch (e) { }
            try { await notifyStudentOnStatusChange(odRequest, 'OD', 'forwarded', 'staff'); } catch (e) { }
        }
        await odRequest.save();
        res.status(200).json({ success: true, message: `Updated`, data: odRequest });
    } catch (error) { res.status(500).json({ success: false, message: 'Update failed', error: error.message }); }
};

exports.updateHODStatus = async (req, res) => {
    try {
        const { id } = req.params;
        const { status, remarks } = req.body;
        const odRequest = await ODRequest.findById(id);
        if (!odRequest) return res.status(404).json({ success: false, message: 'Not found' });
        odRequest.hodStatus = status;
        if (remarks) odRequest.hodRemarks = remarks;
        const isApproved = status && (status.toLowerCase() === 'approved' || status.toLowerCase() === 'accepted');
        if (isApproved) {
            odRequest.status = 'accepted';
            try { await generateODPDFHelper(odRequest); } catch (pdfError) { console.error('PDF Error:', pdfError); }
        } else if (status === 'rejected') {
            odRequest.status = 'rejected';
        }
        await odRequest.save();
        try { await notifyStudentOnStatusChange(odRequest, 'OD', status, 'hod'); } catch (e) { }
        res.status(200).json({ success: true, message: `Updated`, data: odRequest });
    } catch (error) { res.status(500).json({ success: false, message: 'Update failed', error: error.message }); }
};

exports.getODRequest = async (req, res) => {
    try {
        const odRequest = await ODRequest.findById(req.params.id);
        if (!odRequest) return res.status(404).json({ success: false, message: 'Not found' });
        res.status(200).json({ success: true, data: odRequest });
    } catch (error) { res.status(500).json({ success: false, message: 'Fetch failed', error: error.message }); }
};

exports.getAllODRequests = async (req, res) => {
    try {
        const { department, year, section, status } = req.query;
        const query = {};
        if (department) query.department = department;
        if (year) query.year = year;
        if (section) query.section = section;
        if (status) query.status = status;
        const requests = await ODRequest.find(query).sort({ createdAt: -1 });
        res.status(200).json({ success: true, count: requests.length, data: requests });
    } catch (error) { res.status(500).json({ success: false, message: 'Fetch failed', error: error.message }); }
};

exports.deleteODRequest = async (req, res) => {
    try {
        const odRequest = await ODRequest.findByIdAndDelete(req.params.id);
        if (!odRequest) return res.status(404).json({ success: false, message: 'Not found' });
        res.status(200).json({ success: true, message: 'Deleted' });
    } catch (error) { res.status(500).json({ success: false, message: 'Delete failed', error: error.message }); }
};

exports.updateODRequest = async (req, res) => {
    try {
        const { id } = req.params;
        const updateData = req.body;
        const existing = await ODRequest.findById(id);
        if (!existing) return res.status(404).json({ success: false, message: 'Not found' });
        if (existing.status !== 'pending' && existing.staffStatus !== 'pending') return res.status(400).json({ success: false, message: 'Cannot edit' });
        const updates = { updatedAt: new Date().toISOString() };
        ['subject', 'content', 'from', 'to', 'image'].forEach(f => { if (updateData[f] !== undefined) updates[f] = updateData[f]; });
        const odRequest = await ODRequest.findByIdAndUpdate(id, updates, { new: true });
        res.status(200).json({ success: true, message: 'Updated', data: odRequest });
    } catch (error) { res.status(500).json({ success: false, message: 'Update failed', error: error.message }); }
};

exports.verifyOD = async (req, res) => {
    try {
        const { odId } = req.params;
        const od = await ODRequest.findOne({ odId });
        if (!od) return res.status(404).send('<h1 style="color:#ef4444;text-align:center;padding:50px;font-family:sans-serif;">INVALID RECORD ❌</h1>');
        res.send(`<html><head><title>Verify</title><meta name="viewport" content="width=device-width, initial-scale=1.0"><style>body{font-family:sans-serif;background:#f9fafb;margin:0;padding:20px;}.container{max-width:500px;margin:0 auto;background:white;border-radius:15px;box-shadow:0 10px 30px rgba(0,0,0,0.05);overflow:hidden;border:1px solid #e5e7eb;}.header{background:#2563EB;color:white;padding:20px;text-align:center;}.content{padding:30px;}.field{margin-bottom:15px;}.label{font-size:11px;color:#6b7280;text-transform:uppercase;font-weight:bold;}.value{font-size:15px;color:#111827;}</style></head><body><div class="container"><div class="header"><h3>ACT Verification Portal</h3></div><div class="content"><div style="text-align:center;margin-bottom:20px;color:#2563EB;font-weight:bold;">✓ VALID OD RECORD</div><div class="field"><div class="label">ID</div><div class="value">${od.odId}</div></div><div class="field"><div class="label">Student</div><div class="value">${od.studentName}</div></div><div class="field"><div class="label">Activity</div><div class="value">${od.subject}</div></div><div class="field"><div class="label">Dates</div><div class="value">${od.from} to ${od.to}</div></div></div><div style="text-align:center;padding:15px;background:#f3f4f6;font-size:10px;color:#9ca3af;">Attendanzy Institutional Security</div></div></body></html>`);
    } catch (e) { res.status(500).send("Error"); }
};

exports.downloadODPDF = async (req, res) => {
    try {
        let { id } = req.params;
        if (id && id.includes('ObjectId("')) id = id.match(/ObjectId\("([0-9a-fA-F]+)"\)/)[1];
        else if (id && id.startsWith('"')) id = id.slice(1, -1);
        const od = await ODRequest.findById(id);
        if (!od) return res.status(404).json({ success: false, message: 'Not found' });
        if (od.status === 'accepted') await generateODPDFHelper(od);
        res.download(path.join(__dirname, '../letters', `${od.odId}.pdf`), `OD_${od.studentName.replace(/\s+/g, '_')}.pdf`);
    } catch (error) { res.status(500).json({ success: false, message: 'Download failed', error: error.message }); }
};
