/**
 * File upload service.
 * Uses multer with either local disk storage (dev/MVP) or S3-compatible storage (prod).
 */
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { v4: uuidv4 } = require('uuid');

const UPLOAD_DIR = path.join(__dirname, '../../uploads');

// Ensure upload directory exists in development
if (!fs.existsSync(UPLOAD_DIR)) {
  fs.mkdirSync(UPLOAD_DIR, { recursive: true });
}

const ALLOWED_MIME_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'image/heic'];
const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10 MB

function fileFilter(_req, file, cb) {
  if (ALLOWED_MIME_TYPES.includes(file.mimetype)) {
    cb(null, true);
  } else {
    cb(Object.assign(new Error('Only image files are allowed'), { status: 400 }));
  }
}

// ── Local disk storage ─────────────────────────────────────────────────────
const localStorage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, UPLOAD_DIR),
  filename: (_req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase() || '.jpg';
    cb(null, `${uuidv4()}${ext}`);
  },
});

const upload = multer({
  storage: localStorage,
  limits: { fileSize: MAX_FILE_SIZE },
  fileFilter,
});

/**
 * Return the public URL for a locally stored file.
 * In production, swap this for an S3 presigned or CDN URL.
 */
function getFileUrl(req, filename) {
  const base = process.env.BASE_URL || `${req.protocol}://${req.get('host')}`;
  return `${base}/uploads/${filename}`;
}

module.exports = { upload, getFileUrl };
