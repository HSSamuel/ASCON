const mongoose = require("mongoose");

const userSettingsSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "UserAuth",
      required: true,
      unique: true,
    },
    // Privacy Controls
    isEmailVisible: { type: Boolean, default: true },
    isPhoneVisible: { type: Boolean, default: false },
    isLocationVisible: { type: Boolean, default: false },
    isOpenToMentorship: { type: Boolean, default: false },

    // ✅ NEW: Birthday Privacy
    isBirthdayVisible: { type: Boolean, default: true },

    // App State
    hasSeenWelcome: { type: Boolean, default: false },
    fcmToken: { type: String, default: "" },
  },
  { timestamps: true },
);

module.exports = mongoose.model("UserSettings", userSettingsSchema);
