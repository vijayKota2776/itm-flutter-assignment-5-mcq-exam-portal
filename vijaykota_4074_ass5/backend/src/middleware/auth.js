const jwt = require('jsonwebtoken');
const { admin, getDb, isMockDb } = require('../config/firebase');
const { errorResponse } = require('../utils/response');

const JWT_SECRET = process.env.JWT_SECRET || 'itm_skills_university_jwt_secret_default_key';

const authMiddleware = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    const mockRoleHeader = req.headers['x-mock-role'];

    // 1. Development/Testing quick token support
    if (mockRoleHeader && (mockRoleHeader === 'admin' || mockRoleHeader === 'student')) {
      const mockUid = mockRoleHeader === 'admin' ? 'admin_test_uid' : 'student_test_uid';
      const mockEmail = mockRoleHeader === 'admin' ? 'admin@itm.edu' : 'student@itm.edu';
      const mockName = mockRoleHeader === 'admin' ? 'ITM Admin' : 'ITM Student';

      // Ensure user exists in Firestore
      const db = getDb();
      const userRef = db.collection('users').doc(mockUid);
      const userDoc = await userRef.get();
      if (!userDoc.exists) {
        await userRef.set({
          uid: mockUid,
          email: mockEmail,
          name: mockName,
          role: mockRoleHeader,
          photoUrl: '',
          createdAt: new Date().toISOString(),
          lastLogin: new Date().toISOString()
        });
      }

      req.user = {
        uid: mockUid,
        email: mockEmail,
        name: mockName,
        role: mockRoleHeader
      };
      return next();
    }

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return errorResponse(res, 'Authentication token missing or malformed', 'UNAUTHORIZED', 401);
    }

    const token = authHeader.split('Bearer ')[1].trim();

    // 2. Check for simple test tokens
    if (token === 'test-admin-token' || token === 'test-student-token') {
      const role = token === 'test-admin-token' ? 'admin' : 'student';
      const uid = `${role}_test_uid`;
      const email = `${role}@itm.edu`;
      const name = role === 'admin' ? 'ITM Admin' : 'ITM Student';

      const db = getDb();
      const userRef = db.collection('users').doc(uid);
      const userDoc = await userRef.get();
      if (!userDoc.exists) {
        await userRef.set({
          uid,
          email,
          name,
          role,
          photoUrl: '',
          createdAt: new Date().toISOString(),
          lastLogin: new Date().toISOString()
        });
      }

      req.user = { uid, email, name, role };
      return next();
    }

    let decoded = null;

    // 3. Try JWT verification (for custom backend auth or admin scripts)
    try {
      decoded = jwt.verify(token, JWT_SECRET);
    } catch {
      // If JWT verification fails, proceed to Firebase token verification
    }

    // 4. Try Firebase ID Token verification
    if (!decoded) {
      try {
        if (admin && admin.auth) {
          decoded = await admin.auth().verifyIdToken(token);
        }
      } catch (fbErr) {
        console.warn('[AuthMiddleware] Firebase verifyIdToken error:', fbErr.message);
      }
    }

    if (!decoded) {
      return errorResponse(res, 'Invalid or expired authentication token', 'INVALID_TOKEN', 401);
    }

    const uid = decoded.uid || decoded.sub || decoded.id;
    const email = decoded.email || '';

    // Fetch user record from Firestore to get verified role
    const db = getDb();
    const userDoc = await db.collection('users').doc(uid).get();

    if (!userDoc.exists) {
      // Auto-provision if user exists in Firebase Auth
      const defaultRole = (email.toLowerCase().includes('admin') || email === process.env.DEFAULT_ADMIN_EMAIL)
        ? 'admin'
        : 'student';

      const newUser = {
        uid,
        email,
        name: decoded.name || email.split('@')[0] || 'User',
        role: decoded.role || defaultRole,
        photoUrl: decoded.picture || '',
        createdAt: new Date().toISOString(),
        lastLogin: new Date().toISOString()
      };

      await db.collection('users').doc(uid).set(newUser);
      req.user = newUser;
    } else {
      req.user = {
        uid,
        ...userDoc.data()
      };
    }

    next();
  } catch (err) {
    console.error('[AuthMiddleware] Error:', err);
    return errorResponse(res, 'Authentication failed', 'AUTH_ERROR', 401, err.message);
  }
};

module.exports = authMiddleware;
