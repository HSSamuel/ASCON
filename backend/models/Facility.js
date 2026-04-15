const mongoose = require("mongoose");

const facilitySchema = new mongoose.Schema(
  {
    name: { type: String, required: true },
    image: { type: String, required: true }, // URL from Cloudinary
    description: { type: String },

    // ✅ ADDED: Payment URL Field
    paymentUrl: { type: String, default: "" },

    rates: [
      {
        type: { type: String, required: true }, // e.g., "Daily", "Weekend"
        naira: { type: String, required: true }, // e.g., "250,000"
        dollar: { type: String, required: true }, // e.g., "200"
      },
    ],
    isActive: { type: Boolean, default: true },
  },
  { timestamps: true }
);

module.exports = mongoose.model("Facility", facilitySchema);
