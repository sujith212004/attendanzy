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

    const qrBuffer = await QRCode.toBuffer(verificationUrl, {
        margin: 1,
        width: 300,
        errorCorrectionLevel: 'H'
    });

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

    const textColor = '#111827';
    const accentColor = '#2563EB'; // Blue for OD
    const logoPath = path.join(__dirname, '../assets/logo.jpg');

    // --- Background Watermark ---
    if (fs.existsSync(logoPath)) {
        doc.save();
        doc.opacity(0.05);
        doc.image(logoPath, 147, 280, { width: 300 });
        doc.restore();
    }

    // --- Institutional Letterhead ---
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
    doc.font('Helvetica-Bold').fontSize(10).text(`Ref No: OD/${odId}`, 45, 130);
    doc.text(`Date: ${today}`, 440, 130, { align: 'right' });

    doc.moveDown(3);

    // --- "From" Section ---
    doc.font('Helvetica-Bold').fontSize(11).text('FROM:', 45);
    doc.moveDown(0.3);
    doc.font('Helvetica').fontSize(11);
    const fromText = odRequest.from || `${odRequest.studentName}\nDepartment of ${odRequest.department}\n${odRequest.year}-${odRequest.section}`;
    doc.text(fromText, 75, doc.y, { lineGap: 3 });

    doc.moveDown(2);

    // --- "To" Section ---
    doc.font('Helvetica-Bold').fontSize(11).text('TO:', 45);
    doc.moveDown(0.3);
    doc.font('Helvetica').fontSize(11);
    const toText = odRequest.to || `The Head of Department,\nDepartment of ${odRequest.department},\nAgni College of Technology.`;
    doc.text(toText, 75, doc.y, { lineGap: 3 });

    doc.moveDown(3);

    // --- Subject Line ---
    doc.font('Helvetica-Bold').fontSize(11.5).text(`Subject: ${odRequest.subject.toUpperCase()} - REGARDING.`, 45, doc.y, { underline: true });

    doc.moveDown(4);

    // --- Body Section ---
    doc.font('Helvetica').fontSize(12).text('Respected Sir/Madam,', 45);
    doc.moveDown(1.5);

    const mainContent = odRequest.content || odRequest.reason || 'Requested On-Duty authorization.';
    doc.text(mainContent, 45, doc.y, { align: 'justify', lineGap: 5, width: 505 });

    doc.moveDown(5);
    doc.text('Thanking you,', 45);

    doc.moveDown(4);
    doc.font('Helvetica-Bold').text('Yours obediently,', 380);
    doc.moveDown(0.4);
    doc.text(odRequest.studentName.toUpperCase(), 380);

    // --- High-Fidelity Authorization Area ---
    const bottomBlockY = 665;
    doc.strokeColor('#111827').lineWidth(2).moveTo(40, bottomBlockY - 20).lineTo(555, bottomBlockY - 20).stroke();

    doc.fillColor(accentColor).font('Helvetica-Bold').fontSize(14).text('SECURE OFFICIAL AUTHORIZATION', 45, bottomBlockY);

    doc.y = bottomBlockY + 30;
    doc.fillColor('#374151').font('Helvetica').fontSize(9.5).text('This On-Duty (OD) authorization is electronically verified. The department confirms the student\'s involvement in the aforementioned activity for the specified duration.', 45, doc.y, { width: 380, lineGap: 2 });

    doc.moveDown(1);
    doc.fillColor(textColor).font('Helvetica-Bold').fontSize(9.5);
    doc.text(`VERIFIED BY: ${odRequest.forwardedBy || 'Department Staff'}`, 45);
    doc.text(`AUTHORIZED BY: HEAD OF DEPARTMENT`, 45);
    doc.text(`TIMESTAMP: ${new Date().toLocaleString('en-IN')}`, 45);

    // --- Branded QR Code ---
    try {
        const qrX = 460;
        const qrY = bottomBlockY + 5;
        const qrSize = 85;

        doc.image(qrBuffer, qrX, qrY, { width: qrSize });

        const boxSize = 20;
        doc.save();
        doc.fillColor('white').rect(qrX + (qrSize / 2) - (boxSize / 2), qrY + (qrSize / 2) - (boxSize / 2), boxSize, boxSize).fill();
        doc.fillColor(accentColor).font('Helvetica-Bold').fontSize(6).text('ATZ', qrX + (qrSize / 2) - (boxSize / 2), qrY + (qrSize / 2) - 2, { width: boxSize, align: 'center' });
        doc.restore();

        doc.fillColor('#6B7280').font('Helvetica-Bold').fontSize(7).text('DOC-VERIFY QR', qrX, qrY + qrSize + 5, { width: qrSize, align: 'center' });
    } catch (e) { }

    // Security Footer
    doc.strokeColor('#E5E7EB').lineWidth(1).moveTo(40, 805).lineTo(555, 805).stroke();
    doc.fillColor('#9CA3AF').font('Helvetica').fontSize(8).text('Electronic OD Authorization | Attendanzy Secure Portal | CID: ' + (odRequest._id.toString().substring(0, 8)), 40, 812, { width: 515, align: 'center' });

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
        if (!od) return res.status(404).send('<h1 style="color:#ef4444;text-align:center;padding:50px;font-family:sans-serif;">INVALID DOCUMENT ❌<br><small style="color:#6b7280;">This record does not exist in the institutional database.</small></h1>');

        res.send(`
        <html>
        <head>
            <title>Secure Verification | Attendanzy</title>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body { font-family: 'Inter', -apple-system, sans-serif; background: #f9fafb; margin: 0; padding: 20px; color: #111827; }
                .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 20px; box-shadow: 0 20px 50px rgba(0,0,0,0.05); overflow: hidden; border: 1px solid #e5e7eb; }
                .banner { background: #2563EB; color: white; padding: 30px; text-align: center; }
                .banner h1 { margin: 0; font-size: 24px; letter-spacing: -0.5px; }
                .content { padding: 40px; }
                .status-badge { display: inline-flex; align-items: center; background: #dbeafe; color: #1e40af; padding: 10px 20px; border-radius: 100px; font-weight: 700; font-size: 14px; margin-bottom: 30px; }
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
                        <div class="status-badge">✓ OFFICIALLY VERIFIED OD RECORD</div>
                    </div>
                    <div class="grid">
                        <div class="field"><div class="label">Reference ID</div><div class="value">${od.odId}</div></div>
                        <div class="field"><div class="label">Activity Date</div><div class="value">${od.from} to ${od.to}</div></div>
                        <div class="field"><div class="label">Student Name</div><div class="value">${od.studentName}</div></div>
                        <div class="field"><div class="label">Register No</div><div class="value">${od.studentEmail.split('@')[0].toUpperCase()}</div></div>
                        <div class="field" style="grid-column: 1 / -1;"><div class="label">Activity Purpose</div><div class="value">${od.subject}</div></div>
                        <div class="field"><div class="label">Authorized By</div><div class="value">HOD, Dept of ${od.department}</div></div>
                        <div class="field"><div class="label">Status</div><div class="value">Officially Authorized</div></div>
                    </div>
                </div>
                <div class="footer">Attendanzy Secure Document Verification Gateway | ACT-Portal</div>
            </div>
        </body>
        </html>
        `);
    } catch (e) { res.status(500).send("Verification Gateway Error"); }
};

exports.downloadODPDF = async (req, res) => {
    try {
        let { id } = req.params;
        if (id && id.includes('ObjectId("')) id = id.match(/ObjectId\("([0-9a-fA-F]+)"\)/)[1];
        else if (id && id.startsWith('"')) id = id.slice(1, -1);
        const od = await ODRequest.findById(id);
        if (!od) return res.status(404).json({ success: false, message: 'Not found' });

        if (od.status === 'accepted') {
            await generateODPDFHelper(od);
        } else if (!od.odId || !fs.existsSync(path.join(__dirname, '../letters', `${od.odId}.pdf`))) {
            return res.status(404).json({ success: false, message: 'PDF not available' });
        }

        res.download(path.join(__dirname, '../letters', `${od.odId}.pdf`), `OD_${od.studentName.replace(/\s+/g, '_')}.pdf`);
    } catch (error) { res.status(500).json({ success: false, message: 'Download failed', error: error.message }); }
};
