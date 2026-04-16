const router = require("express").Router();
const {
  register,
  login,
  googleLogin,
  refreshToken,
  forgotPassword,
  resetPassword,
  logout,
} = require("../controllers/authController");

// ✅ Import Middleware (but only use it where needed)
const verifyToken = require("./verifyToken");

// ==========================================
// 🔓 PUBLIC ROUTES (No Token Required)
// ==========================================
router.post("/register", register);
router.post("/login", login);
router.post("/google", googleLogin);
router.post("/refresh", refreshToken);

// ✅ FIX: "Forgot Password" must be PUBLIC.
// Users cannot have a valid token if they forgot their password.
router.post("/forgot-password", forgotPassword);

router.post("/reset-password", resetPassword);

// ==========================================
// 🔒 PROTECTED ROUTES (Token Required)
// ==========================================
router.post("/logout", verifyToken, logout);

module.exports = router;
