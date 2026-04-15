const mongoose = require("mongoose");

const userSchema = new mongoose.Schema(
  {
    fullName: { type: String, required: true, min: 6, max: 255 },
    email: { type: String, required: true, max: 255, min: 6 },
    password: { type: String, required: true, max: 1024, min: 6 },
    phoneNumber: { type: String, default: "" },

    programmeTitle: { type: String, required: false },
    customProgramme: { type: String, default: "" },
    yearOfAttendance: { type: Number, required: false },

    jobTitle: { type: String, default: "" },
    organization: { type: String, default: "" },
    bio: { type: String, default: "" },
    linkedin: { type: String, default: "" },

    // Store the Phone's Notification Tokens
    fcmTokens: { type: [String], default: [] },

    alumniId: { type: String, unique: true, sparse: true },
    hasSeenWelcome: { type: Boolean, default: false },

    isAdmin: { type: Boolean, default: false },
    isVerified: { type: Boolean, default: true },
    canEdit: { type: Boolean, default: false },
    profilePicture: { type: String, default: "" },

    // ✅ NEW: Tracks origin ("local" or "google"), but we allow cross-login
    provider: {
      type: String,
      default: "local",
      enum: ["local", "google"],
    },

    // Password Reset
    resetPasswordToken: { type: String },
    resetPasswordExpires: { type: Date },

    date: { type: Date, default: Date.now },
  },
  {
    timestamps: true,
  }
);

userSchema.index({ email: 1 });
userSchema.index({
  fullName: "text",
  jobTitle: "text",
  organization: "text",
  email: "text",     
  alumniId: "text"
});

module.exports = mongoose.model("User", userSchema);
