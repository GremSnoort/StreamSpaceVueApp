import http from "../lib/http";

export default {
  async getProfile(userId) {
    const { data } = await http.get(`/users/${userId}`);
    return data;
  },

  async follow(userId) {
    const { data } = await http.post(`/users/${userId}/follow`);
    return data;
  },

  async unfollow(userId) {
    const { data } = await http.delete(`/users/${userId}/follow`);
    return data;
  },

  async listFollowing(limit = 100) {
    const { data } = await http.get("/me/following", { params: { limit } });
    return Array.isArray(data?.items) ? data.items : [];
  },

  async listFollowers(limit = 100) {
    const { data } = await http.get("/me/followers", { params: { limit } });
    return Array.isArray(data?.items) ? data.items : [];
  }
};
