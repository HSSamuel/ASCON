const mongoose = require("mongoose");

const noticeSchema = new mongoose.Schema({
  title: { type: String, required: true },
  content: { type: String, required: true },
  postedBy: { type: mongoose.Schema.Types.ObjectId, ref: "UserAuth" },
  createdAt: { type: Date, default: Date.now },
});

const groupSchema = new mongoose.Schema({
  name: { type: String, required: true },
  description: { type: String, default: "" },
  type: {
    type: String,
    enum: ["Chapter", "Interest", "Class", "General"],
    default: "Interest",
  },
  icon: { type: String, default: "" },
  members: [{ type: mongoose.Schema.Types.ObjectId, ref: "UserAuth" }],
  admins: [{ type: mongoose.Schema.Types.ObjectId, ref: "UserAuth" }],

  // ✅ NEW: Notice Board Schema embedded
  notices: [noticeSchema],

  createdAt: { type: Date, default: Date.now },
});

module.exports = mongoose.model("Group", groupSchema);
