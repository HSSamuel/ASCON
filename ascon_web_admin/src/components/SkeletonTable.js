import React from "react";
import "../App.css"; // ✅ FIXED: Changed from "./App.css" to "../App.css"

function SkeletonTable({ rows = 5 }) {
  return (
    <div className="table-responsive">
      <table className="admin-table">
        <thead>
          <tr>
            <th>
              <div className="skeleton-box" style={{ width: "40px" }} />
            </th>
            <th>
              <div className="skeleton-box" style={{ width: "150px" }} />
            </th>
            <th>
              <div className="skeleton-box" style={{ width: "100px" }} />
            </th>
            <th>
              <div className="skeleton-box" style={{ width: "80px" }} />
            </th>
          </tr>
        </thead>
        <tbody>
          {Array.from({ length: rows }).map((_, i) => (
            <tr key={i}>
              <td>
                <div className="skeleton-circle" />
              </td>
              <td>
                <div className="skeleton-line" style={{ width: "80%" }} />
                <div
                  className="skeleton-line"
                  style={{ width: "50%", marginTop: "8px" }}
                />
              </td>
              <td>
                <div className="skeleton-line" style={{ width: "60%" }} />
              </td>
              <td>
                <div
                  className="skeleton-box"
                  style={{ width: "60px", height: "24px" }}
                />
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export default SkeletonTable;
