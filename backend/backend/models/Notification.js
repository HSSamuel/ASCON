const mongoose = require("mongoose");

const notificationSchema = new mongoose.Schema({
  recipientId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "UserAuth",
    default: null, // Null = Broadcast
  },
  title: {
    type: String,
    required: true,
  },
  message: {
    type: String,
    required: true,
  },
  data: {
    type: Object,
    default: {},
  },
  isBroadcast: {
    type: Boolean,
    default: false,
  },
  // ✅ TRACKING: Who read it?
  readBy: [
    {
      type: mongoose.Schema.Types.ObjectId,
      ref: "UserAuth",
    },
  ],
  // ✅ NEW: Who deleted it? (Soft Delete)
  deletedBy: [
    {
      type: mongoose.Schema.Types.ObjectId,
      ref: "UserAuth",
    },
  ],
  // Legacy field for personal notifications
  isRead: {
    type: Boolean,
    default: false,
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
});

// ✅ AUTO-DELETE
// This creates a TTL (Time To Live) index.
// MongoDB will automatically delete documents 86400 seconds (24 hours) after 'createdAt'.
notificationSchema.index({ createdAt: 1 }, { expireAfterSeconds: 86400 });

module.exports = mongoose.model("Notification", notificationSchema);
