import React, {
  createContext,
  useState,
  useEffect,
  useContext,
  useCallback,
} from "react";
import { jwtDecode } from "jwt-decode";
import axios from "axios";

const AuthContext = createContext(null);

export const AuthProvider = ({ children }) => {
  const [token, setToken] = useState(null);
  const [user, setUser] = useState(null);
  const [isLoading, setIsLoading] = useState(true);

  // ✅ 1. Stable Login Function
  const login = useCallback((newToken, newRefreshToken = null) => {
    localStorage.setItem("auth_token", newToken);
    if (newRefreshToken) {
      localStorage.setItem("refresh_token", newRefreshToken);
    }

    setToken(newToken);
    try {
      const decoded = jwtDecode(newToken);
      setUser(decoded);
    } catch (e) {
      console.error("Failed to decode token on login");
    }
  }, []);

  // ✅ 2. Stable Logout Function
  const logout = useCallback(() => {
    localStorage.removeItem("auth_token");
    localStorage.removeItem("refresh_token");
    setToken(null);
    setUser(null);
  }, []);

  // ✅ 3. Silent Refresh Logic (Moved outside effect)
  const checkTokenExpiry = useCallback(
    async (currentToken) => {
      if (!currentToken) return;

      try {
        const decoded = jwtDecode(currentToken);
        const currentTime = Date.now() / 1000;

        // Refresh if expiring in < 5 minutes
        if (decoded.exp - currentTime < 300) {
          const refreshToken = localStorage.getItem("refresh_token");
          if (!refreshToken) return;

          const response = await axios.post(
            `${process.env.REACT_APP_API_URL || "https://ascon.onrender.com"}/api/auth/refresh`,
            { refreshToken },
          );

          if (response.data && response.data.token) {
            console.log("🔄 Session silently refreshed");
            login(response.data.token);
          }
        }
      } catch (error) {
        console.warn("Silent refresh failed:", error);
        // Optional: logout() if strictly needed, but better to let the token expire naturally to avoid jarring UX
      }
    },
    [login],
  );

  // ✅ 4. INITIALIZATION EFFECT (Runs Once)
  // This guarantees isLoading becomes false, no matter what.
  useEffect(() => {
    const initializeAuth = () => {
      const storedToken = localStorage.getItem("auth_token");
      if (storedToken) {
        try {
          const decoded = jwtDecode(storedToken);
          const currentTime = Date.now() / 1000;

          if (decoded.exp < currentTime) {
            console.warn("Token expired on startup.");
            logout();
          } else {
            setToken(storedToken);
            setUser(decoded);
          }
        } catch (e) {
          console.error("Invalid token on startup:", e);
          logout();
        }
      }
      // ✅ CRITICAL: This ensures the spinner ALWAYS disappears
      setIsLoading(false);
    };

    initializeAuth();
  }, [logout]);

  // ✅ 5. INTERVAL EFFECT (Runs only when logged in)
  useEffect(() => {
    if (!token) return;

    // Run check immediately on mount/token change
    checkTokenExpiry(token);

    // Start interval
    const intervalId = setInterval(() => {
      checkTokenExpiry(token);
    }, 120000); // Check every 2 minutes

    return () => clearInterval(intervalId);
  }, [token, checkTokenExpiry]);

  return (
    <AuthContext.Provider value={{ token, user, isLoading, login, logout }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => useContext(AuthContext);
