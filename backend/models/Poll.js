const mongoose = require("mongoose");

const pollSchema = new mongoose.Schema({
  question: { type: String, required: true },
  options: [
    {
      text: { type: String, required: true },
      voteCount: { type: Number, default: 0 },
    },
  ],
  votedUsers: [{ type: mongoose.Schema.Types.ObjectId, ref: "UserAuth" }],

  // ✅ UPDATED: Made Group Optional (for Global Dashboard Polls)
  group: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "Group",
    required: false,
  },

  createdBy: { type: mongoose.Schema.Types.ObjectId, ref: "UserAuth" },
  isActive: { type: Boolean, default: true },
  expiresAt: { type: Date },
  createdAt: { type: Date, default: Date.now },
});

module.exports = mongoose.model("Poll", pollSchema);
