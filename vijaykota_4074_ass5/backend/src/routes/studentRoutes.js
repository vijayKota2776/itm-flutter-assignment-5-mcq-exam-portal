const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/auth');
const { requireStudent } = require('../middleware/roles');
const studentController = require('../controllers/studentController');

// All student routes require authenticated student
router.use(authMiddleware);

router.get('/exams', requireStudent, studentController.getAvailableExams);
router.post('/exam/:id/start', requireStudent, studentController.startExam);
router.post('/exam/:id/save-answer', requireStudent, studentController.saveAnswer);
router.post('/exam/:id/submit', requireStudent, studentController.submitExam);
router.get('/result/:resultId', studentController.getResult);
router.post('/result/:attemptId/pdf', studentController.getResultPdf);
router.get('/history', requireStudent, studentController.getExamHistory);

module.exports = router;
