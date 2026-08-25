/**
 * File upload service.
 *
 * Strategy:
 *  - If S3_BUCKET + S3_ACCESS_KEY + S3_SECRET_KEY are set → multer-s3 (prod)
 *  - Otherwise → local disk (dev only; ephemeral on Render)
 *
 * All route handlers use the same `upload` multer middleware and `getFileUrl`
 * so swapping storage requires no route changes.
 */
const multer = require('multer');
const multerS3 = require('multer-s3');
const { S3Client } = require('@aws-sdk/client-s3');
const path = require('path');
const fs = require('fs');
const { v4: uuidv4 } = require('uuid');

const ALLOWED_MIME_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'image/heic'];
const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10 MB

function fileFilter(_req, file, cb) {
  if (ALLOWED_MIME_TYPES.includes(file.mimetype)) {
    cb(null, true);
  } else {
    cb(Object.assign(new Error('Only image files are allowed'), { status: 400 }));
  }
}

const useS3 = !!(
  process.env.S3_BUCKET &&
  process.env.S3_ACCESS_KEY &&
  process.env.S3_SECRET_KEY
);

let upload;

if (useS3) {
  const s3 = new S3Client({
    region: process.env.S3_REGION || 'us-east-1',
    endpoint: process.env.S3_ENDPOINT || undefined,
    credentials: {
      accessKeyId: process.env.S3_ACCESS_KEY,
      secretAccessKey: process.env.S3_SECRET_KEY,
    },
    forcePathStyle: !!process.env.S3_ENDPOINT,
  });

  upload = multer({
    storage: multerS3({
      s3,
      bucket: process.env.S3_BUCKET,
      acl: 'public-read',
      contentType: multerS3.AUTO_CONTENT_TYPE,
      key: (_req, file, cb) => {
        const ext = path.extname(file.originalname).toLowerCase() || '.jpg';
        cb(null, `receipts/${uuidv4()}${ext}`);
      },
    }),
    limits: { fileSize: MAX_FILE_SIZE },
    fileFilter,
  });

  console.log('[Upload] S3-compatible storage →', process.env.S3_BUCKET);
} else {
  const UPLOAD_DIR = path.join(__dirname, '../../uploads');
  if (!fs.existsSync(UPLOAD_DIR)) fs.mkdirSync(UPLOAD_DIR, { recursive: true });

  upload = multer({
    storage: multer.diskStorage({
      destination: (_req, _file, cb) => cb(null, UPLOAD_DIR),
      filename: (_req, file, cb) => {
        const ext = path.extname(file.originalname).toLowerCase() || '.jpg';
        cb(null, `${uuidv4()}${ext}`);
      },
    }),
    limits: { fileSize: MAX_FILE_SIZE },
    fileFilter,
  });

  console.log('[Upload] Local disk storage (dev) — set S3_* env vars for production');
}

/**
 * Returns the public URL for an uploaded file.
 * - S3 mode: multer-s3 sets req.file.location automatically.
 * - Local mode: construct from request host.
 */
function getFileUrl(req, filenameOrLocation) {
  if (useS3) return filenameOrLocation; // multer-s3 sets req.file.location
  const base = process.env.BASE_URL || `${req.protocol}://${req.get('host')}`;
  return `${base}/uploads/${filenameOrLocation}`;
}

module.exports = { upload, getFileUrl, useS3 };
