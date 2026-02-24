import http from "../lib/http";

export default {
  async listMyVideos(limit = 200, offset = 0) {
    const { data } = await http.get("/me/videos", { params: { limit, offset } });
    return Array.isArray(data?.items) ? data.items : [];
  },

  async listHot(limit = 100, offset = 0, window = "48 hours") {
    const { data } = await http.get("/feed/hot", { params: { limit, offset, window } });
    return Array.isArray(data?.items) ? data.items : [];
  }
};
