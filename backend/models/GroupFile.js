const mongoose = require("mongoose");

const groupFileSchema = new mongoose.Schema(
  {
    groupId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Group",
      required: true,
    },
    uploader: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "UserAuth", // Links to the user who uploaded
      required: true,
    },
    fileName: { type: String, required: true },
    fileUrl: { type: String, required: true }, // Cloudinary URL
    fileType: { type: String }, // e.g., 'application/pdf'
    size: { type: Number }, // Size in bytes
  },
  { timestamps: true },
);

module.exports = mongoose.model("GroupFile", groupFileSchema);
