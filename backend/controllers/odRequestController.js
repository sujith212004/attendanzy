const ODRequest = require('../models/ODRequest');
const { notifyStaffOnNewRequest, notifyHODOnForward, notifyStudentOnStatusChange, notifyStaffOnHODDecision } = require('../services/notificationService');
const QRCode = require('qrcode');
const PDFDocument = require('pdfkit');
const fs = require('fs');
const path = require('path');

/**
 * Helper to generate Secure OD ID and PDF (Strict One-Page Memorandum Style)
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

    const qrBuffer = await QRCode.toBuffer(verificationUrl, { margin: 1, width: 200 });

    const lettersDir = path.join(__dirname, '../letters');
    if (!fs.existsSync(lettersDir)) {
        fs.mkdirSync(lettersDir, { recursive: true });
    }

    const pdfPath = path.join(lettersDir, `${odId}.pdf`);
    const doc = new PDFDocument({ margin: 50, size: 'A4' });
    const stream = fs.createWriteStream(pdfPath);
    doc.pipe(stream);

    const textColor = '#000000';
    const accentColor = '#2563EB'; // Blue for OD
    const logoPath = path.join(__dirname, '../assets/logo.jpg');

    // --- Background Watermark ---
    if (fs.existsSync(logoPath)) {
        doc.save();
        doc.opacity(0.1);
        doc.image(logoPath, 150, 300, { width: 300 });
        doc.restore();
    }

    // --- Institutional Letterhead (Top Header) ---
    if (fs.existsSync(logoPath)) {
        doc.image(logoPath, 50, 45, { width: 55 });
    }

    doc.fillColor(textColor).font('Helvetica-Bold').fontSize(16).text('AGNI COLLEGE OF TECHNOLOGY', 115, 45);
    doc.font('Helvetica-Bold').fontSize(8).text('An AUTONOMOUS Institution | ISO 9001:2015 Certified', 115, 62);
    doc.font('Helvetica').fontSize(8).text('Affiliated to Anna University | Approved by AICTE', 115, 72);
    doc.text('OMR, Thalambur, Chennai - 603 103, Tamil Nadu, India', 115, 82);
    doc.strokeColor('#333333').lineWidth(1).moveTo(50, 105).lineTo(545, 105).stroke();

    doc.y = 120;
    const today = new Date().toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
    doc.font('Helvetica-Bold').fontSize(9).text(`Ref: ACT/OD/${odId}`, 50, 120);
    doc.text(`Date: ${today}`, 450, 120, { align: 'right' });

    doc.moveDown(3);
    doc.font('Helvetica-Bold').fontSize(10).text('From,', 50);
    doc.font('Helvetica').fontSize(10);
    doc.text(`${odRequest.studentName.toUpperCase()},`, 70);
    doc.text(`${odRequest.studentEmail.split('@')[0].toUpperCase()}, ${odRequest.year} Year / ${odRequest.section},`, 70);
    doc.text(`Department of ${odRequest.department || 'Engineering'}, Agni College of Technology.`, 70);

    doc.moveDown(2);
    doc.font('Helvetica-Bold').fontSize(10).text('To,', 50);
    doc.font('Helvetica').fontSize(10);
    doc.text('The Head of Department,', 70);
    doc.text(`Department of ${odRequest.department || 'Engineering'}, Agni College of Technology.`, 70);

    doc.moveDown(2);
    doc.font('Helvetica-Bold').fontSize(10).text('Through:', 50);
    doc.font('Helvetica').fontSize(10).text('The Class In-charge / Staff Advisor.', 70);

    doc.moveDown(3);
    doc.font('Helvetica-Bold').fontSize(10).text(`Subject: Official Request for On-Duty (OD) Authorization - Regarding.`, 50, doc.y, { underline: true });

    doc.moveDown(3.5);
    doc.font('Helvetica').fontSize(11).text('Respected Sir/Madam,', 50);
    doc.moveDown(1.5);
    const bodyContent = `I am writing this to formally request your authorization for On-Duty (OD) status from ${odRequest.from} to ${odRequest.to} to participate in ${odRequest.subject}. I have provided the detailed activity description below.`;
    doc.text(bodyContent, 50, doc.y, { align: 'justify', lineGap: 4 });

    doc.moveDown(1.5);
    doc.font('Helvetica-Bold').fontSize(10).text('Activity Description / Detailed Purpose:', 50);
    doc.font('Helvetica').fontSize(10).text(odRequest.content || odRequest.reason || 'N/A', 60, doc.y + 4, { width: 485, align: 'justify', lineGap: 2 });

    doc.moveDown(3.5);
    doc.text('I request you to kindly grant me permission for the same as it is part of an official academic/professional activity.', 50, doc.y, { align: 'justify' });
    doc.moveDown(2.5);
    doc.text('Thanking you,', 50);
    doc.moveDown(4);
    doc.font('Helvetica-Bold').text('Yours obediently,', 400);
    doc.text(odRequest.studentName.toUpperCase(), 400);

    const bottomBlockY = 670;
    doc.strokeColor('#666666').lineWidth(0.5).dash(5, { space: 3 }).moveTo(50, bottomBlockY - 15).lineTo(545, bottomBlockY - 15).stroke().undash();
    doc.fillColor(accentColor).font('Helvetica-Bold').fontSize(11).text('■ OFFICIAL OD AUTHORIZATION', 50, bottomBlockY);
    doc.y = bottomBlockY + 25;
    doc.fillColor(textColor).font('Helvetica').fontSize(9).text('The above request has been verified and authorized by the department officials through the Attendanzy Secure System.', 50);
    doc.moveDown(0.5);
    doc.font('Helvetica-Bold').fontSize(8);
    doc.text(`- STAFF APPROVAL: Forwarded by ${odRequest.forwardedBy || 'Department Staff'}`, 60);
    doc.text(`- HOD APPROVAL: Officially Authorized by Head of Department`, 60);
    doc.text(`- TIMESTAMP: ${new Date().toLocaleString('en-IN')}`, 60);

    try {
        doc.image(qrBuffer, 460, bottomBlockY + 15, { width: 75 });
        doc.fillColor('#666666').font('Helvetica').fontSize(6).text('SCAN TO VERIFY', 460, bottomBlockY + 92, { width: 75, align: 'center' });
    } catch (e) { }

    doc.strokeColor('#EEEEEE').lineWidth(0.5).moveTo(50, 785).lineTo(545, 785).stroke();
    doc.fillColor('#999999').font('Helvetica').fontSize(7).text('This is an official system-generated document. Verification URL: ' + verificationUrl, 50, 792, { width: 495, align: 'center' });

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
        res.status(200).json({ success: true, message: `Updated by staff`, data: odRequest });
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
        res.status(200).json({ success: true, message: `Updated by HOD`, data: odRequest });
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
        if (!od) return res.status(404).send('<h1 style="color:red;text-align:center;">INVALID DOCUMENT ❌</h1>');
        res.send(`<html><head><title>Verify</title><meta name="viewport" content="width=device-width, initial-scale=1.0"><style>body{font-family:sans-serif;background:#f0f4f8;padding:20px;}.card{max-width:500px;margin:0 auto;background:white;padding:30px;border-radius:15px;box-shadow:0 10px 25px rgba(0,0,0,0.1); border-top: 5px solid #2563EB;}.header{text-align:center;border-bottom:1px solid #eee;margin-bottom:20px;}.status{display:inline-block;padding:8px 15px;border-radius:50px;background:#e0f2fe;color:#2563EB;font-weight:bold;margin-bottom:20px;}.field{margin-bottom:12px;}.label{font-size:11px;color:#888;text-transform:uppercase;}.value{font-size:15px;font-weight:500;}</style></head><body><div class="card"><div class="header"><h2>OD Verification</h2><p>Ref: ${od.odId}</p></div><div style="text-align:center;"><div class="status">VALID OD AUTHORIZATION</div></div><div class="field"><div class="label">Student</div><div class="value">${od.studentName}</div></div><div class="field"><div class="label">Reg No</div><div class="value">${od.studentEmail.split('@')[0].toUpperCase()}</div></div><div class="field"><div class="label">Dates</div><div class="value">${od.from} to ${od.to}</div></div><div class="field"><div class="label">Activity</div><div class="value">${od.subject}</div></div><div class="field"><div class="label">Authorized By</div><div class="value">HOD (via ${od.forwardedBy || 'Staff'})</div></div><div class="footer" style="text-align:center;margin-top:20px;font-size:10px;color:#aaa;">Secure Document Verification System</div></div></body></html>`);
    } catch (e) { res.status(500).send("Error"); }
};

exports.downloadODPDF = async (req, res) => {
    try {
        let { id } = req.params;
        if (id && id.includes('ObjectId("')) id = id.match(/ObjectId\("([0-9a-fA-F]+)"\)/)[1];
        else if (id && id.startsWith('"')) id = id.slice(1, -1);
        const od = await ODRequest.findById(id);
        if (!od) return res.status(404).json({ success: false, message: 'Not found' });
        if (!od.odId || !fs.existsSync(path.join(__dirname, '../letters', `${od.odId}.pdf`))) {
            if (od.status === 'accepted') await generateODPDFHelper(od); else return res.status(404).json({ success: false, message: 'PDF not available' });
        }
        res.download(path.join(__dirname, '../letters', `${od.odId}.pdf`), `OD_${od.studentName.replace(/\s+/g, '_')}.pdf`);
    } catch (error) { res.status(500).json({ success: false, message: 'Download failed', error: error.message }); }
};
