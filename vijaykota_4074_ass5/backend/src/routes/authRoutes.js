const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/auth');
const authController = require('../controllers/authController');

router.get('/me', authMiddleware, authController.getMe);
router.post('/sync-user', authMiddleware, authController.syncUser);
router.post('/profile', authMiddleware, authController.updateProfile);

module.exports = router;
