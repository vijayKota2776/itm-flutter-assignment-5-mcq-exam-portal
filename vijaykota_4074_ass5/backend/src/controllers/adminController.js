const XLSX = require('xlsx');
const { getDb } = require('../config/firebase');
const { uploadBuffer, deleteAsset } = require('../services/cloudinaryService');
const { parseAndValidateQuestionsFile } = require('../services/excelService');
const { generateAdminReportPDF } = require('../services/pdfService');
const { successResponse, errorResponse } = require('../utils/response');

/**
 * POST /api/admin/upload-excel
 * Uploads question sheet to Cloudinary, parses it, validates all rows, returns question preview
 */
const uploadExcel = async (req, res, next) => {
  try {
    if (!req.file || !req.file.buffer) {
      return errorResponse(res, 'No spreadsheet file uploaded. Please select an .xlsx or .csv file.', 'BAD_REQUEST', 400);
    }

    const { originalname, buffer } = req.file;

    // 1. Parse and validate questions spreadsheet
    const parseResult = parseAndValidateQuestionsFile(buffer);
    if (!parseResult.isValid && parseResult.questions.length === 0) {
      return errorResponse(res, 'Spreadsheet parsing or validation failed', 'INVALID_EXCEL', 400, {
        errors: parseResult.errors
      });
    }

    // 2. Upload original spreadsheet file to Cloudinary
    let cloudinaryResult = { public_id: '', secure_url: '' };
    try {
      cloudinaryResult = await uploadBuffer(buffer, {
        folder: 'mcq-portal/excel-sheets',
        resource_type: 'raw',
        format: originalname.endsWith('.csv') ? 'csv' : 'xlsx'
      });
    } catch (uploadErr) {
      console.warn('[AdminController] Cloudinary upload notice:', uploadErr.message);
    }

    return successResponse(res, {
      fileName: originalname,
      excelUrl: cloudinaryResult.secure_url,
      excelPublicId: cloudinaryResult.public_id,
      isValid: parseResult.isValid,
      totalRows: parseResult.totalRows,
      validCount: parseResult.validCount,
      errorCount: parseResult.errorCount,
      errors: parseResult.errors,
      questions: parseResult.questions
    }, 'Spreadsheet processed successfully');
  } catch (err) {
    next(err);
  }
};

/**
 * POST /api/admin/exam
 * Creates a new examination with metadata and stores its questions
 */
const createExam = async (req, res, next) => {
  try {
    const {
      title,
      subject,
      description = '',
      duration,
      totalMarks,
      marksPerQuestion = 1,
      negativeMarking = 0,
      passingMarks,
      instructions = 'Read all questions carefully before answering.',
      startDate,
      endDate,
      excelUrl = '',
      excelPublicId = '',
      questions = []
    } = req.body;

    // Metadata Validations
    if (!title || !subject) {
      return errorResponse(res, 'Exam Title and Subject are required fields.', 'VALIDATION_ERROR', 400);
    }
    const numDuration = Number(duration);
    if (isNaN(numDuration) || numDuration <= 0) {
      return errorResponse(res, 'Duration must be a positive number of minutes.', 'VALIDATION_ERROR', 400);
    }
    if (!questions || questions.length === 0) {
      return errorResponse(res, 'An exam must contain at least one valid question.', 'VALIDATION_ERROR', 400);
    }

    const sDate = new Date(startDate || Date.now());
    const eDate = new Date(endDate || (Date.now() + 7 * 24 * 60 * 60 * 1000));
    if (isNaN(sDate.getTime()) || isNaN(eDate.getTime())) {
      return errorResponse(res, 'Invalid start or end date specified.', 'VALIDATION_ERROR', 400);
    }
    if (eDate <= sDate) {
      return errorResponse(res, 'End date must be strictly after start date.', 'VALIDATION_ERROR', 400);
    }

    const calculatedTotalMarks = Number(totalMarks) || (questions.length * Number(marksPerQuestion));
    const calculatedPassingMarks = Number(passingMarks) || (calculatedTotalMarks * 0.4);

    const db = getDb();
    const examRef = db.collection('exams').doc();
    const examId = examRef.id;

    const examData = {
      id: examId,
      title: String(title).trim(),
      subject: String(subject).trim(),
      description: String(description).trim(),
      duration: numDuration,
      totalMarks: calculatedTotalMarks,
      marksPerQuestion: Number(marksPerQuestion),
      negativeMarking: Number(negativeMarking),
      passingMarks: calculatedPassingMarks,
      instructions: String(instructions).trim(),
      questionCount: questions.length,
      excelUrl,
      excelPublicId,
      status: 'draft', // draft | published | archived
      startDate: sDate.toISOString(),
      endDate: eDate.toISOString(),
      createdBy: req.user.uid,
      createdByName: req.user.name,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };

    // Use Batch write to commit exam and all questions together
    const batch = db.batch();
    batch.set(examRef, examData);

    questions.forEach((q, idx) => {
      const qRef = db.collection('questions').doc();
      batch.set(qRef, {
        id: qRef.id,
        examId,
        questionNo: q.questionNo || idx + 1,
        question: String(q.question).trim(),
        imageUrl: q.imageUrl || '',
        options: {
          A: String(q.options?.A || '').trim(),
          B: String(q.options?.B || '').trim(),
          C: String(q.options?.C || '').trim(),
          D: String(q.options?.D || '').trim()
        },
        correctAnswer: String(q.correctAnswer).trim().toUpperCase()
      });
    });

    await batch.commit();

    return successResponse(res, examData, 'Exam created successfully in draft mode', 201);
  } catch (err) {
    next(err);
  }
};

/**
 * GET /api/admin/exams
 * Lists all exams with optional status and search filtering
 */
const getExams = async (req, res, next) => {
  try {
    const { status, search } = req.query;
    const db = getDb();

    let query = db.collection('exams');
    if (status && status !== 'all') {
      query = query.where('status', '==', status);
    }

    const snapshot = await query.get();
    let exams = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));

    // In-memory search filter
    if (search) {
      const q = search.toLowerCase();
      exams = exams.filter(e =>
        (e.title && e.title.toLowerCase().includes(q)) ||
        (e.subject && e.subject.toLowerCase().includes(q))
      );
    }

    // Sort by createdAt descending
    exams.sort((a, b) => new Date(b.createdAt || 0) - new Date(a.createdAt || 0));

    return successResponse(res, exams, 'Exams retrieved successfully');
  } catch (err) {
    next(err);
  }
};

/**
 * GET /api/admin/exam/:id
 * Fetches an exam by ID along with its questions (admin route includes correct answers)
 */
const getExamById = async (req, res, next) => {
  try {
    const { id } = req.params;
    const db = getDb();

    const examDoc = await db.collection('exams').doc(id).get();
    if (!examDoc.exists) {
      return errorResponse(res, 'Exam not found', 'NOT_FOUND', 404);
    }

    const questionsSnap = await db.collection('questions').where('examId', '==', id).get();
    const questions = questionsSnap.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    questions.sort((a, b) => (a.questionNo || 0) - (b.questionNo || 0));

    return successResponse(res, {
      ...examDoc.data(),
      id: examDoc.id,
      questions
    }, 'Exam details retrieved successfully');
  } catch (err) {
    next(err);
  }
};

/**
 * PUT /api/admin/exam/:id
 * Updates exam metadata or status (draft, published, archived)
 */
const updateExam = async (req, res, next) => {
  try {
    const { id } = req.params;
    const db = getDb();

    const examRef = db.collection('exams').doc(id);
    const doc = await examRef.get();
    if (!doc.exists) {
      return errorResponse(res, 'Exam not found', 'NOT_FOUND', 404);
    }

    const updates = { ...req.body, updatedAt: new Date().toISOString() };
    delete updates.id;
    delete updates.createdAt;
    delete updates.createdBy;

    await examRef.update(updates);
    const updated = (await examRef.get()).data();

    return successResponse(res, { id, ...updated }, 'Exam updated successfully');
  } catch (err) {
    next(err);
  }
};

/**
 * DELETE /api/admin/exam/:id
 * Deletes exam, question documents, and associated Cloudinary assets
 */
const deleteExam = async (req, res, next) => {
  try {
    const { id } = req.params;
    const db = getDb();

    const examRef = db.collection('exams').doc(id);
    const examDoc = await examRef.get();
    if (!examDoc.exists) {
      return errorResponse(res, 'Exam not found', 'NOT_FOUND', 404);
    }

    const examData = examDoc.data();

    // 1. Delete associated Cloudinary asset if public ID exists
    if (examData.excelPublicId) {
      try {
        await deleteAsset(examData.excelPublicId, 'raw');
      } catch (cloudErr) {
        console.warn(`[AdminController] Cloudinary asset cleanup warning: ${cloudErr.message}`);
      }
    }

    // 2. Delete questions
    const questionsSnap = await db.collection('questions').where('examId', '==', id).get();
    const batch = db.batch();
    questionsSnap.docs.forEach(doc => {
      batch.delete(db.collection('questions').doc(doc.id));
    });
    batch.delete(examRef);
    await batch.commit();

    return successResponse(res, { id }, 'Exam and associated questions deleted successfully');
  } catch (err) {
    next(err);
  }
};

/**
 * GET /api/admin/students
 * Lists all registered student accounts with their attempt metrics
 */
const getStudents = async (req, res, next) => {
  try {
    const db = getDb();
    const usersSnap = await db.collection('users').where('role', '==', 'student').get();
    const resultsSnap = await db.collection('results').get();

    const results = resultsSnap.docs.map(d => d.data());

    const students = usersSnap.docs.map(doc => {
      const u = doc.data();
      const studentResults = results.filter(r => r.studentId === u.uid);
      const totalAttempts = studentResults.length;
      const totalScore = studentResults.reduce((acc, curr) => acc + (Number(curr.score) || 0), 0);
      const avgScore = totalAttempts > 0 ? Number((totalScore / totalAttempts).toFixed(2)) : 0;
      const passCount = studentResults.filter(r => r.status === 'PASS').length;
      const passPercentage = totalAttempts > 0 ? Number(((passCount / totalAttempts) * 100).toFixed(1)) : 0;

      return {
        uid: u.uid,
        name: u.name || 'Student',
        email: u.email,
        photoUrl: u.photoUrl || '',
        createdAt: u.createdAt,
        lastLogin: u.lastLogin,
        totalAttempts,
        averageScore: avgScore,
        passPercentage
      };
    });

    return successResponse(res, students, 'Students retrieved successfully');
  } catch (err) {
    next(err);
  }
};

/**
 * GET /api/admin/report/:examId
 * Calculates aggregate performance analytics for an examination
 */
const getExamReport = async (req, res, next) => {
  try {
    const { examId } = req.params;
    const db = getDb();

    const examDoc = await db.collection('exams').doc(examId).get();
    if (!examDoc.exists) {
      return errorResponse(res, 'Exam not found', 'NOT_FOUND', 404);
    }
    const examData = examDoc.data();

    // Fetch all results for this exam
    const resultsSnap = await db.collection('results').where('examId', '==', examId).get();
    const results = resultsSnap.docs.map(d => d.data());

    const totalAttempts = results.length;
    let averageScore = 0;
    let highestScore = 0;
    let lowestScore = 0;
    let passCount = 0;
    let failCount = 0;

    // Score distribution bins: [0-20%, 21-40%, 41-60%, 61-80%, 81-100%]
    const scoreBins = {
      '0-20%': 0,
      '21-40%': 0,
      '41-60%': 0,
      '61-80%': 0,
      '81-100%': 0
    };

    if (totalAttempts > 0) {
      let sumScore = 0;
      highestScore = Number(results[0].score) || 0;
      lowestScore = Number(results[0].score) || 0;

      results.forEach(r => {
        const s = Number(r.score) || 0;
        const p = Number(r.percentage) || 0;
        sumScore += s;
        if (s > highestScore) highestScore = s;
        if (s < lowestScore) lowestScore = s;
        if (r.status === 'PASS') passCount++;
        else failCount++;

        if (p <= 20) scoreBins['0-20%']++;
        else if (p <= 40) scoreBins['21-40%']++;
        else if (p <= 60) scoreBins['41-60%']++;
        else if (p <= 80) scoreBins['61-80%']++;
        else scoreBins['81-100%']++;
      });

      averageScore = Number((sumScore / totalAttempts).toFixed(2));
    }

    const passPercentage = totalAttempts > 0 ? Number(((passCount / totalAttempts) * 100).toFixed(1)) : 0;
    const failPercentage = totalAttempts > 0 ? Number(((failCount / totalAttempts) * 100).toFixed(1)) : 0;

    // Sort students by score descending for leaderboard
    const studentList = [...results].sort((a, b) => (Number(b.score) || 0) - (Number(a.score) || 0));

    return successResponse(res, {
      exam: { id: examDoc.id, ...examData },
      stats: {
        totalAttempts,
        averageScore,
        highestScore,
        lowestScore,
        passCount,
        failCount,
        passPercentage,
        failPercentage,
        scoreDistribution: scoreBins
      },
      students: studentList
    }, 'Exam report generated successfully');
  } catch (err) {
    next(err);
  }
};

/**
 * POST /api/admin/report/:examId/export
 * Exports exam report to CSV, Excel, or PDF and uploads to Cloudinary
 */
const exportReport = async (req, res, next) => {
  try {
    const { examId } = req.params;
    const { format = 'csv' } = req.body;
    const db = getDb();

    const examDoc = await db.collection('exams').doc(examId).get();
    if (!examDoc.exists) {
      return errorResponse(res, 'Exam not found', 'NOT_FOUND', 404);
    }
    const examData = examDoc.data();

    const resultsSnap = await db.collection('results').where('examId', '==', examId).get();
    const results = resultsSnap.docs.map(d => d.data());
    results.sort((a, b) => (Number(b.score) || 0) - (Number(a.score) || 0));

    const exportRows = results.map((r, idx) => ({
      'Rank': idx + 1,
      'Student Name': r.studentName || 'Student',
      'Email': r.studentEmail || r.email || '',
      'Score': r.score,
      'Total Marks': r.totalMarks,
      'Percentage (%)': r.percentage,
      'Grade': r.grade,
      'Status': r.status,
      'Time Taken (s)': r.timeTaken,
      'Submission Date': r.submittedAt
    }));

    let buffer;
    let mimeType = 'text/csv';
    let fileExt = 'csv';

    if (format === 'excel' || format === 'xlsx') {
      const ws = XLSX.utils.json_to_sheet(exportRows);
      const wb = XLSX.utils.book_new();
      XLSX.utils.book_append_sheet(wb, ws, 'Report');
      buffer = XLSX.write(wb, { type: 'buffer', bookType: 'xlsx' });
      mimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      fileExt = 'xlsx';
    } else if (format === 'pdf') {
      const stats = {
        totalAttempts: results.length,
        averageScore: results.length ? (results.reduce((a, b) => a + Number(b.score), 0) / results.length).toFixed(2) : 0,
        highestScore: results.length ? Math.max(...results.map(r => Number(r.score))) : 0,
        lowestScore: results.length ? Math.min(...results.map(r => Number(r.score))) : 0,
        passPercentage: results.length ? ((results.filter(r => r.status === 'PASS').length / results.length) * 100).toFixed(1) : 0
      };
      buffer = await generateAdminReportPDF({ exam: examData, stats, students: exportRows });
      mimeType = 'application/pdf';
      fileExt = 'pdf';
    } else {
      // Default CSV
      const ws = XLSX.utils.json_to_sheet(exportRows);
      const csvString = XLSX.utils.sheet_to_csv(ws);
      buffer = Buffer.from(csvString, 'utf8');
      mimeType = 'text/csv';
      fileExt = 'csv';
    }

    // Upload to Cloudinary
    let cloudResult = { secure_url: '', public_id: '' };
    try {
      cloudResult = await uploadBuffer(buffer, {
        folder: 'mcq-portal/reports',
        resource_type: 'raw',
        format: fileExt
      });
    } catch (cErr) {
      console.warn('[AdminController] Cloudinary export upload notice:', cErr.message);
    }

    return successResponse(res, {
      format: fileExt,
      reportUrl: cloudResult.secure_url,
      publicId: cloudResult.public_id,
      totalRows: exportRows.length
    }, 'Report exported and uploaded successfully');
  } catch (err) {
    next(err);
  }
};

/**
 * GET /api/admin/dashboard-stats
 * Quick high-level metrics for admin dashboard cards
 */
const getDashboardStats = async (req, res, next) => {
  try {
    const db = getDb();
    const examsSnap = await db.collection('exams').get();
    const studentsSnap = await db.collection('users').where('role', '==', 'student').get();
    const attemptsSnap = await db.collection('attempts').get();
    const resultsSnap = await db.collection('results').get();

    const exams = examsSnap.docs.map(d => d.data());
    const totalExams = exams.length;
    const activeExams = exams.filter(e => e.status === 'published').length;
    const totalStudents = studentsSnap.docs.length;
    const totalAttempts = attemptsSnap.docs.length;

    const results = resultsSnap.docs.map(d => d.data());
    const totalScore = results.reduce((a, b) => a + (Number(b.score) || 0), 0);
    const averageScore = results.length > 0 ? Number((totalScore / results.length).toFixed(2)) : 0;
    const passCount = results.filter(r => r.status === 'PASS').length;
    const passPercentage = results.length > 0 ? Number(((passCount / results.length) * 100).toFixed(1)) : 0;

    return successResponse(res, {
      totalExams,
      activeExams,
      totalStudents,
      totalAttempts,
      averageScore,
      passPercentage
    }, 'Dashboard stats retrieved successfully');
  } catch (err) {
    next(err);
  }
};

module.exports = {
  uploadExcel,
  createExam,
  getExams,
  getExamById,
  updateExam,
  deleteExam,
  getStudents,
  getExamReport,
  exportReport,
  getDashboardStats
};
