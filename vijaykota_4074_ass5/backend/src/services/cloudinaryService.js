const { cloudinary, isConfigured } = require('../config/cloudinary');
const { Readable } = require('stream');

/**
 * Upload a buffer to Cloudinary
 * @param {Buffer} buffer - File buffer
 * @param {Object} options - Cloudinary upload options (folder, resource_type, public_id)
 * @returns {Promise<{ public_id: string, secure_url: string, format: string, resource_type: string, created_at: string }>}
 */
const uploadBuffer = (buffer, options = {}) => {
  return new Promise((resolve, reject) => {
    if (!isConfigured()) {
      const mockPublicId = `${options.folder || 'mcq-portal'}/sim_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
      const ext = options.resource_type === 'image' ? '.png' : options.format ? `.${options.format}` : '.bin';
      const mockUrl = `https://res.cloudinary.com/itm-skills-university/raw/upload/v${Date.now()}/${mockPublicId}${ext}`;

      return resolve({
        public_id: mockPublicId,
        secure_url: mockUrl,
        format: options.format || 'auto',
        resource_type: options.resource_type || 'auto',
        created_at: new Date().toISOString()
      });
    }

    const uploadStream = cloudinary.uploader.upload_stream(options, (error, result) => {
      if (error) {
        console.error('[Cloudinary] Upload failed:', error);
        return reject(error);
      }
      resolve({
        public_id: result.public_id,
        secure_url: result.secure_url,
        format: result.format,
        resource_type: result.resource_type,
        created_at: result.created_at || new Date().toISOString()
      });
    });

    // Pipe buffer to upload stream
    if (buffer) {
      const readableStream = Readable.from(buffer);
      readableStream.pipe(uploadStream);
    } else {
      reject(new Error('Buffer cannot be empty'));
    }
  });
};

/**
 * Delete an asset from Cloudinary
 * @param {string} publicId - Cloudinary asset public ID
 * @param {string} resourceType - 'image', 'raw', 'video'
 */
const deleteAsset = async (publicId, resourceType = 'raw') => {
  if (!publicId) return { result: 'not_found' };
  if (!isConfigured()) {
    return { result: 'ok', mock: true };
  }
  try {
    const result = await cloudinary.uploader.destroy(publicId, { resource_type: resourceType });
    return result;
  } catch (err) {
    console.error(`[Cloudinary] Asset deletion failed for ${publicId}:`, err.message);
    return { result: 'error', error: err.message };
  }
};

module.exports = {
  uploadBuffer,
  deleteAsset
};
