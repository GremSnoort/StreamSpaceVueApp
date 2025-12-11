const express = require("express");
const multer = require("multer");
const path = require("path");
const fs = require("fs");

const router = express.Router();

// -------------------------
// Ensure upload dirs exist
// -------------------------
const uploadDir = path.join(__dirname, "uploads/videos");
const dbFile = path.join(__dirname, "uploads/media.json");

fs.mkdirSync(uploadDir, { recursive: true });

// if DB file doesn't exist → create it
if (!fs.existsSync(dbFile)) {
  fs.writeFileSync(dbFile, JSON.stringify([]));
}

// Load DB
function loadDB() {
  return JSON.parse(fs.readFileSync(dbFile, "utf8"));
}

// Save DB
function saveDB(data) {
  fs.writeFileSync(dbFile, JSON.stringify(data, null, 2));
}

// -------------------------
// Multer config
// -------------------------
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadDir),
  filename: (req, file, cb) => {
    const unique = Date.now() + "-" + Math.round(Math.random() * 1e9);
    cb(null, unique + path.extname(file.originalname));
  }
});

const upload = multer({ storage });

// -------------------------
// Upload Route
// -------------------------
router.post("/upload", upload.single("file"), (req, res) => {
  if (!req.file) return res.status(400).json({ error: "No file uploaded" });

  const { title, description } = req.body;
  const fileUrl = `/videos/${req.file.filename}`;

  // create new media record
  const entry = {
    id: Date.now().toString(),
    title,
    description,
    url: fileUrl,      // for player
    playUrl: fileUrl,  // m3u8 @TODO !!!
    preview: fileUrl,  // TODO: replace with thumbnail
    createdAt: new Date().toISOString()
  };

  // save into DB
  const db = loadDB();
  db.push(entry);
  saveDB(db);

  res.json(entry);
});

// -------------------------
// List all media
// -------------------------
router.get("/", (req, res) => {
  const db = loadDB();
  res.json(db);
});

module.exports = router;
