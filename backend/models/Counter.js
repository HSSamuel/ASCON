const mongoose = require("mongoose");

const counterSchema = new mongoose.Schema({
  _id: { type: String, required: true }, // e.g. "alumni_id_2026"
  seq: { type: Number, default: 0 }, // The count (1, 2, 3...)
});

module.exports = mongoose.model("Counter", counterSchema);
