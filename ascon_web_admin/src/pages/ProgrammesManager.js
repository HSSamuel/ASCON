import React, { useState } from "react";
import api from "../api"; // ✅ Import centralized API
import ProgrammesTab from "../components/ProgrammesTab";
import ConfirmModal from "../ConfirmModal";
import Toast from "../Toast";
import { usePaginatedFetch } from "../hooks/usePaginatedFetch";

function ProgrammesManager({ canEdit }) {
  const [toast, setToast] = useState(null);
  const [deleteModal, setDeleteModal] = useState({ show: false, id: null });
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const [showForm, setShowForm] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [editingId, setEditingId] = useState(null);

  // ✅ NEW: File State for uploads
  const [selectedFile, setSelectedFile] = useState(null);

  const [progForm, setProgForm] = useState({
    title: "",
    description: "",
    location: "ASCON Complex, Badagry",
    duration: "",
    fee: "",
    image: "",
  });

  const BASE_URL =
    process.env.REACT_APP_API_URL || "https://ascon.onrender.com";

  const programmes = usePaginatedFetch(
    `${BASE_URL}/api/admin/programmes`,
    localStorage.getItem("auth_token"),
    refreshTrigger,
  );

  const showToast = (message, type = "success") => setToast({ message, type });

  const resetForm = () => {
    setEditingId(null);
    setSelectedFile(null); // ✅ Clear file on reset
    setProgForm({
      title: "",
      description: "",
      location: "ASCON Complex, Badagry",
      duration: "",
      fee: "",
      image: "",
    });
    setShowForm(false);
  };

  const handleProgrammeSubmit = async (e) => {
    e.preventDefault();
    setIsSubmitting(true);

    try {
      // ✅ UPDATED: Use FormData for File Uploads
      const formData = new FormData();
      formData.append("title", progForm.title);
      formData.append("description", progForm.description);
      formData.append("location", progForm.location);
      formData.append("duration", progForm.duration);
      formData.append("fee", progForm.fee);

      // Handle Image Logic
      if (selectedFile) {
        formData.append("image", selectedFile);
      } else {
        // If no new file, send the existing image string (if any)
        formData.append("image", progForm.image);
      }

      // Important: Allow axios to set the boundary automatically
      const config = { headers: { "Content-Type": "multipart/form-data" } };

      if (editingId) {
        await api.put(`/api/admin/programmes/${editingId}`, formData, config);
        showToast("Programme updated");
      } else {
        await api.post("/api/admin/programmes", formData, config);
        showToast("Programme created");
      }
      resetForm();
      setRefreshTrigger((prev) => prev + 1);
    } catch (err) {
      console.error(err);
      showToast(
        err.response?.data?.message || "Error saving programme",
        "error",
      );
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleDelete = async () => {
    setIsSubmitting(true);
    try {
      await api.delete(`/api/admin/programmes/${deleteModal.id}`);
      showToast("Programme deleted");
      setRefreshTrigger((prev) => prev + 1);
    } catch (err) {
      showToast("Delete failed", "error");
    } finally {
      setIsSubmitting(false);
      setDeleteModal({ show: false, id: null });
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
        title="Delete Programme"
        message="Are you sure?"
        onClose={() => setDeleteModal({ show: false, id: null })}
        onConfirm={handleDelete}
        isLoading={isSubmitting}
      />

      <ProgrammesTab
        programmesList={programmes.data}
        canEdit={canEdit}
        editingId={editingId}
        progForm={progForm}
        setProgForm={setProgForm}
        handleProgrammeSubmit={handleProgrammeSubmit}
        showForm={showForm}
        setShowForm={setShowForm}
        isSubmitting={isSubmitting}
        // ✅ NEW: Pass file handler
        onFileSelect={(file) => setSelectedFile(file)}
        selectedFile={selectedFile}
        startEditProgramme={(prog) => {
          setEditingId(prog._id);
          setSelectedFile(null); // Reset file selection when starting edit
          setProgForm({
            title: prog.title || "",
            description: prog.description || "",
            location: prog.location || "ASCON Complex, Badagry",
            duration: prog.duration || "",
            fee: prog.fee || "",
            image: prog.image || "",
          });
          setShowForm(true);
          window.scrollTo(0, 0);
        }}
        cancelEditProgramme={resetForm}
        deleteProgrammeClick={(id) => setDeleteModal({ show: true, id })}
      />
    </div>
  );
}

export default ProgrammesManager;
