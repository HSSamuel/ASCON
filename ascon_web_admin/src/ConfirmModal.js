import React from "react";
import "./ConfirmModal.css";

const ConfirmModal = ({
  isOpen,
  onClose,
  onCancel, // ✅ ADDED: Capture the prop passed from FacilitiesTab
  onConfirm,
  title,
  message,
  confirmText, // ✅ ADDED: Allow custom text (e.g. "Delete")
}) => {
  if (!isOpen) return null;

  // ✅ FIX: Use whichever prop was passed (onClose or onCancel)
  const handleClose = onClose || onCancel;

  return (
    <div className="modal-overlay" onClick={handleClose}>
      {/* Stop click propagation so clicking inside box doesn't close it */}
      <div className="modal-content" onClick={(e) => e.stopPropagation()}>
        <span className="modal-icon">⚠️</span>
        <h3 className="modal-title">{title}</h3>
        <p className="modal-text">{message}</p>

        <div className="modal-actions">
          <button
            type="button" // ✅ ADDED: Prevent accidental form submission
            className="btn-cancel"
            onClick={handleClose}
          >
            Cancel
          </button>
          <button
            type="button" // ✅ ADDED: Prevent accidental form submission
            className="btn-delete"
            onClick={onConfirm}
          >
            {confirmText || "Yes, Delete"} {/* ✅ FIX: Use dynamic text */}
          </button>
        </div>
      </div>
    </div>
  );
};

export default ConfirmModal;
