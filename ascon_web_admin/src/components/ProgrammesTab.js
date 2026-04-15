import React from "react";

function ProgrammesTab({
  programmesList,
  canEdit,
  editingId,
  progForm,
  setProgForm,
  handleProgrammeSubmit,
  cancelEditProgramme,
  startEditProgramme,
  deleteProgrammeClick,
  showForm,
  setShowForm,
  isSubmitting,
  // ✅ NEW PROPS
  onFileSelect,
  selectedFile,
}) {
  const handleAutoResize = (e) => {
    e.target.style.height = "auto";
    e.target.style.height = `${e.target.scrollHeight}px`;
  };

  return (
    <div>
      <div
        style={{
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
          marginBottom: "20px",
        }}
      >
        <h3 style={{ margin: 0, color: "#1B5E3A" }}>Programmes Directory</h3>

        {canEdit && !showForm && (
          <button
            onClick={() => {
              setShowForm(true);
              window.scrollTo(0, 0);
            }}
            className="approve-btn"
            style={{
              padding: "10px 20px",
              backgroundColor: "#28a745",
              color: "white",
              border: "none",
              borderRadius: "5px",
              cursor: "pointer",
              fontWeight: "bold",
            }}
          >
            + Add New Programme
          </button>
        )}
      </div>

      {canEdit ? (
        <>
          {showForm && (
            <div className="form-card fade-in" style={{ marginBottom: "30px" }}>
              <div
                style={{
                  display: "flex",
                  justifyContent: "space-between",
                  alignItems: "center",
                }}
              >
                <h2
                  style={{
                    color: editingId ? "#d4af37" : "#1B5E3A",
                    marginTop: 0,
                  }}
                >
                  {editingId ? "✏️ Edit Programme" : "🎓 Add New Programme"}
                </h2>
                <button
                  onClick={cancelEditProgramme}
                  style={{
                    background: "none",
                    border: "none",
                    fontSize: "24px",
                    cursor: "pointer",
                    color: "#666",
                  }}
                >
                  &times;
                </button>
              </div>

              <form onSubmit={handleProgrammeSubmit}>
                <div style={{ marginBottom: "15px" }}>
                  <label
                    style={{
                      display: "block",
                      fontSize: "12px",
                      color: "#666",
                      marginBottom: "5px",
                    }}
                  >
                    Programme Title *
                  </label>
                  <input
                    style={{
                      width: "100%",
                      padding: "10px",
                      boxSizing: "border-box",
                    }}
                    placeholder="e.g. Regular Course"
                    value={progForm.title}
                    onChange={(e) =>
                      setProgForm({ ...progForm, title: e.target.value })
                    }
                    required
                  />
                </div>

                {/* ✅ UPDATED: File Input for Image */}
                <div style={{ marginBottom: "15px" }}>
                  <label
                    style={{
                      display: "block",
                      fontSize: "12px",
                      color: "#666",
                      marginBottom: "5px",
                    }}
                  >
                    Programme Cover Image
                  </label>
                  <input
                    type="file"
                    accept="image/*"
                    onChange={(e) => {
                      if (e.target.files && e.target.files[0]) {
                        onFileSelect(e.target.files[0]);
                      }
                    }}
                    style={{
                      width: "100%",
                      padding: "10px",
                      boxSizing: "border-box",
                      border: "1px solid #ccc",
                      borderRadius: "4px",
                      background: "#fff",
                    }}
                  />
                  {/* Show link to existing image if editing and no new file selected */}
                  {editingId && !selectedFile && progForm.image && (
                    <div style={{ marginTop: "5px", fontSize: "12px" }}>
                      Current Image:{" "}
                      <a
                        href={progForm.image}
                        target="_blank"
                        rel="noreferrer"
                        style={{ color: "#1B5E3A" }}
                      >
                        View
                      </a>
                    </div>
                  )}
                </div>

                <div
                  style={{
                    display: "flex",
                    gap: "10px",
                    marginBottom: "15px",
                  }}
                >
                  <div style={{ flex: 1 }}>
                    <label
                      style={{
                        display: "block",
                        fontSize: "12px",
                        color: "#666",
                        marginBottom: "5px",
                      }}
                    >
                      Duration
                    </label>
                    <input
                      style={{
                        width: "100%",
                        padding: "10px",
                        boxSizing: "border-box",
                      }}
                      placeholder="e.g. 6 Weeks"
                      value={progForm.duration}
                      onChange={(e) =>
                        setProgForm({
                          ...progForm,
                          duration: e.target.value,
                        })
                      }
                    />
                  </div>
                  <div style={{ flex: 1 }}>
                    <label
                      style={{
                        display: "block",
                        fontSize: "12px",
                        color: "#666",
                        marginBottom: "5px",
                      }}
                    >
                      Fee
                    </label>
                    <input
                      style={{
                        width: "100%",
                        padding: "10px",
                        boxSizing: "border-box",
                      }}
                      placeholder="e.g. ₦50,000"
                      value={progForm.fee}
                      onChange={(e) =>
                        setProgForm({ ...progForm, fee: e.target.value })
                      }
                    />
                  </div>
                </div>

                <div style={{ marginBottom: "15px" }}>
                  <label
                    style={{
                      display: "block",
                      fontSize: "12px",
                      color: "#666",
                      marginBottom: "5px",
                    }}
                  >
                    Description
                  </label>

                  <textarea
                    style={{
                      width: "100%",
                      padding: "10px",
                      minHeight: "80px",
                      boxSizing: "border-box",
                      fontFamily: "inherit",
                      resize: "vertical",
                      overflow: "hidden",
                    }}
                    placeholder="Brief details (Type to expand)..."
                    value={progForm.description}
                    onInput={handleAutoResize}
                    onChange={(e) => {
                      handleAutoResize(e);
                      setProgForm({
                        ...progForm,
                        description: e.target.value,
                      });
                    }}
                  />
                </div>

                <div style={{ display: "flex", gap: "10px" }}>
                  <button
                    type="submit"
                    className="approve-btn"
                    disabled={isSubmitting}
                    style={{
                      flex: 1,
                      padding: "12px",
                      backgroundColor: editingId ? "#d4af37" : "#1B5E3A",
                      opacity: isSubmitting ? 0.7 : 1,
                      cursor: isSubmitting ? "not-allowed" : "pointer",
                    }}
                  >
                    {isSubmitting ? (
                      <>
                        <span className="loading-spinner"></span> Saving...
                      </>
                    ) : editingId ? (
                      "UPDATE PROGRAMME"
                    ) : (
                      "SAVE PROGRAMME"
                    )}
                  </button>

                  <button
                    type="button"
                    onClick={cancelEditProgramme}
                    className="delete-btn"
                    style={{ flex: 0.3, backgroundColor: "#666" }}
                    disabled={isSubmitting}
                  >
                    CANCEL
                  </button>
                </div>
              </form>
            </div>
          )}
        </>
      ) : (
        <div className="empty-state">🔒 View-Only Mode enabled.</div>
      )}

      <div className="table-responsive">
        <table className="admin-table">
          <thead>
            <tr>
              <th>Image</th>
              <th style={{ width: "40%" }}>Title</th>
              <th>Info</th>
              <th>Action</th>
            </tr>
          </thead>
          <tbody>
            {programmesList.map((prog) => (
              <tr key={prog._id}>
                <td data-label="Image">
                  {prog.image ? (
                    <img
                      src={prog.image}
                      alt="prog"
                      style={{
                        width: "40px",
                        height: "40px",
                        borderRadius: "4px",
                        objectFit: "cover",
                      }}
                    />
                  ) : (
                    <div
                      style={{
                        width: "40px",
                        height: "40px",
                        background: "#eee",
                        borderRadius: "4px",
                        display: "flex",
                        alignItems: "center",
                        justifyContent: "center",
                      }}
                    >
                      🎓
                    </div>
                  )}
                </td>
                <td data-label="Title">
                  <strong>{prog.title}</strong>
                  {prog.description && (
                    <div
                      style={{
                        fontSize: "12px",
                        color: "#666",
                        marginTop: "4px",
                        maxWidth: "300px",
                        whiteSpace: "nowrap",
                        overflow: "hidden",
                        textOverflow: "ellipsis",
                      }}
                    >
                      {prog.description}
                    </div>
                  )}
                </td>
                <td data-label="Info">
                  <div style={{ fontSize: "13px" }}>
                    {prog.duration && <div>⏳ {prog.duration}</div>}
                    {prog.fee && (
                      <div style={{ color: "green" }}>💰 {prog.fee}</div>
                    )}
                  </div>
                </td>
                <td data-label="Action">
                  {canEdit ? (
                    <div className="action-buttons-container">
                      <button
                        onClick={() => startEditProgramme(prog)}
                        className="approve-btn compact-btn"
                        style={{ backgroundColor: "#3498db" }}
                      >
                        EDIT
                      </button>
                      <button
                        className="delete-btn compact-btn"
                        onClick={() => deleteProgrammeClick(prog._id)}
                      >
                        REMOVE
                      </button>
                    </div>
                  ) : (
                    <span style={{ color: "#ccc" }}>🔒</span>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

export default ProgrammesTab;
