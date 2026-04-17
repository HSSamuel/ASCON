const mongoose = require("mongoose");

const userAuthSchema = new mongoose.Schema(
  {
    // Core Authentication
    email: { type: String, required: true, max: 255, min: 6, unique: true },

    // ✅ FIX: Password is now conditionally required ONLY for local logins
    password: {
      type: String,
      required: function () {
        return this.provider === "local";
      },
      max: 1024,
      min: 6,
    },

    // System & Auth States
    isVerified: { type: Boolean, default: true },
    isAdmin: { type: Boolean, default: false },
    canEdit: { type: Boolean, default: false },
    canCreatePolls: { type: Boolean, default: false },

    provider: { type: String, default: "local", enum: ["local", "google"] },

    // Password Reset (Will store hashed tokens)
    resetPasswordToken: { type: String },
    resetPasswordExpires: { type: Date },

    // Real-Time System
    isOnline: { type: Boolean, default: false },
    lastSeen: { type: Date, default: Date.now },
    fcmTokens: { type: [String], default: [] },
  },
  {
    timestamps: true,
  },
);

module.exports = mongoose.model("UserAuth", userAuthSchema);
