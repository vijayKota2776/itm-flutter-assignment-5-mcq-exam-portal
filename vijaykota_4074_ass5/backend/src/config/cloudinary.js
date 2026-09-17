const cloudinary = require('cloudinary').v2;
const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../../.env') });

const cloudName = process.env.CLOUDINARY_CLOUD_NAME;
const apiKey = process.env.CLOUDINARY_API_KEY;
const apiSecret = process.env.CLOUDINARY_API_SECRET;

const isConfigured = Boolean(cloudName && apiKey && apiSecret);

if (isConfigured) {
  cloudinary.config({
    cloud_name: cloudName,
    api_key: apiKey,
    api_secret: apiSecret,
    secure: true
  });
  console.log('[Cloudinary] Initialized successfully with Cloud Name:', cloudName);
} else {
  console.warn('[Cloudinary] Incomplete Cloudinary credentials (cloud_name/api_key/api_secret).');
  console.warn('[Cloudinary] Operating in fallback mode. Cloudinary uploads will return simulated secure URLs.');
}

module.exports = {
  cloudinary,
  isConfigured: () => isConfigured
};
