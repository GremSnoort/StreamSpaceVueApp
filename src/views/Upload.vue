<template>
  <div class="upload-wrapper">
    <h1 class="page-title">Upload New Video</h1>

    <div class="form-box">
      <!-- Title -->
      <label class="label">Video Title</label>
      <input
        v-model="title"
        placeholder="Enter a video title"
        class="textfield"
      />

      <!-- Description -->
      <label class="label">Description</label>
      <textarea
        v-model="description"
        placeholder="Enter a short description"
        class="textfield textarea"
      ></textarea>

      <!-- Drag & Drop -->
      <div
        class="drop-zone"
        @dragover.prevent="dragging = true"
        @dragleave.prevent="dragging = false"
        @drop.prevent="handleDrop"
        :class="{ dragging }"
      >
        <p v-if="!file">Drop a video file here or click to choose…</p>
        <p v-else>Selected: <strong>{{ file.name }}</strong></p>

        <input
          ref="fileInput"
          type="file"
          accept="video/*"
          class="hidden-input"
          @change="handleFileSelect"
        />
      </div>

      <!-- Upload Button -->
      <button class="upload-btn" :disabled="!file || uploading" @click="upload">
        {{ uploading ? "Uploading…" : "Upload" }}
      </button>
    </div>
  </div>
</template>

<script setup>
import { ref } from "vue";
import http from "../lib/http";
import { useRouter } from "vue-router";

const title = ref("");
const description = ref("");
const file = ref(null);
const dragging = ref(false);
const uploading = ref(false);

const fileInput = ref(null);
const router = useRouter();

function handleFileSelect(e) {
  file.value = e.target.files[0];
}

function handleDrop(e) {
  dragging.value = false;
  const dropped = e.dataTransfer.files[0];
  if (dropped) file.value = dropped;
}

function openFileDialog() {
  fileInput.value?.click();
}

async function upload() {
  if (!file.value) return;

  uploading.value = true;
  const formData = new FormData();

  formData.append("title", title.value);
  formData.append("description", description.value);
  formData.append("file", file.value);

  try {
    await http.post("/upload/new", formData, {
      headers: { "Content-Type": "multipart/form-data" }
    });

    router.push({ name: "gallery" });
  } catch (err) {
    console.error("Upload failed:", err);
    alert("Upload failed!");
  }

  uploading.value = false;
}
</script>

<style scoped>
.upload-wrapper {
  max-width: 700px;
  margin: 0 auto;
  padding: 30px;
  color: white;
  background: linear-gradient(145deg, #0f0f0f, #151515);
  border-radius: 18px;
}

.page-title {
  font-size: 34px;
  font-weight: 800;
  margin-bottom: 25px;
  text-align: center;

  background: linear-gradient(to right, #6aa8ff, #b1d1ff);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
}

.form-box {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.label {
  font-size: 15px;
  font-weight: 600;
  color: #9bc6ff;
}

.textfield {
  width: 100%;
  padding: 12px 14px;
  border-radius: 10px;
  border: 1px solid #2f2f2f;
  background: #101010;
  color: white;
  font-size: 15px;
}

.textarea {
  min-height: 90px;
  resize: vertical;
}

.drop-zone {
  border: 2px dashed #2d4da8;
  border-radius: 12px;
  padding: 45px 20px;
  text-align: center;
  cursor: pointer;
  transition: 0.25s;
  background: #111;
  color: #c7d8ff;
}

.drop-zone.dragging {
  border-color: #5a86ff;
  background: rgba(35, 72, 255, 0.15);
}

.hidden-input {
  display: none;
}

.upload-btn {
  padding: 14px 0;
  font-size: 18px;
  font-weight: 700;
  border: none;
  border-radius: 12px;
  color: white;
  background: linear-gradient(135deg, #1e3cff, #0b1a88);
  cursor: pointer;
  box-shadow: 0 6px 16px rgba(40, 60, 255, 0.55);
  transition: 0.25s;
}

.upload-btn:hover:not(:disabled) {
  transform: translateY(-2px);
  background: linear-gradient(135deg, #304eff, #1627a3);
}

.upload-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
</style>
