const mongoose = require("mongoose");

const documentRequestSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: "UserAuth", required: true },
    type: {
      type: String,
      enum: [
        "Transcript",
        "Certificate",
        "Reference Letter",
        "Statement of Result",
      ],
      required: true,
    },
    details: { type: String, required: true }, // e.g., "Send to X University"
    status: {
      type: String,
      enum: ["Pending", "Processing", "Ready", "Delivered", "Rejected"],
      default: "Pending",
    },
    adminComment: { type: String, default: "" },
  },
  { timestamps: true },
);

module.exports = mongoose.model("DocumentRequest", documentRequestSchema);
