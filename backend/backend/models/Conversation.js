const mongoose = require("mongoose");

const conversationSchema = new mongoose.Schema(
  {
    participants: [{ type: mongoose.Schema.Types.ObjectId, ref: "UserAuth" }],
    lastMessage: { type: String, default: "" },
    lastMessageSender: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "UserAuth",
    },
    lastMessageAt: { type: Date, default: Date.now },
    isGroup: { type: Boolean, default: false },
    groupName: { type: String, default: "" },
    groupAdmin: { type: mongoose.Schema.Types.ObjectId, ref: "UserAuth" },

    // ✅ NEW: Link to the Community Group ID
    groupId: { type: mongoose.Schema.Types.ObjectId, ref: "Group" },
  },
  { timestamps: true },
);

conversationSchema.index({ participants: 1 });
conversationSchema.index({ lastMessageAt: -1 });
// ✅ Index for finding the group chat quickly
conversationSchema.index({ groupId: 1 });

module.exports = mongoose.model("Conversation", conversationSchema);
