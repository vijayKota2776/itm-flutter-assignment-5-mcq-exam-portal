/**
 * Standardized API Response Utilities
 */

const successResponse = (res, data = {}, message = 'Success', statusCode = 200) => {
  return res.status(statusCode).json({
    success: true,
    message,
    data
  });
};

const errorResponse = (res, message = 'Internal Server Error', errorCode = 'ERROR', statusCode = 400, details = null) => {
  const response = {
    success: false,
    message,
    errorCode
  };
  if (details) {
    response.details = details;
  }
  return res.status(statusCode).json(response);
};

module.exports = {
  successResponse,
  errorResponse
};
