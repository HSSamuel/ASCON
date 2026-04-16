const router = require("express").Router();
const ProgrammeInterest = require("../models/ProgrammeInterest");
const Programme = require("../models/Programme");
const Joi = require("joi"); // ✅ Added Joi
const verifyToken = require("./verifyToken");
const verifyAdmin = require("./verifyAdmin");
const { sendPersonalNotification } = require("../utils/notificationHandler"); // ✅ Added

// ==========================================
// 🛡️ VALIDATION SCHEMA
// ==========================================
const interestSchema = Joi.object({
  programmeId: Joi.string().required(),
  fullName: Joi.string().min(3).required(),
  email: Joi.string().email().required(),
  phone: Joi.string().min(10).required(),
  sex: Joi.string().required(),
  addressStreet: Joi.string().required(),
  addressLine2: Joi.string().optional().allow(""),
  city: Joi.string().required(),
  state: Joi.string().required(),
  country: Joi.string().required(),
  sponsoringOrganisation: Joi.string().required(),
  department: Joi.string().optional().allow(""),
  jobTitle: Joi.string().optional().allow(""),
  userId: Joi.string().optional().allow(null, ""),
});

// @route   POST /api/programme-interest
// @desc    Register interest in a programme
router.post("/", async (req, res) => {
  // ✅ 1. Validate Input (Clean & Secure)
  const { error } = interestSchema.validate(req.body);
  if (error) return res.status(400).json({ message: error.details[0].message });

  try {
    const {
      programmeId,
      fullName,
      email,
      phone,
      sex,
      addressStreet,
      addressLine2,
      city,
      state,
      country,
      sponsoringOrganisation,
      department,
      jobTitle,
      userId,
    } = req.body;

    // 2. Get Programme Details
    const programme = await Programme.findById(programmeId);
    if (!programme)
      return res.status(404).json({ message: "Programme not found." });

    // 3. Check for duplicate (Prevent double submission today)
    const startOfToday = new Date();
    startOfToday.setHours(0, 0, 0, 0);

    const existing = await ProgrammeInterest.findOne({
      programmeId,
      email: email.toLowerCase(),
      createdAt: { $gte: startOfToday },
    });

    if (existing)
      return res
        .status(400)
        .json({ message: "You have already registered for this today." });

    // 4. Save
    const newInterest = new ProgrammeInterest({
      programmeId,
      programmeTitle: programme.title,
      fullName,
      email: email.toLowerCase(),
      phone,
      sex,
      addressStreet,
      addressLine2,
      city,
      state,
      country,
      sponsoringOrganisation,
      department,
      jobTitle,
      userId: userId || null,
    });

    await newInterest.save();

    // ✅ SEND CONFIRMATION NOTIFICATION
    if (userId) {
      try {
        await sendPersonalNotification(
          userId,
          "Application Received 🎓",
          `We have received your interest in: ${programme.title}.`,
          { route: "programme_detail", id: programmeId },
        );
      } catch (e) {
        console.error("Programme interest notification failed", e);
      }
    }

    res.status(201).json({ message: "Registration Submitted Successfully!" });
  } catch (err) {
    console.error("Registration Error:", err);
    res.status(500).json({ message: "Server error. Please try again." });
  }
});

// @route   GET /api/programme-interest
// @desc    Get all registrations (Newest first)
// ✅ SECURITY FIX: Added verifyToken and verifyAdmin
router.get("/", verifyToken, verifyAdmin, async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const skip = (page - 1) * limit;

    const interests = await ProgrammeInterest.find()
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit);

    const total = await ProgrammeInterest.countDocuments();

    res.json({
      registrations: interests,
      total,
      page,
      pages: Math.ceil(total / limit),
    });
  } catch (err) {
    console.error("Fetch Error:", err);
    res.status(500).json({ message: "Server error." });
  }
});

// @route   DELETE /api/programme-interest/:id
// @desc    Delete a registration (Admin Only)
router.delete("/:id", verifyToken, verifyAdmin, async (req, res) => {
  try {
    const deleted = await ProgrammeInterest.findByIdAndDelete(req.params.id);
    if (!deleted)
      return res.status(404).json({ message: "Registration not found" });

    res.json({ message: "Registration deleted successfully." });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
