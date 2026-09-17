const PDFDocument = require('pdfkit');

/**
 * Generates an official ITM Skills University Exam Result Scorecard PDF
 * @param {Object} data - Contains student, exam, result, and questionAnalysis
 * @returns {Promise<Buffer>}
 */
const generateResultPDF = (data) => {
  return new Promise((resolve, reject) => {
    try {
      const doc = new PDFDocument({ margin: 40, size: 'A4' });
      const buffers = [];

      doc.on('data', buffers.push.bind(buffers));
      doc.on('end', () => {
        const pdfBuffer = Buffer.concat(buffers);
        resolve(pdfBuffer);
      });

      const { student = {}, exam = {}, result = {}, submittedAt = new Date().toISOString() } = data;

      // Header Branding
      doc.rect(40, 40, 515, 60).fill('#0F172A');
      doc.fillColor('#FFFFFF')
         .fontSize(18)
         .font('Helvetica-Bold')
         .text('ITM SKILLS UNIVERSITY', 55, 52, { align: 'center' });
      doc.fontSize(10)
         .font('Helvetica')
         .text('OFFICIAL EXAMINATION RESULT SCORECARD', 55, 75, { align: 'center' });

      // Student & Exam Details Section
      doc.moveDown(2);
      const startY = 120;
      doc.rect(40, startY, 515, 80).strokeColor('#CBD5E1').stroke();

      doc.fillColor('#1E293B').fontSize(10).font('Helvetica-Bold');
      doc.text('STUDENT INFORMATION', 55, startY + 12);
      doc.font('Helvetica').fontSize(9).fillColor('#475569');
      doc.text(`Name: ${student.name || 'Student'}`, 55, startY + 30);
      doc.text(`Email / Roll No: ${student.email || 'N/A'}`, 55, startY + 45);
      doc.text(`Date of Exam: ${new Date(submittedAt).toLocaleDateString()}`, 55, startY + 60);

      doc.fillColor('#1E293B').fontSize(10).font('Helvetica-Bold');
      doc.text('EXAMINATION DETAILS', 310, startY + 12);
      doc.font('Helvetica').fontSize(9).fillColor('#475569');
      doc.text(`Exam Title: ${exam.title || 'MCQ Examination'}`, 310, startY + 30);
      doc.text(`Subject: ${exam.subject || 'General'}`, 310, startY + 45);
      doc.text(`Duration: ${exam.duration || 30} minutes`, 310, startY + 60);

      // Score Summary Grid
      const scoreY = 220;
      const isPass = result.status === 'PASS';
      const statusColor = isPass ? '#10B981' : '#EF4444';

      // Summary Card
      doc.rect(40, scoreY, 515, 95).fillAndStroke('#F8FAFC', '#E2E8F0');

      doc.fillColor(statusColor).fontSize(20).font('Helvetica-Bold');
      doc.text(`${result.score} / ${result.totalMarks}`, 60, scoreY + 20);
      doc.fontSize(10).font('Helvetica').fillColor('#64748B').text('TOTAL SCORE OBTAINED', 60, scoreY + 48);

      doc.fillColor('#1E40AF').fontSize(20).font('Helvetica-Bold');
      doc.text(`${result.percentage}%`, 210, scoreY + 20);
      doc.fontSize(10).font('Helvetica').fillColor('#64748B').text('PERCENTAGE', 210, scoreY + 48);

      doc.fillColor('#7C3AED').fontSize(20).font('Helvetica-Bold');
      doc.text(`${result.grade || 'N/A'}`, 330, scoreY + 20);
      doc.fontSize(10).font('Helvetica').fillColor('#64748B').text('GRADE', 330, scoreY + 48);

      doc.fillColor(statusColor).fontSize(20).font('Helvetica-Bold');
      doc.text(result.status || 'PASS', 440, scoreY + 20);
      doc.fontSize(10).font('Helvetica').fillColor('#64748B').text('RESULT', 440, scoreY + 48);

      // Stat Pills
      const pillY = scoreY + 70;
      doc.fontSize(9).font('Helvetica-Bold');
      doc.fillColor('#16A34A').text(`Correct: ${result.correct || 0}`, 60, pillY);
      doc.fillColor('#DC2626').text(`Wrong: ${result.wrong || 0}`, 160, pillY);
      doc.fillColor('#D97706').text(`Unattempted: ${result.unattempted || 0}`, 260, pillY);
      const minutes = Math.floor((result.timeTaken || 0) / 60);
      const seconds = (result.timeTaken || 0) % 60;
      doc.fillColor('#4B5563').text(`Time Taken: ${minutes}m ${seconds}s`, 380, pillY);

      // Question-wise Analysis Heading
      let currentY = 340;
      doc.fillColor('#0F172A').fontSize(12).font('Helvetica-Bold');
      doc.text('QUESTION-WISE PERFORMANCE BREAKDOWN', 40, currentY);
      currentY += 20;

      // Table Header
      doc.rect(40, currentY, 515, 22).fill('#1E293B');
      doc.fillColor('#FFFFFF').fontSize(8).font('Helvetica-Bold');
      doc.text('Q#', 45, currentY + 7);
      doc.text('Question Text', 70, currentY + 7);
      doc.text('Your Ans', 350, currentY + 7);
      doc.text('Correct', 405, currentY + 7);
      doc.text('Status', 455, currentY + 7);
      doc.text('Marks', 510, currentY + 7);
      currentY += 24;

      // Rows
      const questions = result.questionAnalysis || [];
      const displayQuestions = questions.slice(0, 18); // Show up to first 18 questions to fit cleanly or paginate

      displayQuestions.forEach((q, index) => {
        const rowBg = index % 2 === 0 ? '#FFFFFF' : '#F1F5F9';
        doc.rect(40, currentY, 515, 20).fill(rowBg);

        const statusColorQ = q.status === 'CORRECT' ? '#16A34A' : q.status === 'WRONG' ? '#DC2626' : '#9CA3AF';

        doc.fillColor('#1E293B').fontSize(8).font('Helvetica');
        doc.text(String(q.questionNo || index + 1), 45, currentY + 6);

        const truncatedQ = (q.question || '').length > 55 ? `${(q.question || '').substring(0, 52)}...` : (q.question || '');
        doc.text(truncatedQ, 70, currentY + 6);

        doc.font('Helvetica-Bold').fillColor('#334155').text(q.studentAnswer || '-', 360, currentY + 6);
        doc.fillColor('#1E40AF').text(q.correctAnswer || '-', 415, currentY + 6);

        doc.fillColor(statusColorQ).text(q.status, 455, currentY + 6);
        doc.fillColor('#0F172A').text(String(q.marksAwarded), 512, currentY + 6);

        currentY += 20;
      });

      if (questions.length > 18) {
        doc.fillColor('#64748B').fontSize(8).font('Helvetica-Oblique');
        doc.text(`... and ${questions.length - 18} more questions recorded. Full review available in online portal.`, 40, currentY + 6);
        currentY += 20;
      }

      // Footer
      const footerY = 780;
      doc.fontSize(8).font('Helvetica').fillColor('#94A3B8');
      doc.text('This is a computer-generated examination result scorecard authenticated by ITM Skills University Examination Controller.', 40, footerY, { align: 'center' });

      doc.end();
    } catch (err) {
      reject(err);
    }
  });
};

/**
 * Generates an Exam Performance Report PDF for Administrators
 */
const generateAdminReportPDF = (reportData) => {
  return new Promise((resolve, reject) => {
    try {
      const doc = new PDFDocument({ margin: 40, size: 'A4' });
      const buffers = [];

      doc.on('data', buffers.push.bind(buffers));
      doc.on('end', () => {
        const pdfBuffer = Buffer.concat(buffers);
        resolve(pdfBuffer);
      });

      const { exam = {}, stats = {}, students = [] } = reportData;

      // Header
      doc.rect(40, 40, 515, 60).fill('#0F172A');
      doc.fillColor('#FFFFFF')
         .fontSize(18)
         .font('Helvetica-Bold')
         .text('ITM SKILLS UNIVERSITY', 55, 52, { align: 'center' });
      doc.fontSize(10)
         .font('Helvetica')
         .text('EXAMINATION COMPREHENSIVE PERFORMANCE REPORT', 55, 75, { align: 'center' });

      doc.moveDown(2);
      const startY = 120;
      doc.rect(40, startY, 515, 55).strokeColor('#CBD5E1').stroke();
      doc.fillColor('#1E293B').fontSize(10).font('Helvetica-Bold');
      doc.text(`Exam: ${exam.title || 'Examination'}`, 55, startY + 12);
      doc.font('Helvetica').fontSize(9).fillColor('#475569');
      doc.text(`Subject: ${exam.subject || 'General'} | Duration: ${exam.duration || 30} mins | Passing Marks: ${exam.passingMarks || 40}`, 55, startY + 30);

      // Key Metrics Row
      const statY = 190;
      doc.rect(40, statY, 515, 65).fillAndStroke('#F8FAFC', '#E2E8F0');

      doc.fillColor('#1E40AF').fontSize(16).font('Helvetica-Bold');
      doc.text(String(stats.totalAttempts || 0), 60, statY + 12);
      doc.fontSize(8).font('Helvetica').fillColor('#64748B').text('TOTAL ATTEMPTS', 60, statY + 36);

      doc.fillColor('#10B981').fontSize(16).font('Helvetica-Bold');
      doc.text(`${stats.averageScore || 0}`, 160, statY + 12);
      doc.fontSize(8).font('Helvetica').fillColor('#64748B').text('AVG SCORE', 160, statY + 36);

      doc.fillColor('#059669').fontSize(16).font('Helvetica-Bold');
      doc.text(`${stats.highestScore || 0}`, 260, statY + 12);
      doc.fontSize(8).font('Helvetica').fillColor('#64748B').text('HIGHEST', 260, statY + 36);

      doc.fillColor('#DC2626').fontSize(16).font('Helvetica-Bold');
      doc.text(`${stats.lowestScore || 0}`, 350, statY + 12);
      doc.fontSize(8).font('Helvetica').fillColor('#64748B').text('LOWEST', 350, statY + 36);

      doc.fillColor('#7C3AED').fontSize(16).font('Helvetica-Bold');
      doc.text(`${stats.passPercentage || 0}%`, 440, statY + 12);
      doc.fontSize(8).font('Helvetica').fillColor('#64748B').text('PASS RATE', 440, statY + 36);

      // Student Rank Table
      let currentY = 275;
      doc.fillColor('#0F172A').fontSize(11).font('Helvetica-Bold');
      doc.text('STUDENT LEADERBOARD & ATTEMPT RECORDS', 40, currentY);
      currentY += 18;

      doc.rect(40, currentY, 515, 20).fill('#1E293B');
      doc.fillColor('#FFFFFF').fontSize(8).font('Helvetica-Bold');
      doc.text('Rank', 45, currentY + 6);
      doc.text('Student Name', 80, currentY + 6);
      doc.text('Email', 200, currentY + 6);
      doc.text('Score', 330, currentY + 6);
      doc.text('Percent', 390, currentY + 6);
      doc.text('Status', 450, currentY + 6);
      doc.text('Grade', 505, currentY + 6);
      currentY += 22;

      students.slice(0, 22).forEach((s, idx) => {
        const rowBg = idx % 2 === 0 ? '#FFFFFF' : '#F1F5F9';
        doc.rect(40, currentY, 515, 18).fill(rowBg);

        const isPass = s.status === 'PASS';
        const color = isPass ? '#16A34A' : '#DC2626';

        doc.fillColor('#1E293B').fontSize(8).font('Helvetica');
        doc.text(String(idx + 1), 45, currentY + 5);
        doc.text(s.studentName || 'Student', 80, currentY + 5);
        doc.text(s.email || 'N/A', 200, currentY + 5);
        doc.font('Helvetica-Bold').text(String(s.score), 330, currentY + 5);
        doc.font('Helvetica').text(`${s.percentage}%`, 390, currentY + 5);
        doc.fillColor(color).font('Helvetica-Bold').text(s.status, 450, currentY + 5);
        doc.fillColor('#7C3AED').text(s.grade || '-', 510, currentY + 5);

        currentY += 18;
      });

      doc.end();
    } catch (err) {
      reject(err);
    }
  });
};

module.exports = {
  generateResultPDF,
  generateAdminReportPDF
};
