const express = require("express");
const multer = require("multer");
const path = require("path");
const fs = require("fs");

const router = express.Router();

// -------------------------
// Ensure upload folder exists
// -------------------------
const uploadDir = path.join(__dirname, "uploads/videos");
fs.mkdirSync(uploadDir, { recursive: true });

// -------------------------
// Multer config
// -------------------------
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const unique = Date.now() + "-" + Math.round(Math.random() * 1e9);
    const ext = path.extname(file.originalname);
    cb(null, unique + ext);
  }
});

const upload = multer({ storage });

// -------------------------
// Routes
// -------------------------

// Upload route
router.post("/new", upload.single("file"), (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: "No file uploaded" });
  }

  const { title, description } = req.body;

  const fileUrl = `/videos/${req.file.filename}`;

  const saved = {
    id: Date.now(),
    title,
    description,
    url: fileUrl,
    preview: fileUrl, // you might replace this with a generated thumbnail
  };

  res.json(saved);
});

// List media (mocked)
router.get("/", (req, res) => {
  // Replace with real DB logic if needed
  res.json([]);
});

module.exports = router;
