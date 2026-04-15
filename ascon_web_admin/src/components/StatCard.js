import React from "react";
import "./StatCard.css";

function StatCard({ title, value, icon, color, onClick }) {
  return (
    <div
      className="stat-card"
      onClick={onClick}
      style={{
        backgroundColor: color,
        cursor: "pointer",
        transition: "transform 0.2s ease-in-out",
      }}
      onMouseEnter={(e) => (e.currentTarget.style.transform = "scale(1.03)")}
      onMouseLeave={(e) => (e.currentTarget.style.transform = "scale(1)")}
    >
      {/* ✅ Icon and Text wrapped for horizontal alignment */}
      <div className="stat-content-wrapper">
        <div className="stat-icon">{icon}</div>
        <div className="stat-info">
          <p className="stat-value">{value}</p>
          <h3 className="stat-title">{title}</h3>
        </div>
      </div>
    </div>
  );
}

export default StatCard;
