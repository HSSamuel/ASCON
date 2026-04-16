import React, { useState } from "react";
import "../Toast.css";

const ConfirmationToast = ({
  isOpen,
  onClose,
  onConfirm,
  status,
  currentNote,
}) => {
  const [note, setNote] = useState(currentNote || "");

  if (!isOpen) return null;

  const getStatusColor = (s) => {
    switch (s) {
      case "Ready":
        return "text-purple-600";
      case "Delivered":
        return "text-green-600";
      case "Rejected":
        return "text-red-600";
      default:
        return "text-blue-600";
    }
  };

  return (
    <div className="toast-overlay">
      <div className="toast-container confirmation-toast">
        <div className="toast-header">
          <strong>Update Request Status</strong>
          <button onClick={onClose} className="close-btn">
            ×
          </button>
        </div>

        <div className="toast-body">
          <p className="mb-2">
            Mark this request as{" "}
            <strong className={getStatusColor(status)}>{status}</strong>?
          </p>

          <textarea
            className="toast-input"
            placeholder="Add a note (e.g., Tracking ID, Pick-up info)..."
            value={note}
            onChange={(e) => setNote(e.target.value)}
            rows={2}
          />
        </div>

        <div className="toast-actions">
          <button className="cancel-btn" onClick={onClose}>
            Cancel
          </button>
          <button
            className="confirm-btn"
            onClick={() => onConfirm(note)}
            style={{ backgroundColor: "#1B5E3A", color: "white" }}
          >
            Confirm Update
          </button>
        </div>
      </div>
    </div>
  );
};

export default ConfirmationToast;
