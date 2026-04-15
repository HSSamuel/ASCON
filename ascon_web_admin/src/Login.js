import React, { useState } from "react";
import api from "./api"; // ✅ Import centralized API
import { GoogleLogin } from "@react-oauth/google";
import { jwtDecode } from "jwt-decode";
import "./App.css";
import logo from "./assets/logo.png";

function Login({ onLogin }) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState("");
  const [isLoading, setIsLoading] = useState(false);

  // Helper to clear error when user types
  const handleInputChange = (setter, value) => {
    setError("");
    setter(value);
  };

  // --- STANDARD EMAIL LOGIN ---
  const handleLogin = async (e) => {
    e.preventDefault();
    setError("");
    setIsLoading(true);

    try {
      const res = await api.post("/api/auth/login", { email, password });
      processLogin(res.data.token);
    } catch (err) {
      const msg =
        err.response?.data?.message ||
        "Login failed. Please check credentials.";
      setError(msg);
      setIsLoading(false);
    }
  };

  // --- GOOGLE LOGIN ---
  const handleGoogleSuccess = async (credentialResponse) => {
    setError("");
    setIsLoading(true);

    try {
      const res = await api.post("/api/auth/google", {
        token: credentialResponse.credential,
      });
      processLogin(res.data.token);
    } catch (err) {
      if (err.response && err.response.status === 404) {
        setError("Access Denied: You are not a registered Admin.");
      } else {
        setError("Google Login Failed. Please try again.");
      }
      setIsLoading(false);
    }
  };

  const processLogin = (token) => {
    try {
      const decoded = jwtDecode(token);

      // Check for Admin privileges
      if (decoded.isAdmin === true) {
        // Clean up old token first
        localStorage.removeItem("auth_token");
        localStorage.setItem("auth_token", token);

        // Trigger parent state update
        onLogin(token);
      } else {
        setError("Access Denied: You do not have Admin privileges.");
        setIsLoading(false);
      }
    } catch (e) {
      console.error("Token Error:", e);
      setError("Invalid security token received.");
      setIsLoading(false);
    }
  };

  return (
    <div className="login-container">
      <div className="login-card">
        <img src={logo} alt="ASCON Logo" className="login-logo" />
        <h2 className="login-title">Admin Portal</h2>

        {error && (
          <div className="login-error" role="alert">
            {error}
          </div>
        )}

        <form onSubmit={handleLogin}>
          <div className="form-group">
            <label htmlFor="email">Email Address</label>
            <input
              id="email"
              type="email"
              value={email}
              onChange={(e) => handleInputChange(setEmail, e.target.value)}
              required
              disabled={isLoading}
              placeholder="Enter admin email"
              className="login-input"
            />
          </div>

          <div className="form-group">
            <label htmlFor="password">Password</label>
            <div className="password-wrapper">
              <input
                id="password"
                type={showPassword ? "text" : "password"}
                value={password}
                onChange={(e) => handleInputChange(setPassword, e.target.value)}
                required
                disabled={isLoading}
                placeholder="Enter password"
                className="login-input"
              />
              <button
                type="button"
                className="password-toggle-btn"
                onClick={() => setShowPassword(!showPassword)}
                disabled={isLoading}
                aria-label={showPassword ? "Hide password" : "Show password"}
                title={showPassword ? "Hide password" : "Show password"}
              >
                {showPassword ? "🙈" : "👁️"}
              </button>
            </div>
          </div>

          <button
            type="submit"
            className="approve-btn login-btn"
            disabled={isLoading}
          >
            {isLoading ? <span className="loading-spinner"></span> : "LOGIN"}
          </button>
        </form>

        {/* Divider */}
        <div
          style={{ display: "flex", alignItems: "center", margin: "20px 0" }}
        >
          <div
            style={{ flex: 1, height: "1px", backgroundColor: "#ddd" }}
          ></div>
          <span
            style={{
              padding: "0 10px",
              color: "#888",
              fontSize: "12px",
              fontWeight: "500",
            }}
          >
            OR
          </span>
          <div
            style={{ flex: 1, height: "1px", backgroundColor: "#ddd" }}
          ></div>
        </div>

        <div
          className="google-login-container"
          style={{ display: "flex", justifyContent: "center", width: "100%" }}
        >
          <GoogleLogin
            onSuccess={handleGoogleSuccess}
            onError={() => setError("Google Login Failed")}
            theme="outline"
            size="large"
            width="300"
            text="signin_with"
          />
        </div>
      </div>
    </div>
  );
}

export default Login;
