import React from "react";
import {
  BrowserRouter as Router,
  Routes,
  Route,
  Navigate,
} from "react-router-dom";
import { AuthProvider, useAuth } from "./context/AuthContext";
import AdminDashboard from "./AdminDashboard";
import Login from "./Login";
import ResetPassword from "./pages/ResetPassword";
import VerificationPage from "./pages/VerificationPage";
import LandingPage from "./pages/LandingPage";

const ProtectedRoute = ({ children }) => {
  const { token, isLoading } = useAuth();

  if (isLoading) {
    return (
      <div
        style={{
          display: "flex",
          justifyContent: "center",
          alignItems: "center",
          height: "100vh",
          background: "#f4f6f9",
        }}
      >
        <div className="spinner-border text-primary" role="status">
          <span className="visually-hidden">Loading...</span>
        </div>
      </div>
    );
  }

  if (!token) {
    return <Navigate to="/login" replace />;
  }

  return children;
};

const AppRoutes = () => {
  const { token, login, logout } = useAuth();

  return (
    <Routes>
      <Route path="/verify/:id" element={<VerificationPage />} />
      <Route path="/reset-password" element={<ResetPassword />} />

      {/* ✅ 2. The Landing Page becomes the default root */}
      <Route path="/" element={<LandingPage />} />

      {/* ✅ 3. Update Login redirect to push to /dashboard instead of / */}
      <Route
        path="/login"
        element={
          !token ? (
            <Login onLogin={login} />
          ) : (
            <Navigate to="/dashboard" replace />
          )
        }
      />

      {/* ✅ 4. Move the Admin Dashboard to a dedicated /dashboard route */}
      <Route
        path="/dashboard"
        element={
          <ProtectedRoute>
            <AdminDashboard token={token} onLogout={logout} />
          </ProtectedRoute>
        }
      />

      {/* Fallback to landing page for unknown routes */}
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
};

function App() {
  return (
    <AuthProvider>
      <Router>
        <AppRoutes />
      </Router>
    </AuthProvider>
  );
}

export default App;
