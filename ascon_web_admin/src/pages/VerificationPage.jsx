import { useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import axios from "axios";
import logo from "../assets/logo.png"; // ⚠️ Ensure this image exists in src/assets/

// ✅ Default Fallback Image (Generic Silhouette)
const defaultAvatar = "https://via.placeholder.com/150";

export default function VerificationPage() {
  // 1. Get the ID from the URL (e.g., ASC-2025-0002)
  const { id } = useParams();

  // 2. State Management
  const [status, setStatus] = useState("loading"); // 'loading' | 'valid' | 'invalid'
  const [data, setData] = useState(null);

  // 3. Environment Config (Falls back to Render if .env is missing)
  const BASE_URL =
    process.env.REACT_APP_API_URL || "https://ascon.onrender.com";

  // 4. Fetch Logic
  useEffect(() => {
    const verifyUser = async () => {
      try {
        console.log(`🔍 Verifying ID: ${id} at ${BASE_URL}...`);

        // The Backend handles the "ASC-..." to "ASC/..." conversion
        const res = await axios.get(`${BASE_URL}/api/directory/verify/${id}`);

        if (res.data) {
          setData(res.data);
          setStatus("valid");
        }
      } catch (err) {
        console.error("❌ Verification Failed:", err);
        setStatus("invalid");
      }
    };

    if (id) verifyUser();
  }, [id, BASE_URL]);

  // 5. Helper: Dynamic Badge Color
  const getBadgeStyle = (userStatus) => {
    const safeStatus = userStatus || "Active";
    if (safeStatus === "Active") {
      return { background: "#1B5E3A", color: "white" }; // ✅ ASCON Green
    } else {
      return { background: "#D32F2F", color: "white" }; // 🔴 Red for Suspended
    }
  };

  // 6. Helper: Image Source Logic
  const getImageSource = () => {
    if (data && data.profilePicture && data.profilePicture.length > 10) {
      return data.profilePicture;
    }
    return defaultAvatar;
  };

  // ==========================================
  // 🖥️ RENDER UI
  // ==========================================
  return (
    <div style={styles.container}>
      <div style={styles.card}>
        {/* LOGO HEADER */}
        <img
          src={logo}
          alt="ASCON Logo"
          style={styles.logo}
          onError={(e) => (e.target.style.display = "none")}
        />

        {/* STATE 1: LOADING */}
        {status === "loading" && (
          <div style={{ padding: "40px 0" }}>
            <div className="spinner" style={styles.spinner}></div>
            <h3 style={{ color: "#666", marginTop: 15 }}>
              Verifying Credentials...
            </h3>
          </div>
        )}

        {/* STATE 2: INVALID / NOT FOUND */}
        {status === "invalid" && (
          <>
            <div style={styles.errorBox}>
              <h2 style={styles.errorTitle}>❌ INVALID ID</h2>
            </div>
            <p style={{ marginTop: 20, fontSize: 16, color: "#333" }}>
              The ID <b>{id}</b> could not be verified in our database.
            </p>
            <p style={{ color: "#D32F2F", fontWeight: "bold", marginTop: 10 }}>
              Please contact the ASCON Secretariat.
            </p>
          </>
        )}

        {/* STATE 3: VALID / VERIFIED */}
        {status === "valid" && data && (
          <>
            {/* ✅ 1. SUCCESS BADGE (Always First) */}
            <div style={styles.successBox}>
              <h2 style={styles.successTitle}>✅ VERIFIED ALUMNUS</h2>
            </div>

            {/* ✅ 2. AVATAR (Below Badge) */}
            <img src={getImageSource()} alt="Profile" style={styles.avatar} />

            {/* ✅ 3. NAME (Below Avatar) */}
            <h2 style={styles.name}>
              {data.fullName ? data.fullName.toUpperCase() : "UNKNOWN USER"}
            </h2>

            <div style={styles.divider}></div>

            <div style={styles.infoRow}>
              <span style={styles.label}>Programme</span>
              <span style={styles.value}>{data.programmeTitle || "N/A"}</span>
            </div>

            <div style={styles.infoRow}>
              <span style={styles.label}>Class Set</span>
              <span style={styles.value}>
                {data.yearOfAttendance || "...."}
              </span>
            </div>

            <div style={styles.infoRow}>
              <span style={styles.label}>Alumni ID</span>
              <span style={styles.valueId}>{data.alumniId}</span>
            </div>

            {/* DYNAMIC STATUS BADGE */}
            <div style={{ ...styles.badge, ...getBadgeStyle(data.status) }}>
              {(data.status || "ACTIVE").toUpperCase()} MEMBER
            </div>

            <p style={styles.footer}>
              Administrative Staff College of Nigeria (ASCON)
            </p>
          </>
        )}
      </div>
    </div>
  );
}

// ==========================================
// 🎨 STYLES OBJECT (Flexbox Fixed)
// ==========================================
const styles = {
  container: {
    display: "flex",
    justifyContent: "center",
    alignItems: "center",
    minHeight: "100vh",
    backgroundColor: "#f0f2f5",
    padding: "20px",
    fontFamily: "'Segoe UI', Tahoma, Geneva, Verdana, sans-serif",
  },
  card: {
    background: "white",
    padding: "40px",
    borderRadius: "20px",
    boxShadow: "0 20px 40px rgba(0,0,0,0.1)",
    maxWidth: "400px",
    width: "100%",
    position: "relative",
    overflow: "hidden",
    // ✅ FLEXBOX ENFORCES VERTICAL STACKING & CENTERING
    display: "flex",
    flexDirection: "column",
    alignItems: "center",
    textAlign: "center",
  },
  logo: {
    width: "80px",
    marginBottom: "20px",
    objectFit: "contain",
  },
  avatar: {
    width: "130px",
    height: "130px",
    borderRadius: "50%",
    objectFit: "cover",
    // ✅ Removed auto margins (Flexbox handles centering)
    marginTop: "20px",
    marginBottom: "8px",
    border: "5px solid #1B5E3A",
    boxShadow: "0 8px 16px rgba(0,0,0,0.1)",
  },
  name: {
    margin: "5px 0 5px 0",
    color: "#333",
    fontSize: "22px",
    fontWeight: "800",
    lineHeight: "1.2",
  },
  divider: {
    height: "2px",
    width: "50px",
    backgroundColor: "#eee",
    margin: "15px auto",
  },
  badge: {
    marginTop: "25px",
    display: "inline-block",
    padding: "10px 25px",
    borderRadius: "50px",
    fontSize: "14px",
    fontWeight: "bold",
    letterSpacing: "1px",
    boxShadow: "0 4px 6px rgba(0,0,0,0.1)",
  },
  successBox: {
    border: "2px solid #1B5E3A",
    padding: "8px 16px",
    borderRadius: "10px",
    background: "rgba(27, 94, 58, 0.05)",
    marginBottom: "5px", // Slight spacing before avatar
  },
  successTitle: {
    color: "#1B5E3A",
    margin: 0,
    fontSize: "18px",
    fontWeight: "bold",
  },
  errorBox: {
    border: "2px solid #D32F2F",
    padding: "8px",
    borderRadius: "10px",
    background: "rgba(211, 47, 47, 0.05)",
  },
  errorTitle: {
    color: "#D32F2F",
    margin: 0,
    fontSize: "18px",
    fontWeight: "bold",
  },
  infoRow: {
    display: "flex",
    flexDirection: "column",
    margin: "12px 0",
    alignItems: "center",
    width: "100%",
  },
  label: {
    fontSize: "11px",
    color: "#888",
    textTransform: "uppercase",
    letterSpacing: "1px",
    fontWeight: "600",
    marginBottom: "2px",
  },
  value: {
    fontSize: "16px",
    fontWeight: "600",
    color: "#444",
  },
  valueId: {
    fontSize: "18px",
    fontWeight: "bold",
    color: "#333",
    fontFamily: "monospace",
    background: "#f4f4f4",
    padding: "4px 8px",
    borderRadius: "4px",
  },
  footer: {
    fontSize: "12px",
    color: "#aaa",
    marginTop: 30,
    fontStyle: "italic",
  },
  spinner: {
    border: "4px solid #f3f3f3",
    borderTop: "4px solid #1B5E3A",
    borderRadius: "50%",
    width: "40px",
    height: "40px",
    margin: "0 auto",
    animation: "spin 1s linear infinite",
  },
};
