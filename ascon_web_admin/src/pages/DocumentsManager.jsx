import React, { useState, useEffect, useCallback } from "react";
import api from "../api";
import { useAuth } from "../hooks/useAuth";
import DocumentsTab from "../components/DocumentsTab";
import ConfirmationToast from "../components/ConfirmationToast"; // ✅ Import new component
import Toast from "../Toast";

const DocumentsManager = ({ canEdit }) => {
  const { token } = useAuth();
  const [docs, setDocs] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [toast, setToast] = useState(null);

  // ✅ New State for Confirmation Logic
  const [confirmAction, setConfirmAction] = useState({
    isOpen: false,
    doc: null,
    newStatus: "",
  });

  const showToast = (message, type = "success") => {
    setToast({ message, type });
  };

  const fetchDocs = useCallback(async () => {
    try {
      const data = await api.getDocuments(token);
      setDocs(data);
    } catch (err) {
      console.error(err);
      showToast("Failed to load requests", "error");
    } finally {
      setIsLoading(false);
    }
  }, [token]);

  useEffect(() => {
    fetchDocs();
  }, [fetchDocs]);

  // ✅ 1. Trigger the Confirmation Toast instead of window.confirm
  const initiateStatusUpdate = (doc, newStatus) => {
    setConfirmAction({
      isOpen: true,
      doc: doc,
      newStatus: newStatus,
    });
  };

  // ✅ 2. Handle the Actual API Call after Confirmation
  const handleConfirmUpdate = async (note) => {
    const { doc, newStatus } = confirmAction;

    // Close confirmation toast immediately
    setConfirmAction({ isOpen: false, doc: null, newStatus: "" });

    try {
      const updatedDoc = await api.updateDocumentStatus(
        doc._id,
        newStatus,
        note, // Pass the note from the custom toast input
        token,
      );

      setDocs(docs.map((d) => (d._id === doc._id ? updatedDoc : d)));
      showToast(`Request updated to ${newStatus}`, "success");
    } catch (err) {
      showToast("Update failed", "error");
    }
  };

  return (
    <div className="manager-container">
      <h1 className="text-2xl font-bold mb-6 text-gray-800">
        Document Requests
      </h1>

      {toast && (
        <Toast
          message={toast.message}
          type={toast.type}
          onClose={() => setToast(null)}
        />
      )}

      {/* ✅ Render the Confirmation Toast */}
      <ConfirmationToast
        isOpen={confirmAction.isOpen}
        onClose={() => setConfirmAction({ ...confirmAction, isOpen: false })}
        onConfirm={handleConfirmUpdate}
        status={confirmAction.newStatus}
        currentNote={confirmAction.doc?.adminComment}
      />

      <DocumentsTab
        documentsList={docs}
        loading={isLoading}
        canEdit={canEdit}
        updateStatus={initiateStatusUpdate} // Pass the new initiator function
        search={search}
        setSearch={setSearch}
      />
    </div>
  );
};

export default DocumentsManager;
