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

    // Professional Fields
    skills: { type: [String], default: [] },
    jobTitle: { type: String, default: "" },
    organization: { type: String, default: "" },

    // ASCON History
    programmeTitle: { type: String, required: false },
    customProgramme: { type: String, default: "" },
    yearOfAttendance: { type: Number, required: false },
  },
  { timestamps: true },
);

// Adjusted indexing to match available fields
userProfileSchema.index({
  fullName: "text",
  jobTitle: "text",
  organization: "text",
});

module.exports = mongoose.model("UserProfile", userProfileSchema);
