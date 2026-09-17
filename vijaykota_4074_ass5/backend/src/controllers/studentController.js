const { getDb } = require('../config/firebase');
const { gradeExamAttempt } = require('../services/gradingService');
const { generateResultPDF } = require('../services/pdfService');
const { uploadBuffer } = require('../services/cloudinaryService');
const { successResponse, errorResponse } = require('../utils/response');

/**
 * GET /api/student/exams
 * Lists available exams for the student with dynamic lifecycle status:
 * 'Active' | 'Upcoming' | 'Completed' | 'Expired'
 */
const getAvailableExams = async (req, res, next) => {
  try {
    const studentId = req.user.uid;
    const db = getDb();

    // Fetch published exams
    const examsSnap = await db.collection('exams').where('status', '==', 'published').get();
    const exams = examsSnap.docs.map(doc => ({ id: doc.id, ...doc.data() }));

    // Fetch student's existing attempts
    const attemptsSnap = await db.collection('attempts').where('studentId', '==', studentId).get();
    const studentAttempts = attemptsSnap.docs.map(doc => ({ id: doc.id, ...doc.data() }));

    const now = new Date();

    const categorizedExams = exams.map(exam => {
      const sDate = new Date(exam.startDate);
      const eDate = new Date(exam.endDate);

      const existingAttempt = studentAttempts.find(a => a.examId === exam.id);
      let studentStatus = 'Active';

      if (existingAttempt && existingAttempt.status === 'completed') {
        studentStatus = 'Completed';
      } else if (now < sDate) {
        studentStatus = 'Upcoming';
      } else if (now > eDate) {
        studentStatus = 'Expired';
      } else {
        studentStatus = 'Active';
      }

      return {
        ...exam,
        studentStatus,
        attemptId: existingAttempt ? existingAttempt.id : null,
        attemptStatus: existingAttempt ? existingAttempt.status : null
      };
    });

    // Sort active first, then upcoming, then completed, then expired
    const statusPriority = { 'Active': 1, 'Upcoming': 2, 'Completed': 3, 'Expired': 4 };
    categorizedExams.sort((a, b) => (statusPriority[a.studentStatus] || 5) - (statusPriority[b.studentStatus] || 5));

    return successResponse(res, categorizedExams, 'Available examinations retrieved');
  } catch (err) {
    next(err);
  }
};

/**
 * POST /api/student/exam/:id/start
 * Initiates an exam attempt or resumes an active one.
 * CRITICAL SECURITY: Correct answers are STRICTLY STRIPPED from client response!
 */
const startExam = async (req, res, next) => {
  try {
    const { id } = req.params;
    const studentId = req.user.uid;
    const studentName = req.user.name || 'Student';
    const studentEmail = req.user.email || '';
    const db = getDb();

    // 1. Fetch exam metadata
    const examDoc = await db.collection('exams').doc(id).get();
    if (!examDoc.exists) {
      return errorResponse(res, 'Exam not found', 'NOT_FOUND', 404);
    }
    const exam = { id: examDoc.id, ...examDoc.data() };

    if (exam.status !== 'published') {
      return errorResponse(res, 'This examination is currently not published or open for attempts', 'EXAM_UNAVAILABLE', 403);
    }

    const now = new Date();
    const sDate = new Date(exam.startDate);
    const eDate = new Date(exam.endDate);

    if (now < sDate) {
      return errorResponse(res, `This exam will open on ${sDate.toLocaleString()}`, 'EXAM_NOT_STARTED', 400);
    }
    if (now > eDate) {
      return errorResponse(res, 'This exam ended on ' + eDate.toLocaleString(), 'EXAM_EXPIRED', 400);
    }

    // 2. Check for existing attempts
    const attemptsSnap = await db.collection('attempts')
      .where('studentId', '==', studentId)
      .where('examId', '==', id)
      .get();

    const existingAttempts = attemptsSnap.docs.map(d => ({ id: d.id, ...d.data() }));
    const completedAttempt = existingAttempts.find(a => a.status === 'completed');

    if (completedAttempt) {
      return errorResponse(res, 'You have already completed this examination. Only one attempt is permitted.', 'DUPLICATE_ATTEMPT', 403);
    }

    // Check for an active in-progress attempt
    let activeAttempt = existingAttempts.find(a => a.status === 'in-progress');
    const nowTime = Date.now();

    if (activeAttempt) {
      const expiryTime = new Date(activeAttempt.expiresAt).getTime();
      if (nowTime > expiryTime + 30000) {
        // Expired without submission
        await db.collection('attempts').doc(activeAttempt.id).update({
          status: 'expired',
          updatedAt: new Date().toISOString()
        });
        return errorResponse(res, 'Your examination session has expired.', 'SESSION_EXPIRED', 400);
      }
    } else {
      // 3. Create a fresh attempt document
      const durationMinutes = Number(exam.duration) || 30;
      const startedAt = new Date();
      const expiresAt = new Date(startedAt.getTime() + durationMinutes * 60 * 1000);

      const attemptRef = db.collection('attempts').doc();
      const newAttempt = {
        id: attemptRef.id,
        studentId,
        studentName,
        studentEmail,
        examId: id,
        examTitle: exam.title,
        startedAt: startedAt.toISOString(),
        expiresAt: expiresAt.toISOString(),
        answers: {},
        status: 'in-progress',
        createdAt: startedAt.toISOString(),
        updatedAt: startedAt.toISOString()
      };

      await attemptRef.set(newAttempt);
      activeAttempt = newAttempt;
    }

    // 4. Fetch questions and STRIP CORRECT ANSWERS!
    const questionsSnap = await db.collection('questions').where('examId', '==', id).get();
    const questions = questionsSnap.docs.map(doc => {
      const q = doc.data();
      return {
        id: doc.id,
        questionNo: q.questionNo,
        question: q.question,
        imageUrl: q.imageUrl || '',
        options: {
          A: q.options?.A || '',
          B: q.options?.B || '',
          C: q.options?.C || '',
          D: q.options?.D || ''
        }
        // NOTE: correctAnswer is intentionally omitted for exam security
      };
    });

    questions.sort((a, b) => (a.questionNo || 0) - (b.questionNo || 0));

    const remainingSeconds = Math.max(0, Math.floor((new Date(activeAttempt.expiresAt).getTime() - Date.now()) / 1000));

    return successResponse(res, {
      attemptId: activeAttempt.id,
      exam: {
        id: exam.id,
        title: exam.title,
        subject: exam.subject,
        duration: exam.duration,
        totalMarks: exam.totalMarks,
        marksPerQuestion: exam.marksPerQuestion,
        negativeMarking: exam.negativeMarking,
        instructions: exam.instructions,
        questionCount: questions.length
      },
      questions,
      studentAnswers: activeAttempt.answers || {},
      startedAt: activeAttempt.startedAt,
      expiresAt: activeAttempt.expiresAt,
      remainingSeconds
    }, 'Examination started successfully');
  } catch (err) {
    next(err);
  }
};

/**
 * POST /api/student/exam/:id/save-answer
 * Continuous autosave endpoint: persists student selected answers immediately
 */
const saveAnswer = async (req, res, next) => {
  try {
    const { id: examId } = req.params;
    const { attemptId, answers } = req.body;
    const studentId = req.user.uid;

    if (!attemptId) {
      return errorResponse(res, 'Attempt ID is required for autosave', 'BAD_REQUEST', 400);
    }

    const db = getDb();
    const attemptRef = db.collection('attempts').doc(attemptId);
    const attemptDoc = await attemptRef.get();

    if (!attemptDoc.exists) {
      return errorResponse(res, 'Attempt not found', 'NOT_FOUND', 404);
    }

    const attempt = attemptDoc.data();
    if (attempt.studentId !== studentId) {
      return errorResponse(res, 'Unauthorized attempt access', 'FORBIDDEN', 403);
    }
    if (attempt.status !== 'in-progress') {
      return errorResponse(res, `Cannot autosave on ${attempt.status} attempt`, 'INVALID_STATE', 400);
    }

    // Merge new answers with existing answers
    const updatedAnswers = {
      ...(attempt.answers || {}),
      ...(answers || {})
    };

    await attemptRef.update({
      answers: updatedAnswers,
      updatedAt: new Date().toISOString()
    });

    return successResponse(res, { saved: true, count: Object.keys(updatedAnswers).length }, 'Answers autosaved');
  } catch (err) {
    next(err);
  }
};

/**
 * POST /api/student/exam/:id/submit
 * Server-Side Evaluation, score calculation, result generation, PDF creation & Cloudinary upload
 */
const submitExam = async (req, res, next) => {
  try {
    const { id: examId } = req.params;
    const { attemptId, answers = {}, isAutoSubmit = false } = req.body;
    const studentId = req.user.uid;
    const db = getDb();

    if (!attemptId) {
      return errorResponse(res, 'Attempt ID is required for submission', 'BAD_REQUEST', 400);
    }

    const attemptRef = db.collection('attempts').doc(attemptId);
    const attemptDoc = await attemptRef.get();

    if (!attemptDoc.exists) {
      return errorResponse(res, 'Attempt not found', 'NOT_FOUND', 404);
    }

    const attempt = attemptDoc.data();
    if (attempt.studentId !== studentId) {
      return errorResponse(res, 'Unauthorized attempt access', 'FORBIDDEN', 403);
    }

    // Prevent double submission
    if (attempt.status === 'completed') {
      // Return existing result
      const existingResSnap = await db.collection('results').where('attemptId', '==', attemptId).limit(1).get();
      if (!existingResSnap.empty) {
        return successResponse(res, existingResSnap.docs[0].data(), 'Exam already submitted');
      }
    }

    // Fetch official exam configuration
    const examDoc = await db.collection('exams').doc(examId).get();
    if (!examDoc.exists) {
      return errorResponse(res, 'Associated exam document not found', 'NOT_FOUND', 404);
    }
    const examData = examDoc.data();

    // Verify time expiration (allow 60s grace buffer for network latency during autosubmit)
    const now = Date.now();
    const expiryTime = new Date(attempt.expiresAt).getTime();
    if (now > expiryTime + 60000 && !isAutoSubmit) {
      console.warn(`[SubmitExam] Attempt ${attemptId} submitted past expiry time.`);
    }

    // Merge submitted answers with saved answers
    const finalAnswers = {
      ...(attempt.answers || {}),
      ...answers
    };

    // Fetch official questions containing correct answers from database
    const questionsSnap = await db.collection('questions').where('examId', '==', examId).get();
    const questions = questionsSnap.docs.map(d => ({ id: d.id, ...d.data() }));
    questions.sort((a, b) => (a.questionNo || 0) - (b.questionNo || 0));

    // Calculate time taken
    const startTime = new Date(attempt.startedAt).getTime();
    const timeTakenSeconds = Math.max(1, Math.floor((now - startTime) / 1000));

    // Evaluate server-side grading
    const evaluation = gradeExamAttempt(questions, finalAnswers, examData, timeTakenSeconds);

    const submissionTime = new Date().toISOString();
    const resultRef = db.collection('results').doc();
    const resultId = resultRef.id;

    // Generate Result PDF
    let resultPdfUrl = '';
    let resultPdfPublicId = '';
    try {
      const pdfBuffer = await generateResultPDF({
        student: {
          name: attempt.studentName || req.user.name,
          email: attempt.studentEmail || req.user.email
        },
        exam: examData,
        result: evaluation,
        submittedAt: submissionTime
      });

      const cloudUpload = await uploadBuffer(pdfBuffer, {
        folder: 'mcq-portal/results',
        resource_type: 'raw',
        format: 'pdf'
      });

      resultPdfUrl = cloudUpload.secure_url;
      resultPdfPublicId = cloudUpload.public_id;
    } catch (pdfErr) {
      console.error('[SubmitExam] PDF generation/upload error:', pdfErr.message);
    }

    const resultRecord = {
      id: resultId,
      attemptId,
      studentId,
      studentName: attempt.studentName || req.user.name,
      studentEmail: attempt.studentEmail || req.user.email,
      examId,
      examTitle: examData.title,
      subject: examData.subject,
      totalQuestions: evaluation.totalQuestions,
      attempted: evaluation.attempted,
      correct: evaluation.correct,
      wrong: evaluation.wrong,
      unattempted: evaluation.unattempted,
      marksPerQuestion: evaluation.marksPerQuestion,
      negativeMarking: evaluation.negativeMarking,
      totalMarks: evaluation.totalMarks,
      passingMarks: evaluation.passingMarks,
      score: evaluation.score,
      percentage: evaluation.percentage,
      status: evaluation.status,
      grade: evaluation.grade,
      timeTaken: evaluation.timeTaken,
      resultPdfUrl,
      resultPdfPublicId,
      submittedAt: submissionTime,
      questionAnalysis: evaluation.questionAnalysis
    };

    // Commit Result & Update Attempt
    const batch = db.batch();
    batch.set(resultRef, resultRecord);
    batch.update(attemptRef, {
      status: 'completed',
      answers: finalAnswers,
      score: evaluation.score,
      percentage: evaluation.percentage,
      resultId,
      submittedAt: submissionTime,
      updatedAt: submissionTime
    });
    await batch.commit();

    return successResponse(res, resultRecord, 'Examination submitted and evaluated successfully');
  } catch (err) {
    next(err);
  }
};

/**
 * GET /api/student/result/:resultId
 * Retrieves detailed result scorecard
 */
const getResult = async (req, res, next) => {
  try {
    const { resultId } = req.params;
    const studentId = req.user.uid;
    const db = getDb();

    // Check if queried by result ID or attempt ID
    let doc = await db.collection('results').doc(resultId).get();
    if (!doc.exists) {
      const snap = await db.collection('results').where('attemptId', '==', resultId).limit(1).get();
      if (snap.empty) {
        return errorResponse(res, 'Result not found', 'NOT_FOUND', 404);
      }
      doc = snap.docs[0];
    }

    const data = doc.data();
    // Verify ownership if student
    if (req.user.role === 'student' && data.studentId !== studentId) {
      return errorResponse(res, 'Access denied', 'FORBIDDEN', 403);
    }

    return successResponse(res, { id: doc.id, ...data }, 'Result retrieved successfully');
  } catch (err) {
    next(err);
  }
};

/**
 * GET /api/student/history
 * Lists all completed exam attempts and their outcomes for current student
 */
const getExamHistory = async (req, res, next) => {
  try {
    const studentId = req.user.uid;
    const db = getDb();

    const resultsSnap = await db.collection('results').where('studentId', '==', studentId).get();
    const results = resultsSnap.docs.map(doc => ({ id: doc.id, ...doc.data() }));

    // Sort by submittedAt descending
    results.sort((a, b) => new Date(b.submittedAt || 0) - new Date(a.submittedAt || 0));

    return successResponse(res, results, 'Examination history retrieved');
  } catch (err) {
    next(err);
  }
};

/**
 * POST /api/student/result/:attemptId/pdf
 * Generates or returns Cloudinary PDF URL for downloading
 */
const getResultPdf = async (req, res, next) => {
  try {
    const { attemptId } = req.params;
    const db = getDb();

    const resultsSnap = await db.collection('results').where('attemptId', '==', attemptId).limit(1).get();
    if (resultsSnap.empty) {
      return errorResponse(res, 'Result not found for the specified attempt', 'NOT_FOUND', 404);
    }

    const resultData = resultsSnap.docs[0].data();
    return successResponse(res, {
      pdfUrl: resultData.resultPdfUrl,
      publicId: resultData.resultPdfPublicId
    }, 'PDF link retrieved');
  } catch (err) {
    next(err);
  }
};

module.exports = {
  getAvailableExams,
  startExam,
  saveAnswer,
  submitExam,
  getResult,
  getExamHistory,
  getResultPdf
};
