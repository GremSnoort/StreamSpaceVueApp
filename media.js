const express = require("express");
const multer = require("multer");
const path = require("path");
const fs = require("fs");
const { exec } = require("child_process");

const router = express.Router();

// -------------------------
// Ensure upload dirs exist
// -------------------------
const videoDir = path.join(__dirname, "uploads/videos");
const previewDir = path.join(__dirname, "uploads/previews");
const dbFile = path.join(__dirname, "uploads/media.json");

fs.mkdirSync(videoDir, { recursive: true });
fs.mkdirSync(previewDir, { recursive: true });

if (!fs.existsSync(dbFile)) {
  fs.writeFileSync(dbFile, JSON.stringify([]));
}

function loadDB() {
  return JSON.parse(fs.readFileSync(dbFile, "utf8"));
}

function saveDB(data) {
  fs.writeFileSync(dbFile, JSON.stringify(data, null, 2));
}

// -------------------------
// Multer config
// -------------------------
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, videoDir),
  filename: (req, file, cb) => {
    const unique = Date.now() + "-" + Math.round(Math.random() * 1e9);
    cb(null, unique + path.extname(file.originalname));
  }
});

const upload = multer({ storage });

// -------------------------
// Upload Route + Thumbnail
// -------------------------
router.post("/upload", upload.single("file"), (req, res) => {
  if (!req.file) return res.status(400).json({ error: "No file uploaded" });

  const { title, description } = req.body;

  const videoPath = req.file.path;
  const videoUrl = `/videos/${req.file.filename}`;

  const previewFile = req.file.filename.replace(path.extname(req.file.filename), ".jpg");
  const previewPath = path.join(previewDir, previewFile);
  const previewUrl = `/previews/${previewFile}`;

  // Generate thumbnail at 2-second mark
  const ffmpegCmd = `ffmpeg -ss 2 -i "${videoPath}" -frames:v 1 -q:v 2 "${previewPath}" -y`;

  exec(ffmpegCmd, (err) => {
    if (err) {
      console.error("Thumbnail generation failed:", err);
    }

    const entry = {
      id: Date.now().toString(),
      title,
      description,
      url: videoUrl,
      playUrl: videoUrl,
      preview: previewUrl,
      createdAt: new Date().toISOString()
    };

    const db = loadDB();
    db.push(entry);
    saveDB(db);

    res.json(entry);
  });
});

// -------------------------
// Delete media
// -------------------------
router.delete("/:id", (req, res) => {
  const { id } = req.params;

  const db = loadDB();
  const item = db.find(v => v.id === id);

  if (!item) {
    return res.status(404).json({ error: "Not found" });
  }

  // Remove db entry
  const updated = db.filter(v => v.id !== id);
  saveDB(updated);

  // Remove files
  try {
    if (item.url) {
      const filePath = path.join(__dirname, "uploads", item.url.replace(/^\/+/, ""));
      fs.unlink(filePath, () => {});
    }

    if (item.preview) {
      const thumbPath = path.join(__dirname, "uploads", item.preview.replace(/^\/+/, ""));
      fs.unlink(thumbPath, () => {});
    }
  } catch (err) {
    console.warn("Delete cleanup error:", err);
  }

  res.json({ success: true });
});

// -------------------------
// List uploaded media
// -------------------------
router.get("/", (req, res) => {
  res.json(loadDB());
});

module.exports = router;
