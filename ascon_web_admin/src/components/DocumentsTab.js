import React from "react";
import SkeletonTable from "./SkeletonTable";

function DocumentsTab({
  documentsList = [],
  loading,
  canEdit,
  updateStatus,
  search,
  setSearch,
}) {
  // SKELETON LOADING
  if (loading && documentsList.length === 0) {
    return <SkeletonTable rows={10} />;
  }

  // ✅ Client-side filtering (since backend returns all docs)
  const displayList = documentsList.filter(
    (doc) =>
      (doc.user?.fullName || "").toLowerCase().includes(search.toLowerCase()) ||
      (doc.type || "").toLowerCase().includes(search.toLowerCase()) ||
      (doc.status || "").toLowerCase().includes(search.toLowerCase()),
  );

  // EXPORT TO CSV FUNCTION
  const exportToCSV = () => {
    if (!documentsList || documentsList.length === 0) {
      alert("No data to export.");
      return;
    }

    const headers = [
      "User Name",
      "Alumni ID",
      "Document Type",
      "Details",
      "Status",
      "Date Requested",
      "Admin Note",
    ];

    const rows = documentsList.map((doc) => [
      `"${doc.user?.fullName || "Unknown"}"`,
      `"${doc.user?.alumniId || "N/A"}"`,
      `"${doc.type}"`,
      `"${doc.details}"`,
      doc.status,
      new Date(doc.createdAt).toLocaleDateString(),
      `"${doc.adminComment || ""}"`,
    ]);

    const csvContent = [
      headers.join(","),
      ...rows.map((row) => row.join(",")),
    ].join("\n");

    const blob = new Blob([csvContent], { type: "text/csv;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.setAttribute("href", url);
    link.setAttribute(
      "download",
      `ascon_documents_export_${new Date().toISOString().slice(0, 10)}.csv`,
    );
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const renderStatusBadge = (status) => {
    // ✅ REMOVED UNUSED 'colors' OBJECT HERE

    // Tailwind classes map to standard CSS if needed, or use inline styles
    const styleMap = {
      Pending: { backgroundColor: "#fff3cd", color: "#856404" },
      Processing: { backgroundColor: "#cff4fc", color: "#055160" },
      Ready: { backgroundColor: "#e0cffc", color: "#4c0bce" },
      Delivered: { backgroundColor: "#d1e7dd", color: "#0f5132" },
      Rejected: { backgroundColor: "#f8d7da", color: "#842029" },
    };

    return (
      <span
        className="status-badge"
        style={{
          padding: "4px 8px",
          borderRadius: "12px",
          fontSize: "11px",
          fontWeight: "bold",
          ...styleMap[status],
        }}
      >
        {status}
      </span>
    );
  };

  return (
    <div>
      {/* HEADER: SEARCH & EXPORT */}
      <div
        style={{
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
          marginBottom: "15px",
          flexWrap: "wrap",
          gap: "10px",
        }}
      >
        <input
          type="text"
          placeholder="🔍 Search Request, Name, or Status..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          style={{
            maxWidth: "350px",
            padding: "10px",
            border: "1px solid #ccc",
            borderRadius: "6px",
          }}
        />

        <button
          onClick={exportToCSV}
          className="approve-btn"
          style={{
            backgroundColor: "#1B5E3A",
            display: "flex",
            alignItems: "center",
            gap: "8px",
          }}
        >
          📥 Export to Excel
        </button>
      </div>

      <div className="table-responsive">
        <table className="admin-table">
          <thead>
            <tr>
              <th>User</th>
              <th>Request</th>
              <th>Date</th>
              <th>Status</th>
              <th>Action</th>
            </tr>
          </thead>
          <tbody>
            {displayList.length > 0 ? (
              displayList.map((doc) => (
                <tr key={doc._id}>
                  <td data-label="User">
                    <div
                      style={{
                        display: "flex",
                        alignItems: "center",
                        gap: "10px",
                      }}
                    >
                      <div
                        className="avatar-placeholder"
                        style={{ width: 30, height: 30, fontSize: 14 }}
                      >
                        {(doc.user?.fullName || "U").charAt(0)}
                      </div>
                      <div>
                        <strong>{doc.user?.fullName || "Unknown"}</strong>
                        <div style={{ fontSize: "11px", color: "#666" }}>
                          {doc.user?.alumniId || "No ID"}
                        </div>
                      </div>
                    </div>
                  </td>
                  <td data-label="Request">
                    <div style={{ fontWeight: "bold", color: "#333" }}>
                      {doc.type}
                    </div>
                    <div
                      style={{
                        fontSize: "12px",
                        color: "#666",
                        maxWidth: "200px",
                      }}
                      title={doc.details}
                    >
                      {doc.details}
                    </div>
                    {doc.adminComment && (
                      <div
                        style={{
                          fontSize: "11px",
                          color: "red",
                          marginTop: "2px",
                        }}
                      >
                        Note: {doc.adminComment}
                      </div>
                    )}
                  </td>
                  <td data-label="Date">
                    {new Date(doc.createdAt).toLocaleDateString()}
                  </td>
                  <td data-label="Status">{renderStatusBadge(doc.status)}</td>
                  <td data-label="Action">
                    {canEdit ? (
                      <select
                        value={doc.status}
                        onChange={(e) => updateStatus(doc, e.target.value)}
                        style={{
                          padding: "6px",
                          borderRadius: "4px",
                          border: "1px solid #ccc",
                          fontSize: "12px",
                          cursor: "pointer",
                        }}
                      >
                        <option value="Pending">Pending</option>
                        <option value="Processing">Processing</option>
                        <option value="Ready">Ready</option>
                        <option value="Delivered">Delivered</option>
                        <option value="Rejected">Rejected</option>
                      </select>
                    ) : (
                      <span style={{ color: "#999", fontSize: "12px" }}>
                        View Only
                      </span>
                    )}
                  </td>
                </tr>
              ))
            ) : (
              <tr>
                <td
                  colSpan="5"
                  style={{ textAlign: "center", padding: "30px" }}
                >
                  No documents found.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}

export default DocumentsTab;
