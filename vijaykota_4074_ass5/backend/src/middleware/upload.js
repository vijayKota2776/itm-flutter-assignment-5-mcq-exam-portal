const multer = require('multer');
const path = require('path');

// Memory storage keeps file buffer in memory for direct parsing or streaming to Cloudinary
const storage = multer.memoryStorage();

const allowedExtensions = ['.xlsx', '.xls', '.csv', '.png', '.jpg', '.jpeg', '.pdf'];

const fileFilter = (req, file, cb) => {
  const ext = path.extname(file.originalname).toLowerCase();
  if (allowedExtensions.includes(ext)) {
    cb(null, true);
  } else {
    cb(new Error(`Unsupported file format (${ext}). Allowed formats: ${allowedExtensions.join(', ')}`), false);
  }
};

const upload = multer({
  storage,
  limits: {
    fileSize: 15 * 1024 * 1024 // 15MB limit
  },
  fileFilter
});

module.exports = upload;
