const express = require("express");
const multer = require("multer");
const path = require("path");
const fs = require("fs");
const { exec } = require("child_process");

const router = express.Router();

const API_BASE = "http://localhost:3001"

// -------------------------
// Ensure upload dirs exist
// -------------------------
const videoDir = path.join(__dirname, "uploads/videos");
const previewDir = path.join(__dirname, "uploads/previews");
const hlsDir = path.join(__dirname, "uploads/hls");
const dbFile = path.join(__dirname, "uploads/media.json");

fs.mkdirSync(videoDir, { recursive: true });
fs.mkdirSync(previewDir, { recursive: true });
fs.mkdirSync(hlsDir, { recursive: true });

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

  const id = Date.now().toString();

  const videoPath = req.file.path;
  const videoUrl = `/videos/${req.file.filename}`;

  // HLS output
  const hlsOutputDir = path.join(hlsDir, id);
  fs.mkdirSync(hlsOutputDir, { recursive: true });

  const hlsPlaylist = path.join(hlsOutputDir, "master.m3u8");
  const playUrl = `${API_BASE}/hls/${id}/master.m3u8`

  // Thumbnail
  const previewFile = `${id}.jpg`;
  const previewPath = path.join(previewDir, previewFile);
  const previewUrl = `${API_BASE}/previews/${previewFile}`

  // Generate thumbnail at 2-second mark
  const thumbnailCmd =
    `ffmpeg -ss 2 -i "${videoPath}" -frames:v 1 -q:v 2 "${previewPath}" -y`;

  const hlsCmd =
    `ffmpeg -i "${videoPath}" \
    -profile:v baseline -level 3.0 \
    -start_number 0 \
    -hls_time 6 -hls_list_size 0 \
    -f hls "${hlsPlaylist}"`;

  exec(`${thumbnailCmd} && ${hlsCmd}`, (err) => {
    if (err) {
      console.error("FFmpeg failed:", err);
      return res.status(500).json({ error: "Processing failed" });
    }

    const entry = {
      id,
      title,
      description,
      url: `${API_BASE}${videoUrl}`,
      playUrl,
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
// Get single media by id
// -------------------------
router.get("/:id", (req, res) => {
  const { id } = req.params
  const db = loadDB()

  const item = db.find(v => String(v.id) === String(id))

  if (!item) {
    return res.status(404).json({ error: "Media not found" })
  }

  res.json(item)
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
