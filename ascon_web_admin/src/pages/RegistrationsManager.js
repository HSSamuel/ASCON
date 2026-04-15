import React, { useState } from "react";
import api from "../api"; // ✅ Import centralized API
import RegistrationsTab from "../components/RegistrationsTab";
import ConfirmModal from "../ConfirmModal";
import Toast from "../Toast";
import { usePaginatedFetch } from "../hooks/usePaginatedFetch";

const BASE_URL = process.env.REACT_APP_API_URL || "https://ascon.onrender.com";

function RegistrationsManager({ token, canEdit }) {
  const [toast, setToast] = useState(null);
  const [deleteModal, setDeleteModal] = useState({
    show: false,
    id: null,
    type: null,
  });

  // Data Fetching hooks still use BASE_URL/token for now
  const progRegs = usePaginatedFetch(
    `${BASE_URL}/api/programme-interest`,
    token,
  );
  const eventRegs = usePaginatedFetch(
    `${BASE_URL}/api/event-registration`,
    token,
  );

  const showToast = (message, type = "success") => setToast({ message, type });

  const confirmDelete = (id, type) => {
    const deleteType = type === "programmes" ? "reg_prog" : "reg_event";
    setDeleteModal({ show: true, id, type: deleteType });
  };

  const handleDelete = async () => {
    const { id, type } = deleteModal;
    setDeleteModal({ show: false, id: null, type: null });

    try {
      if (type === "reg_prog") {
        await api.delete(`/api/programme-interest/${id}`); // ✅ Cleaner
        progRegs.refresh();
      } else {
        await api.delete(`/api/event-registration/${id}`); // ✅ Cleaner
        eventRegs.refresh();
      }
      showToast("Registration deleted");
    } catch (err) {
      showToast("Delete failed", "error");
    }
  };

  return (
    <div className="manager-container">
      {toast && (
        <Toast
          message={toast.message}
          type={toast.type}
          onClose={() => setToast(null)}
        />
      )}
      <ConfirmModal
        isOpen={deleteModal.show}
        title="Delete Registration"
        message="Are you sure? This cannot be undone."
        onClose={() => setDeleteModal({ show: false, id: null, type: null })}
        onConfirm={handleDelete}
      />
      <RegistrationsTab
        registrations={progRegs.data}
        eventRegistrations={eventRegs.data}
        isLoading={progRegs.loading || eventRegs.loading}
        onDelete={confirmDelete}
        canEdit={canEdit}
        showToast={showToast}
      />
    </div>
  );
}

export default RegistrationsManager;
