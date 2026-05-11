const mongoose = require("mongoose");

const userSettingsSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "UserAuth",
      required: true,
      unique: true,
    },
    // The only setting we kept for the app's functionality
    hasSeenWelcome: { type: Boolean, default: false },
  },
  { timestamps: true },
);

module.exports = mongoose.model("UserSettings", userSettingsSchema);
