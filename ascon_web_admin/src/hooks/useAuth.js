import { useState, useEffect } from "react";
import { jwtDecode } from "jwt-decode";

export function useAuth(token, onLogout) {
  const [currentUser, setCurrentUser] = useState(null);

  useEffect(() => {
    if (token) {
      try {
        const decoded = jwtDecode(token);
        const currentTime = Date.now() / 1000;

        if (decoded.exp < currentTime) {
          console.warn("Token expired. Logging out.");
          onLogout();
        } else {
          setCurrentUser(decoded);
        }
      } catch (e) {
        console.error("Error decoding token", e);
        onLogout();
      }
    }
  }, [token, onLogout]);

  const canEdit = currentUser?.canEdit || false;
  const userRole = canEdit ? "Super Admin" : "Viewer"; // or "Admin" based on logic

  return { currentUser, canEdit, userRole };
}
