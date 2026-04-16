const mongoose = require("mongoose");

// Schema for Comments inside a Post
const commentSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "UserAuth",
      required: true,
    },
    text: { type: String, required: true, max: 500 },
  },
  { timestamps: true },
);

// Main Post Schema
const updatePostSchema = new mongoose.Schema(
  {
    authorId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "UserAuth",
      required: true,
    },

    text: { type: String, max: 1000, default: "" },
    mediaUrl: { type: String, default: "" }, // Kept for backward compatibility
    mediaUrls: { type: [String], default: [] }, // ✅ NEW: Array for multiple images
    mediaType: {
      type: String,
      enum: ["image", "video", "none"],
      default: "none",
    },

    likes: [{ type: mongoose.Schema.Types.ObjectId, ref: "UserAuth" }],
    comments: [commentSchema],

    isBlocked: { type: Boolean, default: false },
  },
  {
    timestamps: true,
  },
);

updatePostSchema.index({ createdAt: -1 });
updatePostSchema.index({ authorId: 1 });

module.exports = mongoose.model("UpdatePost", updatePostSchema);
