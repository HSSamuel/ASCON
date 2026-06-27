import React, { useState } from "react";

function RegistrationsTab({
  registrations,
  eventRegistrations,
  isLoading,
  onDelete,
  canEdit,
  showToast,
}) {
  // Toggle State: 'programmes' or 'events'
  const [view, setView] = useState("programmes");

  if (isLoading) {
    return (
      <div style={{ padding: "40px", textAlign: "center", color: "#666" }}>
        Loading registrations...
      </div>
    );
  }

  // Helper to choose which list to show based on the toggle
  const activeList = view === "programmes" ? registrations : eventRegistrations;

  // ✅ HELPER: Format Phone Number
  const formatPhone = (phone) => {
    if (!phone) return "";
    if (phone.startsWith("+234") && phone.length > 10) {
      return `${phone.substring(0, 4)} ${phone.substring(4, 7)} ${phone.substring(7, 10)} ${phone.substring(10)}`;
    }
    return phone;
  };

  // ✅ EXPORT TO EXCEL (CSV) FUNCTION
  const exportToCSV = () => {
    if (!activeList || activeList.length === 0) {
      if (showToast) {
        showToast("No data to export.", "error");
      } else {
        alert("No data to export.");
      }
      return;
    }

    if (showToast) {
      showToast(`Downloading ${view} list...`, "info");
    }

    // 1. Define Headers based on View
    const headers = [
      "Date",
      "Full Name",
      "Email",
      "Phone",
      view === "programmes" ? "Programme Title" : "Event Title",
      view === "events" ? "Event Type" : null,
      "Organization",
      "Job Title",
      // ✅ UPDATED: Added State to Export
      view === "programmes" ? "City" : null,
      view === "programmes" ? "State" : null,
      view === "programmes" ? "Country" : null,
      view === "events" ? "Special Requirements" : null,
    ].filter((h) => h !== null);

    // 2. Map Data to Rows
    const rows = activeList.map((reg) =>
      [
        `"${new Date(reg.createdAt).toLocaleDateString()}"`,
        `"${reg.fullName || ""}"`,
        `"${reg.email || ""}"`,
        `"${reg.phone || ""}"`,
        `"${reg.programmeTitle || reg.eventTitle || ""}"`,
        view === "events" ? `"${reg.eventType || ""}"` : null,
        `"${reg.sponsoringOrganisation || reg.organization || ""}"`,
        `"${reg.jobTitle || ""}"`,
        // ✅ UPDATED: Include State in CSV
        view === "programmes" ? `"${reg.city || ""}"` : null,
        view === "programmes" ? `"${reg.state || ""}"` : null,
        view === "programmes" ? `"${reg.country || ""}"` : null,
        view === "events" ? `"${reg.specialRequirements || ""}"` : null,
      ].filter((cell) => cell !== null),
    );

    // 3. Combine Headers and Rows
    const csvContent = [
      headers.join(","),
      ...rows.map((row) => row.join(",")),
    ].join("\n");

    // 4. Trigger Download
    const blob = new Blob([csvContent], { type: "text/csv;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.setAttribute("href", url);
    link.setAttribute(
      "download",
      `ascon_${view}_registrations_${new Date().toISOString().slice(0, 10)}.csv`,
    );
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  return (
    <div>
      {/* 1. HEADER & TOGGLE */}
      <div
        className="empty-state"
        style={{ textAlign: "center", marginBottom: "30px" }}
      >
        <h2 style={{ margin: "0 0 10px 0", color: "#1B5E3A" }}>
          📋 Registrations Viewer
        </h2>
        <p style={{ color: "#666", margin: "0 0 20px 0" }}>
          View users who have expressed interest via the mobile app.
        </p>

        <div
          style={{
            display: "flex",
            justifyContent: "center",
            gap: "10px",
            flexWrap: "wrap",
          }}
        >
          {/* TOGGLE BUTTONS */}
          <div
            style={{
              display: "inline-flex",
              background: "#f0f0f0",
              borderRadius: "8px",
              padding: "4px",
            }}
          >
            <button
              onClick={() => setView("programmes")}
              style={{
                padding: "8px 20px",
                border: "none",
                borderRadius: "6px",
                cursor: "pointer",
                background: view === "programmes" ? "white" : "transparent",
                color: view === "programmes" ? "#1B5E3A" : "#666",
                fontWeight: view === "programmes" ? "bold" : "normal",
                boxShadow:
                  view === "programmes" ? "0 2px 4px rgba(0,0,0,0.1)" : "none",
                transition: "all 0.2s",
              }}
            >
              Programmes ({registrations.length})
            </button>
            <button
              onClick={() => setView("events")}
              style={{
                padding: "8px 20px",
                border: "none",
                borderRadius: "6px",
                cursor: "pointer",
                background: view === "events" ? "white" : "transparent",
                color: view === "events" ? "#1B5E3A" : "#666",
                fontWeight: view === "events" ? "bold" : "normal",
                boxShadow:
                  view === "events" ? "0 2px 4px rgba(0,0,0,0.1)" : "none",
                transition: "all 0.2s",
              }}
            >
              Events ({eventRegistrations.length})
            </button>
          </div>

          {/* EXPORT BUTTON */}
          <button
            onClick={exportToCSV}
            className="approve-btn"
            style={{
              backgroundColor: "#1B5E3A",
              display: "flex",
              alignItems: "center",
              gap: "8px",
              padding: "8px 16px",
              height: "40px",
              border: "none",
              borderRadius: "6px",
              color: "white",
              cursor: "pointer",
            }}
          >
            📥 Export to Excel
          </button>
        </div>
      </div>

      {/* 2. DATA TABLE */}
      <div className="table-responsive">
        <table className="admin-table">
          <thead>
            <tr>
              <th>Date</th>
              <th>Applicant</th>
              <th>Contact</th>
              <th>
                {view === "programmes" ? "Programme Title" : "Event / Type"}
              </th>
              <th>Organization</th>

              {/* Show "Location" Header ONLY for Programmes */}
              {view === "programmes" && <th>Location</th>}

              {/* Show "Special Req" ONLY for Events */}
              {view === "events" && <th>Special Req</th>}

              <th>Action</th>
            </tr>
          </thead>
          <tbody>
            {activeList.length === 0 ? (
              <tr>
                <td
                  colSpan={7}
                  style={{
                    textAlign: "center",
                    padding: "40px",
                    color: "#888",
                  }}
                >
                  No {view} registrations found yet.
                </td>
              </tr>
            ) : (
              activeList.map((reg) => (
                <tr key={reg._id}>
                  {/* DATE */}
                  <td
                    style={{
                      fontSize: "12px",
                      color: "#666",
                      whiteSpace: "nowrap",
                    }}
                  >
                    {new Date(reg.createdAt).toLocaleDateString()} <br />
                    {new Date(reg.createdAt).toLocaleTimeString([], {
                      hour: "2-digit",
                      minute: "2-digit",
                    })}
                  </td>

                  {/* APPLICANT */}
                  <td>
                    <div style={{ fontWeight: "bold", color: "#333" }}>
                      {reg.fullName}
                    </div>
                    <div style={{ fontSize: "12px", color: "#888" }}>
                      {reg.sex}
                    </div>
                  </td>

                  {/* CONTACT */}
                  <td>
                    <div style={{ fontSize: "13px" }}>📧 {reg.email}</div>
                    <div style={{ fontSize: "13px", marginTop: "2px" }}>
                      {/* ✅ FORMATTED PHONE NUMBER */}
                      📞 {formatPhone(reg.phone)}
                    </div>
                  </td>

                  {/* TITLE */}
                  <td>
                    <span
                      className="tag"
                      style={{
                        backgroundColor:
                          view === "events" ? "#e3f2fd" : "#e8f5e9",
                        color: view === "events" ? "#0d47a1" : "#1b5e20",
                        padding: "4px 8px",
                        borderRadius: "4px",
                        fontSize: "12px",
                        fontWeight: "bold",
                      }}
                    >
                      {reg.programmeTitle || reg.eventTitle}
                    </span>
                    {reg.eventType && (
                      <div
                        style={{
                          fontSize: "10px",
                          marginTop: "6px",
                          color: "#666",
                          textTransform: "uppercase",
                          fontWeight: "bold",
                        }}
                      >
                        TYPE: {reg.eventType}
                      </div>
                    )}
                  </td>

                  {/* EMPLOYMENT */}
                  <td style={{ fontSize: "13px" }}>
                    <div style={{ fontWeight: "bold" }}>
                      {reg.sponsoringOrganisation || reg.organization}
                    </div>
                    <div style={{ color: "#666", fontSize: "12px" }}>
                      {reg.jobTitle}
                    </div>
                  </td>

                  {/* ✅ UPDATED: Show City, State, Country */}
                  {view === "programmes" && (
                    <td style={{ fontSize: "13px" }}>
                      {reg.city ? `${reg.city}, ` : ""}
                      {/* Show State if available */}
                      {reg.state ? `${reg.state}, ` : ""}
                      <span style={{ fontWeight: "500" }}>
                        {reg.country || "N/A"}
                      </span>
                    </td>
                  )}

                  {/* SPECIAL REQ (Events Only) */}
                  {view === "events" && (
                    <td
                      style={{
                        fontSize: "12px",
                        color: "#d32f2f",
                        maxWidth: "150px",
                      }}
                    >
                      {reg.specialRequirements ? (
                        <span
                          style={{
                            background: "#ffebee",
                            padding: "2px 6px",
                            borderRadius: "4px",
                          }}
                        >
                          {reg.specialRequirements}
                        </span>
                      ) : (
                        <span style={{ color: "#ccc" }}>-</span>
                      )}
                    </td>
                  )}

                  {/* DELETE BUTTON */}
                  <td>
                    {canEdit ? (
                      <button
                        className="delete-btn compact-btn"
                        onClick={() => onDelete(reg._id, view)}
                        title="Delete Registration"
                        style={{ padding: "6px 12px" }}
                      >
                        🗑️
                      </button>
                    ) : (
                      <span style={{ color: "#ccc", fontSize: "12px" }}>
                        🔒
                      </span>
                    )}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}

export default RegistrationsTab;
