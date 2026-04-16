import React, { useEffect } from "react";
// ✅ Import professional icons from react-icons (already installed in your package.json)
import { FiCheckCircle, FiAlertCircle, FiInfo, FiX } from "react-icons/fi";
import "./Toast.css";

function Toast({ message, type = "success", onClose }) {
  // Auto-dismiss after 4 seconds
  useEffect(() => {
    const timer = setTimeout(() => {
      onClose();
    }, 4000);
    return () => clearTimeout(timer);
  }, [onClose]);

  // Helper to render the correct icon component
  const renderIcon = () => {
    switch (type) {
      case "success":
        return <FiCheckCircle size={20} />;
      case "error":
        return <FiAlertCircle size={20} />;
      case "info":
        return <FiInfo size={20} />;
      default:
        return <FiInfo size={20} />;
    }
  };

  return (
    <div className={`toast-container toast-${type}`}>
      <div className="toast-icon-wrapper">{renderIcon()}</div>

      <div className="toast-content">
        {/* Optional: You could add a title here based on type if needed */}
        <p className="toast-message">{message}</p>
      </div>

      <button className="toast-close-btn" onClick={onClose} aria-label="Close">
        <FiX size={18} />
      </button>
    </div>
  );
}

export default Toast;
