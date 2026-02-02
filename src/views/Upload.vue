<template>
  <div class="page panel upload">
    <header class="upload-header">
      <h1 class="title">Upload New Video</h1>
      <p class="upload-subtitle">Add a title, description and upload your file.</p>
    </header>

    <form class="upload-form" @submit.prevent="upload">
      <!-- Title -->
      <label class="field">
        <span class="field-label">Video Title</span>
        <input
          v-model="title"
          class="control"
          type="text"
          placeholder="Enter a video title"
          autocomplete="off"
        />
      </label>

      <!-- Description -->
      <label class="field">
        <span class="field-label">Description</span>
        <textarea
          v-model="description"
          class="control control-textarea"
          placeholder="Enter a short description"
        ></textarea>
      </label>

      <!-- Drop zone -->
      <button
        type="button"
        class="drop"
        :class="{ dragging }"
        @click="openFileDialog"
        @dragover.prevent="dragging = true"
        @dragleave.prevent="dragging = false"
        @drop.prevent="handleDrop"
      >
        <div class="drop-inner">
          <div class="drop-icon">⬆</div>

          <p v-if="!file" class="drop-text">
            Drop a video file here or click to choose…
          </p>
          <p v-else class="drop-text">
            Selected: <strong>{{ file.name }}</strong>
          </p>

          <p class="drop-hint">Supported: MP4 / HLS source files (video/*)</p>
        </div>

        <input
          ref="fileInput"
          type="file"
          accept="video/*"
          class="hidden-input"
          @change="handleFileSelect"
        />
      </button>

      <!-- Actions -->
      <div class="actions">
        <button class="btn btn-primary btn-lg" type="submit" :disabled="!file || uploading">
          {{ uploading ? "Uploading…" : "Upload" }}
        </button>

        <button class="btn btn-secondary btn-lg" type="button" @click="goGallery">
          ← Back to Gallery
        </button>
      </div>
    </form>
  </div>
</template>

<script setup>
import { ref } from "vue"
import http from "../lib/http"
import { useRouter } from "vue-router"

const title = ref("")
const description = ref("")
const file = ref(null)
const dragging = ref(false)
const uploading = ref(false)

const fileInput = ref(null)
const router = useRouter()

function handleFileSelect(e) {
  file.value = e.target.files?.[0] || null
}

function handleDrop(e) {
  dragging.value = false
  const dropped = e.dataTransfer.files?.[0]
  if (dropped) file.value = dropped
}

function openFileDialog() {
  fileInput.value?.click()
}

function goGallery() {
  router.push({ name: "gallery" })
}

async function upload() {
  if (!file.value || uploading.value) return

  uploading.value = true
  const formData = new FormData()
  formData.append("title", title.value)
  formData.append("description", description.value)
  formData.append("file", file.value)

  try {
    await http.post("/media/upload", formData, {
      headers: { "Content-Type": "multipart/form-data" }
    })
    router.push({ name: "gallery" })
  } catch (err) {
    console.error("Upload failed:", err)
    alert("Upload failed!")
  } finally {
    uploading.value = false
  }
}
</script>

<style scoped>
/* page-specific only */

.upload {
  padding: 28px;
  max-width: 900px;
}

/* header */
.upload-header {
  margin-bottom: var(--space-5);
}

.upload-subtitle {
  margin: 10px 0 0;
  color: var(--muted);
  font-size: 14px;
  opacity: 0.9;
}

/* form */
.upload-form {
  display: grid;
  gap: var(--space-4);
}

/* fields */
.field {
  display: grid;
  gap: 8px;
}

.field-label {
  font-size: 14px;
  font-weight: 700;
  color: #9bc6ff;
}

.control {
  width: 100%;
  padding: 12px 14px;
  border-radius: var(--r-md);
  border: 1px solid rgba(30, 144, 255, 0.18);
  background: rgba(0, 0, 0, 0.35);
  color: #fff;
  font-size: 15px;
  outline: none;
  transition: border-color 0.2s, box-shadow 0.2s;
}

.control:focus {
  border-color: rgba(79, 138, 255, 0.85);
  box-shadow: 0 0 0 3px rgba(79, 138, 255, 0.18);
}

.control-textarea {
  min-height: 96px;
  resize: vertical;
}

/* drop zone */
.drop {
  border: 2px dashed rgba(79, 138, 255, 0.45);
  border-radius: var(--r-lg);
  background: rgba(0, 0, 0, 0.25);
  padding: 28px;
  cursor: pointer;
  text-align: center;
  transition: 0.2s;
}

.drop.dragging {
  border-color: rgba(79, 138, 255, 0.95);
  background: rgba(79, 138, 255, 0.12);
}

.drop-inner {
  display: grid;
  gap: 10px;
  place-items: center;
}

.drop-icon {
  width: 42px;
  height: 42px;
  border-radius: 12px;
  display: grid;
  place-items: center;
  background: rgba(79, 138, 255, 0.15);
  border: 1px solid rgba(79, 138, 255, 0.25);
  color: #cfe8ff;
  font-weight: 800;
}

.drop-text {
  margin: 0;
  color: rgba(255, 255, 255, 0.82);
}

.drop-hint {
  margin: 0;
  font-size: 12px;
  color: rgba(255, 255, 255, 0.55);
}

.hidden-input {
  display: none;
}

/* actions */
.actions {
  display: flex;
  gap: 12px;
  flex-wrap: wrap;
  margin-top: var(--space-2);
}

.btn-lg {
  padding: 12px 18px;
  border-radius: var(--r-md);
  font-weight: 700;
}
</style>
