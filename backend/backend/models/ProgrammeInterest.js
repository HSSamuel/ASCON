const mongoose = require("mongoose");

const programmeInterestSchema = new mongoose.Schema({
  programmeId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "Programme",
    required: true,
  },
  programmeTitle: { type: String, required: true },

  // --- Personal Info ---
  fullName: { type: String, required: true, trim: true }, // Keeping single string for simplicity
  email: { type: String, required: true, trim: true, lowercase: true },
  phone: { type: String, required: true, trim: true },
  sex: { type: String, enum: ["Male", "Female"], required: true },

  // --- Address ---
  addressStreet: { type: String, required: true },
  addressLine2: { type: String, default: "" },
  city: { type: String, required: true },
  state: { type: String, required: true },
  country: { type: String, required: true },

  // --- Employment ---
  sponsoringOrganisation: { type: String, required: true },
  department: { type: String, required: true },
  jobTitle: { type: String, required: true },

  // --- Meta ---
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "UserAuth",
    required: false,
  },
  status: {
    type: String,
    enum: ["Pending", "Contacted", "Admitted"],
    default: "Pending",
  },
  createdAt: { type: Date, default: Date.now },
});

module.exports = mongoose.model("ProgrammeInterest", programmeInterestSchema);
