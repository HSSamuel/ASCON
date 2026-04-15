import { useState, useEffect } from "react";
import api from "../api"; // ✅ Import centralized API

export function useStats(refreshTrigger) {
  const [stats, setStats] = useState({
    users: 0,
    events: 0,
    programmes: 0,
    totalRegistrations: 0,
    updates: 0, // ✅ Replaces 'jobs'
  });

  useEffect(() => {
    const fetchStats = async () => {
      try {
        // ✅ Single call to the updated admin stats endpoint
        const response = await api.get("/api/admin/stats");

        // The backend now returns { users, events, programmes, totalRegistrations, updates }
        setStats(response.data);
      } catch (e) {
        console.error("Stats error:", e);
      }
    };

    fetchStats();
  }, [refreshTrigger]);

  return stats;
}
