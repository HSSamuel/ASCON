const mongoose = require("mongoose");

const callLogSchema = new mongoose.Schema(
  {
    caller: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "UserAuth",
      required: true,
    },
    receiver: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "UserAuth",
      required: true,
    },
    channelName: {
      type: String,
      required: true,
      index: true,
    },
    // ✅ Differentiate between Voice and Video
    callType: {
      type: String,
      enum: ["voice", "video"],
      default: "voice", // Defaults to voice for backward compatibility
    },
    status: {
      type: String,
      enum: ["initiated", "ringing", "ongoing", "ended", "missed", "declined"],
      default: "initiated",
    },
    startTime: { type: Date, default: Date.now },
    endTime: { type: Date },
    duration: { type: Number, default: 0 },

    callerName: { type: String },
    callerPic: { type: String },
    receiverName: { type: String },
    receiverPic: { type: String },
  },
  { timestamps: true },
);

module.exports = mongoose.model("CallLog", callLogSchema);
