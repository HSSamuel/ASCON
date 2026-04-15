import React, { useState, useEffect } from "react";
import api from "../api";
import UsersTab from "../components/UsersTab";
import ConfirmModal from "../ConfirmModal";
import Toast from "../Toast";
import { usePaginatedFetch } from "../hooks/usePaginatedFetch";
import { io } from "socket.io-client"; // ✅ NEW: Real-time library

const BASE_URL =
  process.env.REACT_APP_API_URL || "https://ascon.onrender.com";

function UsersManager({ token, canEdit }) {
  const [toast, setToast] = useState(null);
  const [deleteModal, setDeleteModal] = useState({ show: false, id: null });

  // Custom hook handles the API fetching
  const users = usePaginatedFetch(`${BASE_URL}/api/admin/users`, token);

  // ✅ NEW: Listen for real-time registration events
  useEffect(() => {
    // Connect to the same backend with AUTH TOKEN
    const authToken = localStorage.getItem("auth_token") || token;

    const socket = io(BASE_URL, {
      auth: { token: authToken }, // ✅ Secure Auth
    });

    socket.on("connect", () => {
      console.log("🔌 Admin Socket Connected");
    });

    socket.on("admin_stats_update", (data) => {
      if (data && data.type === "NEW_USER") {
        console.log("🔔 New user registered! Refreshing list...");
        users.refresh(); // Triggers re-fetch in the hook
        showToast("New user registered", "success");
      }
    });

    return () => {
      socket.disconnect();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const showToast = (message, type = "success") => setToast({ message, type });

  const approveUser = async (id, name) => {
    try {
      await api.put(`/api/admin/users/${id}/verify`);
      showToast(`${name} verified!`);
      users.refresh();
    } catch (err) {
      showToast("Failed to verify user.", "error");
    }
  };

  const toggleAdmin = async (id) => {
    try {
      await api.put(`/api/admin/users/${id}/toggle-admin`);
      showToast("Admin status updated");
      users.refresh();
    } catch (err) {
      showToast("Update failed.", "error");
    }
  };

  const toggleEditPermission = async (id) => {
    try {
      await api.put(`/api/admin/users/${id}/toggle-edit`);
      showToast("Permissions updated");
      users.refresh();
    } catch (err) {
      showToast("Update failed.", "error");
    }
  };

  const handleDelete = async () => {
    try {
      await api.delete(`/api/admin/users/${deleteModal.id}`);
      showToast("User deleted successfully");
      users.refresh();
    } catch (err) {
      showToast("Delete failed", "error");
    }
    setDeleteModal({ show: false, id: null });
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
        title="Delete User"
        message="Are you sure? This cannot be undone."
        onClose={() => setDeleteModal({ show: false, id: null })}
        onConfirm={handleDelete}
      />
      <UsersTab
        usersList={users.data}
        loading={users.loading}
        page={users.page}
        setPage={users.setPage}
        totalPages={users.totalPages}
        search={users.search}
        setSearch={users.setSearch}
        canEdit={canEdit}
        approveUser={approveUser}
        toggleAdmin={toggleAdmin}
        toggleEditPermission={toggleEditPermission}
        deleteUserClick={(id) => setDeleteModal({ show: true, id })}
      />
    </div>
  );
}

export default UsersManager;
