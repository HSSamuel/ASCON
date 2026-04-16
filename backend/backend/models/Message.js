const mongoose = require("mongoose");

// ✅ NEW: Schema for Reactions
const reactionSchema = new mongoose.Schema(
  {
    userId: { type: String, required: true },
    emoji: { type: String, required: true },
  },
  { _id: false }
);

const messageSchema = new mongoose.Schema(
  {
    conversationId: { type: String, required: true },
    sender: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "UserAuth",
      required: true,
    },

    type: {
      type: String,
      enum: ["text", "image", "audio", "file", "poll"],
      default: "text",
    },

    status: {
      type: String,
      enum: ["sent", "delivered", "read"],
      default: "sent",
    },

    text: { type: String, default: "" },
    fileUrl: { type: String, default: "" },
    fileName: { type: String, default: "" },

    pollId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Poll",
      default: null,
    },

    replyTo: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Message",
      default: null,
    },

    isRead: { type: Boolean, default: false },
    isEdited: { type: Boolean, default: false },

    isDeleted: { type: Boolean, default: false },
    deletedFor: [{ type: mongoose.Schema.Types.ObjectId, ref: "UserAuth" }],

    // ✅ NEW: Array to store emoji reactions
    reactions: {
      type: [reactionSchema],
      default: [],
    },
  },
  { timestamps: true },
);

// Compound index for performance
messageSchema.index({ conversationId: 1, createdAt: -1 });

module.exports = mongoose.model("Message", messageSchema);