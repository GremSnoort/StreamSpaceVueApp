import http from "../lib/http";

function paramsToQuery(params = {}) {
  const sp = new URLSearchParams();
  Object.entries(params).forEach(([k, v]) => {
    if (v === null || v === undefined || v === "") return;
    sp.set(k, String(v));
  });
  const q = sp.toString();
  return q ? `?${q}` : "";
}

export default {
  async listTree(type) {
    const { data } = await http.get(`/me/folders/tree${paramsToQuery({ type })}`);
    return Array.isArray(data?.items) ? data.items : [];
  },

  async createFolder(payload) {
    const { data } = await http.post("/me/folders", payload);
    return data;
  },

  async patchFolder(folderId, payload) {
    const { data } = await http.patch(`/me/folders/${folderId}`, payload);
    return data;
  },

  async deleteFolder(folderId) {
    await http.delete(`/me/folders/${folderId}`);
  },

  async listFolderVideos(folderId, params = {}) {
    const { data } = await http.get(`/me/folders/${folderId}/videos${paramsToQuery(params)}`);
    return Array.isArray(data?.items) ? data.items : [];
  },

  async addVideo(folderId, videoId, orderIndex = null) {
    const { data } = await http.post(`/me/folders/${folderId}/videos`, {
      videoId,
      orderIndex
    });
    return data;
  },

  async removeVideo(folderId, videoId) {
    await http.delete(`/me/folders/${folderId}/videos/${videoId}`);
  },

  async moveVideo(folderId, videoId, toFolderId, toOrderIndex = null) {
    const { data } = await http.post(`/me/folders/${folderId}/videos/${videoId}/move`, {
      toFolderId,
      toOrderIndex
    });
    return data;
  }
};
