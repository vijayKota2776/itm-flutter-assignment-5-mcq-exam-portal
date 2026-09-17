const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/auth');
const { requireAdmin } = require('../middleware/roles');
const upload = require('../middleware/upload');
const adminController = require('../controllers/adminController');

// All routes here require authenticated administrator
router.use(authMiddleware, requireAdmin);

router.post('/upload-excel', upload.single('file'), adminController.uploadExcel);
router.post('/exam', adminController.createExam);
router.get('/exams', adminController.getExams);
router.get('/exam/:id', adminController.getExamById);
router.put('/exam/:id', adminController.updateExam);
router.delete('/exam/:id', adminController.deleteExam);
router.get('/students', adminController.getStudents);
router.get('/report/:examId', adminController.getExamReport);
router.post('/report/:examId/export', adminController.exportReport);
router.get('/dashboard-stats', adminController.getDashboardStats);

module.exports = router;
