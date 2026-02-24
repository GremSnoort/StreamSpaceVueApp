import http from "../lib/http";

export default {
  async uploadVideo(formData) {
    const { data } = await http.post("/videos/upload", formData, {
      headers: { "Content-Type": "multipart/form-data" }
    });
    return data;
  },

  async createVideo(payload) {
    const { data } = await http.post("/videos", payload);
    return data;
  },

  async getVideo(videoId) {
    const { data } = await http.get(`/videos/${videoId}`);
    return data;
  },

  async listMyVideos(limit = 200, offset = 0) {
    const { data } = await http.get("/me/videos", { params: { limit, offset } });
    return Array.isArray(data?.items) ? data.items : [];
  },

  async listHot(limit = 100, offset = 0, window = "48 hours") {
    const { data } = await http.get("/feed/hot", { params: { limit, offset, window } });
    return Array.isArray(data?.items) ? data.items : [];
  },

  async updateVideo(videoId, payload) {
    const { data } = await http.patch(`/videos/${videoId}`, payload);
    return data;
  },

  async publishVideo(videoId) {
    const { data } = await http.post(`/videos/${videoId}/publish`);
    return data;
  },

  async unpublishVideo(videoId) {
    const { data } = await http.post(`/videos/${videoId}/unpublish`);
    return data;
  },

  async deleteVideo(videoId) {
    await http.delete(`/videos/${videoId}`);
  }
};
