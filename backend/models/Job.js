const mongoose = require("mongoose");

const jobSchema = new mongoose.Schema({
  title: {
    type: String,
    required: true,
    trim: true,
  },
  company: {
    type: String,
    required: true,
    trim: true,
  },
  location: {
    type: String,
    required: true,
    trim: true,
  },
  type: {
    type: String,
    enum: ["Full-time", "Part-time", "Contract", "Internship", "Remote"],
    default: "Full-time",
  },
  salary: {
    type: String,
    default: "Negotiable",
    trim: true,
  },
  description: {
    type: String,
    required: true,
  },
  // ✅ UPDATED: Accepts any text (Email or URL) without crashing
  applicationLink: {
    type: String,
    required: true,
    trim: true,
  },
  deadline: {
    type: Date,
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
});

module.exports = mongoose.model("Job", jobSchema);
