const mongoose = require("mongoose");

const programmeSchema = new mongoose.Schema({
  title: {
    type: String,
    required: true,
    trim: true,
  },
  // ❌ REMOVED: code field
  description: {
    type: String,
    required: true,
  },
  location: {
    type: String,
    required: true,
  },
  duration: {
    type: String,
    required: true,
  },
  fee: {
    type: String,
    required: false,
    default: "Free",
  },
  image: {
    type: String,
    required: false,
    default: "",
  },
  // ✅ Array to store multiple images
  images: {
    type: [String],
    default: [],
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
});

module.exports = mongoose.model("Programme", programmeSchema);
