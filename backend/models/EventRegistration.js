const mongoose = require("mongoose");

const eventRegistrationSchema = new mongoose.Schema(
  {
    eventId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Event",
      required: true,
    },
    // ✅ ADDED: Snapshot of event details (in case Event is deleted later)
    eventTitle: { type: String, default: "" },
    eventType: { type: String, default: "" },

    fullName: { type: String, required: true },
    email: { type: String, required: true },
    phone: { type: String, required: true },

    // ✅ ADDED: Extended Profile Data
    sex: { type: String, default: "" },
    organization: { type: String, default: "" },
    jobTitle: { type: String, default: "" },
    specialRequirements: { type: String, default: "" },

    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "UserAuth",
      required: false,
    },
  },
  { timestamps: true },
);

module.exports = mongoose.model("EventRegistration", eventRegistrationSchema);
