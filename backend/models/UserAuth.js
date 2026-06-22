const mongoose = require("mongoose");

const userAuthSchema = new mongoose.Schema(
  {
    // Core Authentication
    email: { type: String, required: true, max: 255, min: 6, unique: true },
    password: { type: String, required: true, max: 1024, min: 6 },

    // System & Auth States
    isVerified: { type: Boolean, default: true },
    isAdmin: { type: Boolean, default: false },
    canEdit: { type: Boolean, default: false },
    canCreatePolls: { type: Boolean, default: false },

    provider: { type: String, default: "local", enum: ["local", "google"] },

    // Password Reset
    resetPasswordToken: { type: String },
    resetPasswordExpires: { type: Date },

    // Real-Time System (Needed at the Auth level for socket connection checks)
    isOnline: { type: Boolean, default: false },
    lastSeen: { type: Date, default: Date.now },

    // ✅ Arrays explicitly capped at 5 tokens to manage devices securely
    fcmTokens: { type: [String], default: [] }, // Push notification tokens
    refreshTokens: { type: [String], default: [] }, // Security: Active Refresh Tokens
  },
  {
    timestamps: true,
  },
);

// =========================================================================
// ✅ FIX: Removed the 'next' parameter.
// This prevents Mongoose from incorrectly binding the transaction { session }
// options to 'next', totally eliminating the "next is not a function" error.
// =========================================================================
userAuthSchema.pre("save", function () {
  const MAX_TOKENS = 5;

  // Cap fcmTokens: The authController unshifts to position 0,
  // so the first 5 elements are the newest ones.
  if (this.fcmTokens && this.fcmTokens.length > MAX_TOKENS) {
    this.fcmTokens = this.fcmTokens.slice(0, MAX_TOKENS);
  }

  // Cap refreshTokens: The authController appends to the end,
  // so the last 5 elements are the newest ones.
  if (this.refreshTokens && this.refreshTokens.length > MAX_TOKENS) {
    this.refreshTokens = this.refreshTokens.slice(-MAX_TOKENS);
  }
});

module.exports = mongoose.model("UserAuth", userAuthSchema);
