import React, { createContext, useContext, useState } from "react";
import { useStats } from "../hooks/useStats";

// Create the Context
const DashboardContext = createContext();

// Create the Provider
export const DashboardProvider = ({ children }) => {
  // Centralize the refresh trigger state here
  const [refreshTrigger, setRefreshTrigger] = useState(0);

  // Fetch stats using the hook, passing the trigger
  const stats = useStats(refreshTrigger);

  // Helper function to force a refresh of stats
  const triggerRefresh = () => {
    setRefreshTrigger((prev) => prev + 1);
  };

  return (
    <DashboardContext.Provider value={{ stats, triggerRefresh }}>
      {children}
    </DashboardContext.Provider>
  );
};

// Custom Hook for consuming the context
export const useDashboard = () => {
  const context = useContext(DashboardContext);
  if (!context) {
    throw new Error("useDashboard must be used within a DashboardProvider");
  }
  return context;
};
