const router = require("express").Router();
const rateLimit = require("express-rate-limit");
const upload = require("../config/cloudinary"); // ✅ ADDED: Import Cloudinary Multer

const {
  register,
  login,
  googleLogin,
  refreshToken,
  forgotPassword,
  resetPassword,
  logout,
} = require("../controllers/authController");

const verifyToken = require("./verifyToken");

// Strict rate limiter for password resets (Max 3 attempts per hour per IP)
const passwordResetLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 3,
  message: {
    error:
      "Too many password reset requests from this IP, please try again after an hour.",
  },
});

// ==========================================
// 🔓 PUBLIC ROUTES (No Token Required)
// ==========================================
// ✅ UPDATED: Added upload.single() to process the multipart image payload
router.post("/register", upload.single("profilePicture"), register);

router.post("/login", login);
router.post("/google", googleLogin);
router.post("/refresh", refreshToken);

// Apply the limiter to the public forgot-password route
router.post("/forgot-password", passwordResetLimiter, forgotPassword);

router.post("/reset-password", resetPassword);

// ==========================================
// 🔒 PROTECTED ROUTES (Token Required)
// ==========================================
router.post("/logout", verifyToken, logout);

module.exports = router;
