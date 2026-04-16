const Counter = require("../models/Counter");
// User model is no longer needed for the unsafe check, but kept if you need it elsewhere.
// If not used elsewhere in this file, you can remove it.
const UserAuth = require("../models/UserAuth");
const UserProfile = require("../models/UserProfile");
const crypto = require("crypto");
const logger = require("./logger");

async function generateAlumniId(year) {
  const maxAttempts = 3;
  let attempt = 0;

  // 1. Determine the Target Year
  const currentYear = new Date().getFullYear().toString();
  const targetYear = year ? year.toString() : currentYear;
  const counterId = `alumni_id_${targetYear}`;

  // 2. Standard Generation Loop
  while (attempt < maxAttempts) {
    try {
      // Atomic increment ensures no duplicates even with high concurrency
      const counter = await Counter.findByIdAndUpdate(
        counterId,
        { $inc: { seq: 1 } },
        { new: true, upsert: true, setDefaultsOnInsert: true },
      );

      const paddedNum = counter.seq.toString().padStart(4, "0");
      return `ASC/${targetYear}/${paddedNum}`; // e.g., ASC/2026/0001
    } catch (error) {
      logger.warn(
        `Error generating Alumni ID (Attempt ${attempt + 1}): ${error.message}`,
      );
      attempt++;
    }
  }

  // 3. Fallback: Use Timestamp + Random Hex to guarantee uniqueness if Counter fails
  // This prevents the system from crashing if MongoDB is momentarily glitchy
  const timestamp = Date.now().toString().slice(-6);
  const randomSuffix = crypto.randomBytes(2).toString("hex").toUpperCase();
  logger.error("🚨 ID Generation Failed 3 times. Using Fallback ID.");
  return `ASC/${targetYear}/FB-${timestamp}${randomSuffix}`;
}

module.exports = { generateAlumniId };
