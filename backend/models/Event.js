const mongoose = require("mongoose");

const eventSchema = new mongoose.Schema({
  title: {
    type: String,
    required: true,
    trim: true,
  },
  description: {
    type: String,
    required: true,
  },
  date: {
    type: Date,
    required: true,
  },
  // ✅ NEW: Explicit Time Field
  time: {
    type: String, 
    trim: true,
    default: "10:00 AM", // A sensible default if omitted
  },
  location: {
    type: String,
    trim: true,
    default: "ASCON Complex, Topo-Badagry",
  },
  type: {
    type: String,
    enum: [
      "News",
      "Event",
      "Webinar",
      "Reunion",
      "Seminar",
      "Conference",
      "Workshop",
      "Symposium",
      "AGM",
      "Induction",
    ],
    default: "News",
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

eventSchema.set("toJSON", {
  virtuals: true,
  transform: (doc, ret) => {
    ret.id = ret._id;
    return ret;
  },
});

module.exports = mongoose.model("Event", eventSchema);