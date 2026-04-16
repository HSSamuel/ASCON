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

      <Route
        path="/login"
        element={
          !token ? <Login onLogin={login} /> : <Navigate to="/" replace />
        }
      />

      <Route
        path="/"
        element={
          <ProtectedRoute>
            <AdminDashboard token={token} onLogout={logout} />
          </ProtectedRoute>
        }
      />

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
