import React, { useState, useEffect, useRef } from "react";
import "./NavBar.css";

function NavBar({ activeTab, setActiveTab, onLogout, userRole }) {
  const [isMenuOpen, setIsMenuOpen] = useState(false);
  const [isDesktopDropdownOpen, setIsDesktopDropdownOpen] = useState(false);

  const dropdownRef = useRef(null);

  useEffect(() => {
    function handleClickOutside(event) {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target)) {
        setIsDesktopDropdownOpen(false);
      }
    }
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  const handleTabClick = (tab) => {
    setActiveTab(tab);
    setIsMenuOpen(false);
    setIsDesktopDropdownOpen(false);
  };

  // ✅ 1. Removed "documents" and "registrations" from this array
  const navItems = [
    { id: "users", label: "Users", icon: "👥" },
    { id: "events", label: "Events", icon: "📅" },
    { id: "programmes", label: "Programmes", icon: "🎓" },
    { id: "updates", label: "Social Feed", icon: "💬" },
  ];

  const activeItem =
    navItems.find((item) => item.id === activeTab) || navItems[0];

  return (
    <>
      <nav className="desktop-nav">
        <div className="nav-brand">
          <img src="/logo.png" alt="ASCON Logo" className="brand-logo" />
          <span className="brand-text">ASCON Admin</span>
        </div>

        <div className="nav-dropdown-container" ref={dropdownRef}>
          <span className="nav-label-text">Current View:</span>

          <button
            className="dropdown-trigger"
            onClick={() => setIsDesktopDropdownOpen(!isDesktopDropdownOpen)}
          >
            <span className="trigger-content">
              {activeItem.icon} {activeItem.label}
            </span>
            <span className="trigger-arrow">
              {isDesktopDropdownOpen ? "▲" : "▼"}
            </span>
          </button>

          {isDesktopDropdownOpen && (
            <div className="dropdown-menu">
              {navItems.map((item) => (
                <button
                  key={item.id}
                  className={`dropdown-item ${
                    activeTab === item.id ? "active" : ""
                  }`}
                  onClick={() => handleTabClick(item.id)}
                >
                  {item.icon} {item.label}
                  {activeTab === item.id && (
                    <span className="check-mark">✓</span>
                  )}
                </button>
              ))}
            </div>
          )}
        </div>

        <div className="nav-actions">
          <button className="logout-btn" onClick={onLogout}>
            Logout ↪
          </button>
        </div>
      </nav>

      {isMenuOpen && (
        <div className="mobile-menu-overlay">
          <div className="mobile-menu-content">
            <h3>Menu</h3>
            {navItems.map((item) => (
              <button
                key={item.id}
                className={activeTab === item.id ? "active-mobile-item" : ""}
                onClick={() => handleTabClick(item.id)}
              >
                {item.icon} {item.label}
              </button>
            ))}
            <hr />
            <button className="mobile-logout" onClick={onLogout}>
              🚪 Logout
            </button>
            <button className="close-menu" onClick={() => setIsMenuOpen(false)}>
              ▼ Close
            </button>
          </div>
        </div>
      )}

      <div className="mobile-bottom-bar">
        <div
          className="bottom-nav-item"
          onClick={() => handleTabClick("users")}
        >
          <span
            className={`icon ${activeTab === "users" ? "active-icon" : ""}`}
          >
            👥
          </span>
          <span className="label">Users</span>
        </div>

        <div
          className="bottom-nav-item"
          onClick={() => handleTabClick("events")}
        >
          <span
            className={`icon ${activeTab === "events" ? "active-icon" : ""}`}
          >
            📅
          </span>
          <span className="label">Events</span>
        </div>

        <div className="fab-container">
          <div className="fab-notch"></div>
          <button
            className="fab-btn"
            onClick={() => setIsMenuOpen(!isMenuOpen)}
          >
            <span className="fab-icon">☰</span>
          </button>
          <span className="fab-label">Menu</span>
        </div>

        <div
          className="bottom-nav-item"
          onClick={() => handleTabClick("programmes")}
        >
          <span
            className={`icon ${
              activeTab === "programmes" ? "active-icon" : ""
            }`}
          >
            🎓
          </span>
          <span className="label">Progs</span>
        </div>

        {/* ✅ 2. Replaced "Registrations" with "Social Feed" to keep the mobile UI balanced */}
        <div
          className="bottom-nav-item"
          onClick={() => handleTabClick("updates")}
        >
          <span
            className={`icon ${activeTab === "updates" ? "active-icon" : ""}`}
          >
            💬
          </span>
          <span className="label">Feed</span>
        </div>
      </div>
    </>
  );
}

export default NavBar;
