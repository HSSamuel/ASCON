import { useState, useEffect } from "react";
import { useLocation } from "react-router-dom";
import axios from "axios";
import { FaEye, FaEyeSlash, FaCheckCircle } from "react-icons/fa";
import logo from "../assets/logo.png";
import { Link } from "react-router-dom";

export default function ResetPassword() {
  const [token, setToken] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");

  // Visibility States
  const [showNewPassword, setShowNewPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);

  const [message, setMessage] = useState("");
  const [error, setError] = useState(false);
  const [isLoading, setIsLoading] = useState(false);

  // Track if reset is finished to show the final success view
  const [isSuccess, setIsSuccess] = useState(false);

  const useQuery = () => {
    return new URLSearchParams(useLocation().search);
  };

  const query = useQuery();

  const BASE_URL = process.env.REACT_APP_API_URL || "http://localhost:5000";

  useEffect(() => {
    const tokenParam = query.get("token");
    if (tokenParam) {
      setToken(tokenParam);
    } else {
      setError(true);
      setMessage("Invalid or missing reset token.");
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (newPassword !== confirmPassword) {
      setError(true);
      setMessage("Passwords do not match!");
      return;
    }

    if (newPassword.length < 6) {
      setError(true);
      setMessage("Password must be at least 6 characters.");
      return;
    }

    setIsLoading(true);
    try {
      await axios.post(`${BASE_URL}/api/auth/reset-password`, {
        token: token,
        newPassword: newPassword,
      });

      // Clear any admin sessions just in case
      localStorage.clear();
      sessionStorage.clear();

      // Show Success State instead of redirecting
      setIsSuccess(true);
    } catch (err) {
      setError(true);
      setMessage(err.response?.data?.message || "Something went wrong.");
    } finally {
      setIsLoading(false);
    }
  };

  // ✅ RENDER: SUCCESS VIEW (UPDATED FOR MOBILE USERS)
  if (isSuccess) {
    return (
      <div className="reset-container">
        <div
          className="reset-card"
          style={{ textAlign: "center", padding: "40px 20px" }}
        >
          <FaCheckCircle
            size={60}
            color="#1B5E3A"
            style={{ marginBottom: "20px" }}
          />

          <h2 className="reset-title" style={{ color: "#1B5E3A" }}>
            Success!
          </h2>

          <p
            className="reset-subtitle"
            style={{ fontSize: "16px", marginTop: "10px", color: "#555" }}
          >
            Your password has been reset successfully.
          </p>

          <div style={{ marginTop: "30px", padding: "15px", backgroundColor: "#f0fdf4", borderRadius: "8px", border: "1px solid #bbf7d0" }}>
            <p style={{ fontWeight: 'bold', color: '#166534', margin: 0 }}>
              📱 Mobile App Users:
            </p>
            <p style={{ fontSize: '0.95rem', color: '#166534', marginTop: '5px' }}>
              Please return to the ASCON Alumni App to login with your new password.
            </p>
          </div>

          <div style={{ marginTop: "25px", borderTop: "1px solid #eee", paddingTop: "20px" }}>
            <p style={{ fontSize: '0.85rem', color: '#888' }}>
              Are you an Admin? <Link to="/login" style={{ color: "#1B5E3A", fontWeight: "bold" }}>Login to Portal here</Link>
            </p>
          </div>
        </div>
      </div>
    );
  }

  // ✅ RENDER: FORM VIEW (Normal Reset Form)
  return (
    <div className="reset-container">
      <div className="reset-card">
        <div style={{ textAlign: "center", marginBottom: "20px" }}>
          <img
            src={logo}
            alt="ASCON Logo"
            style={{ width: "100px", height: "auto" }}
          />
        </div>

        <h2 className="reset-title">Reset Password</h2>
        <p className="reset-subtitle">Enter your new password below.</p>

        {message && !isSuccess && (
          <div
            className={error ? "reset-error-banner" : "reset-success-banner"}
          >
            {message}
          </div>
        )}

        {!token ? (
          <p style={{ color: "red", textAlign: "center" }}>
            Error: Invalid Link.
          </p>
        ) : (
          <form onSubmit={handleSubmit} className="reset-form">
            <div className="password-wrapper">
              <input
                type={showNewPassword ? "text" : "password"}
                placeholder="New Password"
                className="reset-input"
                value={newPassword}
                onChange={(e) => setNewPassword(e.target.value)}
                required
              />
              <span
                className="password-toggle-btn"
                onClick={() => setShowNewPassword(!showNewPassword)}
              >
                {showNewPassword ? <FaEyeSlash /> : <FaEye />}
              </span>
            </div>

            <div className="password-wrapper">
              <input
                type={showConfirmPassword ? "text" : "password"}
                placeholder="Confirm Password"
                className="reset-input"
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
                required
              />
              <span
                className="password-toggle-btn"
                onClick={() => setShowConfirmPassword(!showConfirmPassword)}
              >
                {showConfirmPassword ? <FaEyeSlash /> : <FaEye />}
              </span>
            </div>

            <button type="submit" className="reset-button" disabled={isLoading}>
              {isLoading ? "Updating..." : "Update Password"}
            </button>
          </form>
        )}
      </div>
    </div>
  );
}