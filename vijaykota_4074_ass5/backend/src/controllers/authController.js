const { getDb } = require('../config/firebase');
const { successResponse, errorResponse } = require('../utils/response');

/**
 * GET /api/auth/me
 * Returns current authenticated user profile and authoritative role
 */
const getMe = async (req, res, next) => {
  try {
    const { uid } = req.user;
    const db = getDb();
    const doc = await db.collection('users').doc(uid).get();

    if (!doc.exists) {
      return errorResponse(res, 'User record not found in database', 'NOT_FOUND', 404);
    }

    const userData = doc.data();
    return successResponse(res, userData, 'User profile retrieved successfully');
  } catch (err) {
    next(err);
  }
};

/**
 * POST /api/auth/sync-user
 * Synchronizes user state after Firebase Auth login/registration
 */
const syncUser = async (req, res, next) => {
  try {
    const { uid, email, name, photoUrl } = req.body;
    const authUid = req.user.uid;

    if (uid && uid !== authUid) {
      return errorResponse(res, 'User identity mismatch', 'FORBIDDEN', 403);
    }

    const db = getDb();
    const userRef = db.collection('users').doc(authUid);
    const existingDoc = await userRef.get();

    let role = 'student';
    const normalizedEmail = (email || req.user.email || '').toLowerCase().trim();

    if (existingDoc.exists) {
      const existingData = existingDoc.data();
      role = existingData.role || 'student'; // Never trust client-sent role
    } else {
      // Role determination: check default admin email configuration
      if (
        normalizedEmail === (process.env.DEFAULT_ADMIN_EMAIL || 'admin@itm.edu').toLowerCase() ||
        normalizedEmail.endsWith('@admin.itm.edu')
      ) {
        role = 'admin';
      }
    }

    const userData = {
      uid: authUid,
      email: normalizedEmail || req.user.email,
      name: name || req.user.name || normalizedEmail.split('@')[0] || 'User',
      role,
      photoUrl: photoUrl || req.user.photoUrl || '',
      lastLogin: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };

    if (!existingDoc.exists) {
      userData.createdAt = new Date().toISOString();
    }

    await userRef.set(userData, { merge: true });

    return successResponse(res, userData, 'User synchronized successfully');
  } catch (err) {
    next(err);
  }
};

/**
 * POST /api/auth/profile
 * Updates user profile details
 */
const updateProfile = async (req, res, next) => {
  try {
    const { uid } = req.user;
    const { name, photoUrl } = req.body;

    const db = getDb();
    const userRef = db.collection('users').doc(uid);

    const updates = {
      updatedAt: new Date().toISOString()
    };
    if (name) updates.name = String(name).trim();
    if (photoUrl !== undefined) updates.photoUrl = String(photoUrl).trim();

    await userRef.update(updates);
    const updated = (await userRef.get()).data();

    return successResponse(res, updated, 'Profile updated successfully');
  } catch (err) {
    next(err);
  }
};

module.exports = {
  getMe,
  syncUser,
  updateProfile
};
