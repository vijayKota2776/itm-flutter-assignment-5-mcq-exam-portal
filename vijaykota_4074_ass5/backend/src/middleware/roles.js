const { errorResponse } = require('../utils/response');

const requireAdmin = (req, res, next) => {
  if (!req.user) {
    return errorResponse(res, 'Authentication required', 'UNAUTHORIZED', 401);
  }
  if (req.user.role !== 'admin') {
    return errorResponse(res, 'Access denied: Administrator privilege required', 'FORBIDDEN', 403);
  }
  next();
};

const requireStudent = (req, res, next) => {
  if (!req.user) {
    return errorResponse(res, 'Authentication required', 'UNAUTHORIZED', 401);
  }
  if (req.user.role !== 'student') {
    return errorResponse(res, 'Access denied: Student account required', 'FORBIDDEN', 403);
  }
  next();
};

module.exports = {
  requireAdmin,
  requireStudent
};
