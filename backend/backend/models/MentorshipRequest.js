const mongoose = require("mongoose");

const MentorshipRequestSchema = new mongoose.Schema(
  {
    mentor: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "UserAuth",
      required: true,
    },
    mentee: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "UserAuth",
      required: true,
    },
    status: {
      type: String,
      enum: ["Pending", "Accepted", "Rejected"],
      default: "Pending",
    },
    pitch: {
      type: String,
      default: "", // Short note: "I admire your work in..."
    },
  },
  { timestamps: true },
);

// ✅ Prevent Duplicate Requests
// A mentee can only have ONE active request per mentor
MentorshipRequestSchema.index({ mentor: 1, mentee: 1 }, { unique: true });

module.exports = mongoose.model("MentorshipRequest", MentorshipRequestSchema);
