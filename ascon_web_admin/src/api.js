import axios from "axios";

// 1. Create the Axios Instance
const api = axios.create({
  baseURL: process.env.REACT_APP_API_URL || "https://ascon.onrender.com",
});

// 2. Request Interceptor: Auto-attach Token
api.interceptors.request.use(
  (config) => {
    // Check both common storage keys just in case
    const token =
      localStorage.getItem("auth_token") || localStorage.getItem("token");

    if (token) {
      config.headers["auth-token"] = token;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  },
);

// 3. Response Interceptor: Handle 401 (Unauthorized) globally
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response && error.response.status === 401) {
      console.warn("Session expired or invalid token.");
      // window.location.href = "/"; // Uncomment to auto-logout
    }
    return Promise.reject(error);
  },
);

// ============================================================
// ✅ 4. ATTACH DOCUMENT REQUEST METHODS
// ============================================================

// Fetch all document requests (Admin)
api.getDocuments = async (token) => {
  const config = token ? { headers: { "auth-token": token } } : {};
  const response = await api.get("/api/documents/all", config);
  return response.data;
};

// Update status of a request
api.updateDocumentStatus = async (id, status, comment, token) => {
  const config = token ? { headers: { "auth-token": token } } : {};
  const response = await api.put(
    `/api/documents/${id}`,
    { status, adminComment: comment },
    config,
  );
  return response.data;
};

export default api;
