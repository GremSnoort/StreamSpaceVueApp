<script setup>
import { computed, ref, watch } from "vue";
import foldersService from "../../services/foldersService";
import videosService from "../../services/videosService";

const props = defineProps({
  treeType: { type: String, required: true }, // library | favorites
  title: { type: String, default: "Folders" }
});

const loading = ref(true);
const busy = ref(false);
const folders = ref([]);
const folderVideos = ref([]);
const selectedFolderId = ref(null);
const myVideos = ref([]);
const hotVideos = ref([]);
const addVideoId = ref("");
const newFolderName = ref("");
const newFolderParentId = ref("");
const renameValue = ref("");
const moveParentId = ref("");
const errorText = ref("");

const selectableParents = computed(() => [
  { id: "", name: "Root" },
  ...folders.value.map((f) => ({ id: f.id, name: `${"  ".repeat(f.depth)}${f.name}` }))
]);

const selectedFolder = computed(() => folders.value.find((f) => f.id === selectedFolderId.value) || null);

const treeRows = computed(() => {
  const byId = new Map(folders.value.map((f) => [f.id, f]));
  const childrenByParent = new Map();

  for (const f of folders.value) {
    const key = f.parent_id || "__root__";
    if (!childrenByParent.has(key)) childrenByParent.set(key, []);
    childrenByParent.get(key).push(f.id);
  }

  const isLastChild = (id) => {
    const node = byId.get(id);
    if (!node) return false;
    const siblings = childrenByParent.get(node.parent_id || "__root__") || [];
    return siblings[siblings.length - 1] === id;
  };

  return folders.value.map((f) => {
    if (!Array.isArray(f.path) || f.path.length <= 1) {
      return { ...f, treePrefix: "" };
    }

    let prefix = "";
    for (let i = 0; i < f.path.length - 1; i++) {
      const ancestorId = f.path[i];
      const isDirectParent = i === f.path.length - 2;
      if (isDirectParent) {
        prefix += isLastChild(f.id) ? "└─ " : "├─ ";
      } else {
        prefix += isLastChild(ancestorId) ? "   " : "│  ";
      }
    }
    return { ...f, treePrefix: prefix };
  });
});

const moveParentOptions = computed(() => {
  const selected = selectedFolder.value;
  if (!selected) return [{ id: "", name: "Root" }];

  return [
    { id: "", name: "Root" },
    ...folders.value
      .filter((f) => {
        if (f.id === selected.id) return false;
        if (!Array.isArray(f.path)) return true;
        // Нельзя перемещать папку в собственное поддерево
        return !f.path.includes(selected.id);
      })
      .map((f) => ({ id: f.id, name: `${"  ".repeat(f.depth)}${f.name}` }))
  ];
});

const candidateVideos = computed(() => {
  const own = myVideos.value.map((v) => ({ id: v.id, title: v.title }));
  if (props.treeType === "library") return own;

  const map = new Map();
  own.forEach((v) => map.set(v.id, v));
  hotVideos.value.forEach((v) => {
    const id = v.video_id;
    if (!id || map.has(id)) return;
    map.set(id, { id, title: v.title || `Video ${id}` });
  });
  return Array.from(map.values());
});

async function loadTree() {
  const items = await foldersService.listTree(props.treeType);
  folders.value = items;
  if (!selectedFolderId.value || !items.some((f) => f.id === selectedFolderId.value)) {
    selectedFolderId.value = items[0]?.id || null;
  }
}

async function loadSelectedFolderVideos() {
  if (!selectedFolderId.value) {
    folderVideos.value = [];
    return;
  }
  folderVideos.value = await foldersService.listFolderVideos(selectedFolderId.value, { limit: 200 });
}

async function refreshAll() {
  loading.value = true;
  errorText.value = "";
  try {
    await Promise.all([
      loadTree(),
      videosService.listMyVideos(300).then((items) => {
        myVideos.value = items;
      }),
      props.treeType === "favorites"
        ? videosService.listHot(100).then((items) => {
            hotVideos.value = items;
          })
        : Promise.resolve()
    ]);
    await loadSelectedFolderVideos();
  } catch (err) {
    errorText.value = err?.response?.data?.message || err?.message || "Failed to load data";
  } finally {
    loading.value = false;
  }
}

function resetTreeState() {
  folders.value = [];
  folderVideos.value = [];
  selectedFolderId.value = null;
  renameValue.value = "";
  moveParentId.value = "";
  newFolderName.value = "";
  newFolderParentId.value = "";
  addVideoId.value = "";
  errorText.value = "";
}

async function createFolder() {
  const name = newFolderName.value.trim();
  if (!name) return;
  busy.value = true;
  errorText.value = "";
  try {
    await foldersService.createFolder({
      type: props.treeType,
      name,
      parentId: newFolderParentId.value || null
    });
    newFolderName.value = "";
    await refreshAll();
  } catch (err) {
    errorText.value = err?.response?.data?.message || "Create folder failed";
  } finally {
    busy.value = false;
  }
}

async function renameSelectedFolder() {
  if (!selectedFolder.value || !renameValue.value.trim()) return;
  busy.value = true;
  errorText.value = "";
  try {
    await foldersService.patchFolder(selectedFolder.value.id, { name: renameValue.value.trim() });
    renameValue.value = "";
    await refreshAll();
  } catch (err) {
    errorText.value = err?.response?.data?.message || "Rename failed";
  } finally {
    busy.value = false;
  }
}

async function moveSelectedFolder() {
  if (!selectedFolder.value) return;
  busy.value = true;
  errorText.value = "";
  try {
    await foldersService.patchFolder(selectedFolder.value.id, {
      parentId: moveParentId.value || null
    });
    await refreshAll();
  } catch (err) {
    errorText.value = err?.response?.data?.message || "Move folder failed";
  } finally {
    busy.value = false;
  }
}

async function deleteSelectedFolder() {
  if (!selectedFolder.value) return;
  if (!confirm(`Delete folder "${selectedFolder.value.name}"?`)) return;
  busy.value = true;
  errorText.value = "";
  try {
    await foldersService.deleteFolder(selectedFolder.value.id);
    await refreshAll();
  } catch (err) {
    errorText.value = err?.response?.data?.message || "Delete failed";
  } finally {
    busy.value = false;
  }
}

async function addVideoToSelectedFolder() {
  if (!selectedFolder.value || !addVideoId.value) return;
  busy.value = true;
  errorText.value = "";
  try {
    await foldersService.addVideo(selectedFolder.value.id, addVideoId.value);
    addVideoId.value = "";
    await loadSelectedFolderVideos();
    await loadTree();
  } catch (err) {
    errorText.value = err?.response?.data?.message || "Add video failed";
  } finally {
    busy.value = false;
  }
}

async function removeVideo(videoId) {
  if (!selectedFolder.value) return;
  busy.value = true;
  errorText.value = "";
  try {
    await foldersService.removeVideo(selectedFolder.value.id, videoId);
    await loadSelectedFolderVideos();
    await loadTree();
  } catch (err) {
    errorText.value = err?.response?.data?.message || "Remove video failed";
  } finally {
    busy.value = false;
  }
}

async function moveVideo(videoId, toFolderId) {
  if (!selectedFolder.value || !toFolderId || toFolderId === selectedFolder.value.id) return;
  busy.value = true;
  errorText.value = "";
  try {
    await foldersService.moveVideo(selectedFolder.value.id, videoId, toFolderId);
    await loadSelectedFolderVideos();
    await loadTree();
  } catch (err) {
    errorText.value = err?.response?.data?.message || "Move video failed";
  } finally {
    busy.value = false;
  }
}

watch(selectedFolderId, async () => {
  const f = selectedFolder.value;
  renameValue.value = f?.name || "";
  moveParentId.value = f?.parent_id || "";
  await loadSelectedFolderVideos();
});

watch(
  () => props.treeType,
  async () => {
    resetTreeState();
    await refreshAll();
  },
  { immediate: true }
);
</script>

<template>
  <section class="folders-page">
    <header class="folders-header">
      <h1 class="title">{{ title }}</h1>
      <button class="btn btn-secondary" @click="refreshAll" :disabled="busy || loading">
        ↻ Refresh
      </button>
    </header>

    <p v-if="errorText" class="error">{{ errorText }}</p>

    <div v-if="loading" class="panel box">Loading…</div>

    <div v-else class="grid layout">
      <aside class="panel box">
        <h3>Folders</h3>
        <div class="tree-list">
          <button
            v-for="folder in treeRows"
            :key="folder.id"
            class="tree-item"
            :class="{ active: selectedFolderId === folder.id }"
            @click="selectedFolderId = folder.id"
          >
            <span class="tree-label">
              {{ folder.treePrefix }}{{ folder.name }}
            </span>
            <small>{{ folder.videos_count }}</small>
          </button>
        </div>

        <div class="divider" />

        <h4>Create folder</h4>
        <div class="form-stack">
          <input v-model="newFolderName" class="input" placeholder="Folder name" />
          <select v-model="newFolderParentId" class="input">
            <option v-for="p in selectableParents" :key="p.id || 'root'" :value="p.id">
              {{ p.name }}
            </option>
          </select>
          <button class="btn btn-primary" :disabled="busy" @click="createFolder">Create</button>
        </div>
      </aside>

      <main class="panel box">
        <template v-if="selectedFolder">
          <h3>Selected: {{ selectedFolder.name }}</h3>
          <div class="grid row-3">
            <div class="form-stack">
              <label class="field-label">Rename</label>
              <input v-model="renameValue" class="input" />
              <button class="btn btn-secondary action-btn" :disabled="busy" @click="renameSelectedFolder">Save name</button>
            </div>
            <div class="form-stack">
              <label class="field-label">Move under</label>
              <select v-model="moveParentId" class="input">
                <option v-for="p in moveParentOptions" :key="p.id || 'root-2'" :value="p.id">
                  {{ p.name }}
                </option>
              </select>
              <button class="btn btn-secondary action-btn" :disabled="busy" @click="moveSelectedFolder">Move</button>
            </div>
            <div class="form-stack">
              <label class="field-label">Danger zone</label>
              <div class="control-spacer" aria-hidden="true" />
              <button class="btn btn-danger action-btn" :disabled="busy" @click="deleteSelectedFolder">Delete folder</button>
            </div>
          </div>

          <div class="divider" />

          <h4 class="section-title">Add video to folder</h4>
          <div class="row-inline">
            <select v-model="addVideoId" class="input">
              <option value="">Select video</option>
              <option v-for="v in candidateVideos" :key="v.id" :value="v.id">
                {{ v.title }}
              </option>
            </select>
            <button class="btn btn-primary" :disabled="busy || !addVideoId" @click="addVideoToSelectedFolder">
              Add
            </button>
          </div>

          <h4 class="section-title">Videos in folder</h4>
          <div v-if="folderVideos.length === 0" class="muted">No videos in this folder</div>
          <div v-else class="video-list">
            <article v-for="v in folderVideos" :key="v.video_id" class="video-row">
              <div>
                <strong>{{ v.title }}</strong>
                <small>{{ v.visibility }} · {{ v.status }}</small>
              </div>
              <div class="row-inline">
                <select class="input small" @change="moveVideo(v.video_id, $event.target.value)">
                  <option value="">Move to...</option>
                  <option
                    v-for="f in folders"
                    :key="f.id"
                    :value="f.id"
                    :disabled="f.id === selectedFolder.id"
                  >
                    {{ "  ".repeat(f.depth) }}{{ f.name }}
                  </option>
                </select>
                <button class="btn btn-danger" :disabled="busy" @click="removeVideo(v.video_id)">Remove</button>
              </div>
            </article>
          </div>
        </template>
        <template v-else>
          <div class="muted">Create first folder to start.</div>
        </template>
      </main>
    </div>
  </section>
</template>

<style scoped>
.folders-page {
  padding: var(--space-6);
}

.folders-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.layout {
  grid-template-columns: 360px 1fr;
  gap: 16px;
}

.box {
  padding: 16px;
}

.form-stack {
  display: grid;
  gap: 10px;
}

.box h3,
.box h4 {
  margin: 0 0 10px;
}

.tree-list {
  display: grid;
  gap: 6px;
  max-height: 320px;
  overflow: auto;
}

.tree-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  border: 1px solid var(--border);
  background: transparent;
  border-radius: 10px;
  padding: 8px 10px;
  color: var(--text);
  cursor: pointer;
}

.tree-item.active {
  border-color: var(--primary);
  background: rgba(80, 130, 255, 0.12);
}

.tree-label {
  white-space: pre;
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
}

.divider {
  height: 1px;
  background: var(--border);
  margin: 14px 0;
}

.row-inline {
  display: flex;
  gap: 8px;
  align-items: center;
  margin-bottom: 12px;
}

.row-3 {
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 12px;
}

.video-list {
  display: grid;
  gap: 8px;
  margin-top: 8px;
}

.video-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  border: 1px solid var(--border);
  border-radius: 10px;
  padding: 10px 12px;
}

.video-row small {
  display: block;
  color: var(--muted);
}

.small {
  min-width: 180px;
}

.muted {
  color: var(--ui-fg-2);
}

.error {
  color: #ff8f8f;
}

.section-title {
  margin: 16px 0 10px;
}

.control-spacer {
  height: 42px;
}

.action-btn {
  min-height: 42px;
}

select.input {
  color: var(--ui-fg-1);
}

select.input option {
  color: var(--text);
  background-color: var(--panel);
}

@media (max-width: 1100px) {
  .layout {
    grid-template-columns: 1fr;
  }

  .row-3 {
    grid-template-columns: 1fr;
  }
}
</style>
