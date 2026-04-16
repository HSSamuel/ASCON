import React, { useState, useEffect } from "react";
import api from "../api";
import { FaTrash, FaImage, FaUser, FaClock } from "react-icons/fa";
import "./UpdatesManager.css"; // ✅ FIXED: Changed from JobsManager.css to UpdatesManager.css
import Toast from "../Toast";
import ConfirmModal from "../ConfirmModal";
import SkeletonTable from "../components/SkeletonTable";

function UpdatesManager({ canEdit }) {
  const [posts, setPosts] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [toast, setToast] = useState(null);
  const [deleteModal, setDeleteModal] = useState({ show: false, id: null });
  const [isSubmitting, setIsSubmitting] = useState(false);

  const showToast = (message, type = "success") => setToast({ message, type });

  const fetchUpdates = async () => {
    try {
      const res = await api.get("/api/updates");
      setPosts(res.data.data || []); // Access 'data' inside response
      setIsLoading(false);
    } catch (err) {
      console.error("Error fetching updates:", err);
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchUpdates();
  }, []);

  const handleDelete = async () => {
    setIsSubmitting(true);
    try {
      await api.delete(`/api/updates/${deleteModal.id}`);
      showToast("Post removed successfully");
      // Remove from local state immediately
      setPosts(posts.filter((post) => post._id !== deleteModal.id));
    } catch (err) {
      showToast("Failed to delete post", "error");
    } finally {
      setIsSubmitting(false);
      setDeleteModal({ show: false, id: null });
    }
  };

  // Helper to truncate long text
  const truncate = (str, n) => {
    return str?.length > n ? str.substr(0, n - 1) + "..." : str;
  };

  if (isLoading) return <SkeletonTable columns={5} />;

  return (
    <div className="updates-container">
      {" "}
      {/* ✅ Updated class name to match new CSS */}
      {toast && (
        <Toast
          message={toast.message}
          type={toast.type}
          onClose={() => setToast(null)}
        />
      )}
      <ConfirmModal
        isOpen={deleteModal.show}
        title="Remove Post?"
        message="This will permanently delete this content from the user feed. This action cannot be undone."
        onClose={() => setDeleteModal({ show: false, id: null })}
        onConfirm={handleDelete}
        isLoading={isSubmitting}
      />
      <div className="table-header">
        <h2>Feed Moderation</h2>
        <div style={{ color: "#666", fontSize: "0.9rem" }}>
          Monitor and moderate user-generated content
        </div>
      </div>
      <div className="table-responsive">
        <table className="admin-table">
          <thead>
            <tr>
              <th>Author</th>
              <th>Content Snippet</th>
              <th>Media</th>
              <th>Posted Date</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {posts.length > 0 ? (
              posts.map((post) => (
                <tr key={post._id}>
                  {/* AUTHOR */}
                  <td>
                    <div
                      style={{
                        display: "flex",
                        alignItems: "center",
                        gap: "10px",
                      }}
                    >
                      {post.author?.profilePicture ? (
                        <img
                          src={post.author.profilePicture}
                          alt="avatar"
                          style={{
                            width: "30px",
                            height: "30px",
                            borderRadius: "50%",
                            objectFit: "cover",
                          }}
                        />
                      ) : (
                        <div
                          style={{
                            width: "30px",
                            height: "30px",
                            borderRadius: "50%",
                            background: "#eee",
                            display: "flex",
                            alignItems: "center",
                            justifyContent: "center",
                          }}
                        >
                          <FaUser size={12} color="#999" />
                        </div>
                      )}
                      <div>
                        <div className="font-bold">
                          {post.author?.fullName || "Unknown"}
                        </div>
                        <div style={{ fontSize: "0.75rem", color: "#888" }}>
                          {post.author?.jobTitle}
                        </div>
                      </div>
                    </div>
                  </td>

                  {/* CONTENT */}
                  <td style={{ maxWidth: "300px" }}>
                    {post.text ? (
                      <span title={post.text}>{truncate(post.text, 60)}</span>
                    ) : (
                      <span style={{ color: "#ccc", fontStyle: "italic" }}>
                        (No text content)
                      </span>
                    )}
                  </td>

                  {/* MEDIA */}
                  <td>
                    {post.mediaUrl ? (
                      <a
                        href={post.mediaUrl}
                        target="_blank"
                        rel="noopener noreferrer"
                        style={{
                          display: "flex",
                          alignItems: "center",
                          gap: "5px",
                          color: "#007bff",
                          textDecoration: "none",
                        }}
                      >
                        <FaImage /> View Media
                      </a>
                    ) : (
                      <span style={{ color: "#ccc" }}>-</span>
                    )}
                  </td>

                  {/* DATE */}
                  <td>
                    <div
                      style={{
                        display: "flex",
                        alignItems: "center",
                        gap: "5px",
                        color: "#666",
                      }}
                    >
                      <FaClock size={12} />
                      {new Date(post.createdAt).toLocaleDateString()}
                    </div>
                  </td>

                  {/* ACTIONS */}
                  <td>
                    {canEdit && (
                      <button
                        onClick={() =>
                          setDeleteModal({ show: true, id: post._id })
                        }
                        className="delete-btn compact-btn"
                        title="Remove Post"
                        style={{
                          backgroundColor: "#dc3545",
                          color: "white",
                          padding: "6px 12px",
                        }}
                      >
                        <FaTrash /> Remove
                      </button>
                    )}
                  </td>
                </tr>
              ))
            ) : (
              <tr>
                <td colSpan="5" className="empty-state">
                  No updates posted yet.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}

export default UpdatesManager;
