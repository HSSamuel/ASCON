import React from "react";
import SkeletonTable from "./SkeletonTable";

function UsersTab({
  usersList = [],
  loading,
  canEdit,
  approveUser,
  toggleAdmin,
  toggleEditPermission,
  deleteUserClick,
  page,
  setPage,
  totalPages,
  search, // ✅ Receive Search State
  setSearch, // ✅ Receive Set Search Function
}) {
  // SKELETON LOADING
  if (loading && usersList.length === 0) {
    return <SkeletonTable rows={10} />;
  }

  // EXPORT TO CSV FUNCTION
  const exportToCSV = () => {
    if (!usersList || usersList.length === 0) {
      alert("No data to export.");
      return;
    }

    const headers = [
      "Full Name",
      "Email",
      "Phone Number",
      "Programme",
      "Class Year",
      "Alumni ID",
      "Status",
      "Is Admin",
      "Can Edit",
    ];

    const rows = usersList.map((user) => [
      `"${user.fullName || ""}"`,
      `"${user.email || ""}"`,
      `"${user.phoneNumber || ""}"`,
      `"${user.programmeTitle || ""}"`,
      `"${user.yearOfAttendance || ""}"`,
      `"${user.alumniId || ""}"`,
      user.isVerified ? "Verified" : "Pending",
      user.isAdmin ? "Yes" : "No",
      user.canEdit ? "Yes" : "No",
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
      `ascon_alumni_export_${new Date().toISOString().slice(0, 10)}.csv`
    );
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const renderAvatar = (imagePath) => {
    if (!imagePath) return <div className="avatar-placeholder">👤</div>;
    if (imagePath.startsWith("http"))
      return <img src={imagePath} alt="Avatar" className="avatar" />;
    return (
      <img
        src={`data:image/png;base64,${imagePath}`}
        alt="Avatar"
        className="avatar"
      />
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
        {/* ✅ NEW SEARCH BAR */}
        <input
          type="text"
          placeholder="🔍 Search Users (Name, Email, ID)..."
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
              <th>Photo</th>
              <th>Full Name</th>
              <th>Status</th>
              <th>Action</th>
            </tr>
          </thead>
          <tbody>
            {usersList.length > 0 ? (
              usersList.map((user) => (
                <tr key={user._id}>
                  <td data-label="Photo">
                    {renderAvatar(user.profilePicture)}
                  </td>
                  <td data-label="Full Name">
                    <strong>{user.fullName}</strong>
                    <div style={{ fontSize: "12px", color: "#666" }}>
                      {user.email}
                    </div>
                    {user.alumniId && (
                      <div
                        style={{
                          fontSize: "11px",
                          color: "#1B5E3A",
                          fontWeight: "bold",
                          marginTop: "2px",
                        }}
                      >
                        {user.alumniId}
                      </div>
                    )}
                    <div style={{ marginTop: "5px" }}>
                      {user.isAdmin && (
                        <span
                          className="tag"
                          style={{
                            backgroundColor: "#007bff",
                            color: "white",
                            fontSize: "10px",
                            marginRight: "5px",
                          }}
                        >
                          ADMIN
                        </span>
                      )}
                      {user.canEdit && (
                        <span
                          className="tag"
                          style={{
                            backgroundColor: "#d4af37",
                            color: "white",
                            fontSize: "10px",
                          }}
                        >
                          EDITOR
                        </span>
                      )}
                    </div>
                  </td>
                  <td data-label="Status">
                    <span
                      className={`status-badge ${
                        user.isVerified ? "verified" : "pending"
                      }`}
                    >
                      {user.isVerified ? "Verified" : "Pending"}
                    </span>
                  </td>
                  <td data-label="Action">
                    {canEdit ? (
                      <div className="action-buttons-container">
                        {!user.isVerified && (
                          <button
                            onClick={() => approveUser(user._id, user.fullName)}
                            className="approve-btn compact-btn"
                            title="Verify User"
                          >
                            VERIFY
                          </button>
                        )}

                        <button
                          onClick={() => toggleAdmin(user._id)}
                          className="approve-btn compact-btn"
                          style={{
                            backgroundColor: user.isAdmin ? "#444" : "#007bff",
                          }}
                        >
                          {user.isAdmin ? "REVOKE ADMIN" : "MAKE ADMIN"}
                        </button>

                        {user.isAdmin && (
                          <button
                            onClick={() => toggleEditPermission(user._id)}
                            className="approve-btn compact-btn"
                            style={{
                              backgroundColor: user.canEdit ? "#555" : "purple",
                            }}
                          >
                            {user.canEdit ? "REVOKE EDIT" : "GRANT EDIT"}
                          </button>
                        )}

                        <button
                          onClick={() => deleteUserClick(user._id)}
                          className="delete-btn compact-btn"
                        >
                          DELETE
                        </button>
                      </div>
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
                  colSpan="4"
                  style={{ textAlign: "center", padding: "30px" }}
                >
                  No users found.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      {/* PAGINATION CONTROLS */}
      {totalPages > 1 && (
        <div
          style={{
            display: "flex",
            justifyContent: "center",
            alignItems: "center",
            gap: "20px",
            marginTop: "20px",
            marginBottom: "40px",
          }}
        >
          <button
            className="delete-btn"
            disabled={page === 1}
            onClick={() => setPage((p) => Math.max(1, p - 1))}
            style={{
              backgroundColor: page === 1 ? "#ccc" : "#666",
              cursor: page === 1 ? "not-allowed" : "pointer",
            }}
          >
            Previous
          </button>

          <span style={{ fontWeight: "bold", color: "#333" }}>
            Page {page} of {totalPages}
          </span>

          <button
            className="approve-btn"
            disabled={page === totalPages}
            onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
            style={{
              backgroundColor: page === totalPages ? "#ccc" : "#1B5E3A",
              cursor: page === totalPages ? "not-allowed" : "pointer",
            }}
          >
            Next
          </button>
        </div>
      )}
    </div>
  );
}

export default UsersTab;
