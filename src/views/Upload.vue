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
          class="input"
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
          class="input input-textarea"
          placeholder="Enter a short description"
        />
      </label>

      <!-- Drop zone -->
      <button
        type="button"
        class="drop"
        :class="{ 'is-dragging': dragging, 'has-file': !!file }"
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
            Selected: <strong class="drop-file">{{ file.name }}</strong>
          </p>

          <p class="drop-hint">Supported: MP4 / video/*</p>
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
  color: var(--primary);
  opacity: 0.85;
}

/* form */
.upload-form {
  display: grid;
  gap: var(--space-4);
}

/* textarea sizing */
.input-textarea {
  min-height: 110px;
  resize: vertical;
}

/* drop zone */
.drop {
  width: 100%;
  border-radius: var(--r-lg);
  padding: 26px;
  text-align: center;
  cursor: pointer;

  border: 2px dashed var(--glass-border);
  background: linear-gradient(145deg, var(--glass-1), var(--glass-2));
  box-shadow: var(--shadow-soft);

  backdrop-filter: blur(14px);
  -webkit-backdrop-filter: blur(14px);

  transition: transform 0.2s, box-shadow 0.2s, border-color 0.2s, background 0.2s;
}

.drop:hover {
  transform: translateY(-1px);
  box-shadow: var(--shadow-md);
}

.drop.is-dragging {
  border-color: var(--ui-border-strong);
  box-shadow: var(--shadow-lg);
  transform: translateY(-2px);
}

.drop.has-file {
  border-color: var(--ui-border-med);
}

.drop-inner {
  display: grid;
  gap: 10px;
  place-items: center;
}

.drop-icon {
  width: 42px;
  height: 42px;
  border-radius: 14px;

  display: grid;
  place-items: center;

  background: var(--ui-surface-1);
  border: 1px solid var(--ui-border-1);

  color: var(--text);
  font-weight: 900;
}

.drop-text {
  margin: 0;
  color: var(--ui-fg-1);
}

.drop-file {
  color: var(--text);
}

.drop-hint {
  margin: 0;
  font-size: 12px;
  color: var(--ui-fg-2);
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

/* disabled state */
.btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
  transform: none;
}

</style>
