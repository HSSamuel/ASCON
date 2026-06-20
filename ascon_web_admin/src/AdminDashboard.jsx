import React, { useState, useEffect } from "react";
import "./App.css";
import NavBar from "./components/NavBar";
import StatCard from "./components/StatCard";

// ✅ Removed RegistrationsManager and DocumentsManager
import UsersManager from "./pages/UsersManager";
import EventsManager from "./pages/EventsManager";
import ProgrammesManager from "./pages/ProgrammesManager";
import UpdatesManager from "./pages/UpdatesManager";

import { useAuth } from "./hooks/useAuth";
import { DashboardProvider, useDashboard } from "./context/DashboardContext";

const DashboardContent = ({
  token,
  onLogout,
  activeTab,
  setActiveTab,
  theme,
  toggleTheme,
  canEdit,
  userRole,
}) => {
  const { stats } = useDashboard();

  return (
    <div className="admin-container">
      <NavBar
        activeTab={activeTab}
        setActiveTab={setActiveTab}
        onLogout={onLogout}
        userRole={userRole}
        theme={theme}
        toggleTheme={toggleTheme}
      />

      {/* STATS BAR */}
      <div
        className="content-padding stats-grid-mobile"
        style={{
          display: "flex",
          gap: "20px",
          flexWrap: "wrap",
          marginTop: "20px",
        }}
      >
        <StatCard
          title="Total Users"
          value={stats.users}
          icon="👥"
          color={theme === "light" ? "#fff3cd" : "#2c2c2c"}
          onClick={() => setActiveTab("users")}
        />
        <StatCard
          title="Active Events"
          value={stats.events}
          icon="📅"
          color="#d1e7dd"
          onClick={() => setActiveTab("events")}
        />
        <StatCard
          title="Programmes"
          value={stats.programmes}
          icon="🎓"
          color="#cff4fc"
          onClick={() => setActiveTab("programmes")}
        />

        {/* Social Feed */}
        <StatCard
          title="Social Feed"
          value={stats.updates || 0}
          icon="💬"
          color={theme === "light" ? "#e2e3e5" : "#3a3a3a"}
          onClick={() => setActiveTab("updates")}
        />
        {/* ✅ Registrations StatCard has been removed */}
      </div>

      <div
        className="content-padding"
        style={{ marginTop: "30px", paddingBottom: "20px" }}
      >
        {activeTab === "users" && (
          <UsersManager token={token} canEdit={canEdit} />
        )}

        {activeTab === "events" && (
          <EventsManager token={token} canEdit={canEdit} />
        )}

        {activeTab === "programmes" && (
          <ProgrammesManager token={token} canEdit={canEdit} />
        )}

        {activeTab === "updates" && (
          <UpdatesManager token={token} canEdit={canEdit} />
        )}
        {/* ✅ Documents and Registrations views have been removed */}
      </div>
    </div>
  );
};

function AdminDashboard({ token, onLogout }) {
  const [activeTab, setActiveTab] = useState("users");
  const [theme, setTheme] = useState(localStorage.getItem("theme") || "light");
  const { canEdit, userRole } = useAuth(token, onLogout);

  useEffect(() => {
    document.body.setAttribute("data-theme", theme);
  }, [theme]);

  const toggleTheme = () => {
    const newTheme = theme === "light" ? "dark" : "light";
    localStorage.setItem("theme", newTheme);
    setTheme(newTheme);
  };

  return (
    <DashboardProvider>
      <DashboardContent
        token={token}
        onLogout={onLogout}
        activeTab={activeTab}
        setActiveTab={setActiveTab}
        theme={theme}
        toggleTheme={toggleTheme}
        canEdit={canEdit}
        userRole={userRole}
      />
    </DashboardProvider>
  );
}

export default AdminDashboard;
