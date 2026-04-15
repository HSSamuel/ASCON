const mongoose = require("mongoose");

const userProfileSchema = new mongoose.Schema(
  {
    // Link to the Auth Account
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "UserAuth",
      required: true,
      unique: true,
    },

    // Core Identity
    fullName: { type: String, required: true, min: 6, max: 255 },
    alumniId: { type: String, unique: true, sparse: true },
    profilePicture: { type: String, default: "" },
    bio: { type: String, default: "" },

    // Contact
    phoneNumber: { type: String, default: "" },
    linkedin: { type: String, default: "" },

    // Professional & AI Matching Fields
    industry: { type: String, default: "" },
    skills: { type: [String], default: [] },
    jobTitle: { type: String, default: "" },
    organization: { type: String, default: "" },

    // ASCON History
    programmeTitle: { type: String, required: false },
    customProgramme: { type: String, default: "" },
    yearOfAttendance: { type: Number, required: false },

    // Location Data
    city: { type: String, default: "" },
    state: { type: String, default: "" },
    country: { type: String, default: "" },

    // ✅ NEW: Feature Flags & Celebration Data
    dateOfBirth: { type: Date }, // For "Celebration" Quick Win
    isOpenToMentorship: { type: Boolean, default: false },
    isLocationVisible: { type: Boolean, default: false },
  },
  { timestamps: true },
);

// ✅ Advanced Indexing for lightning-fast directory searches
userProfileSchema.index({
  fullName: "text",
  jobTitle: "text",
  organization: "text",
  industry: "text",
  city: "text",
});

module.exports = mongoose.model("UserProfile", userProfileSchema);
