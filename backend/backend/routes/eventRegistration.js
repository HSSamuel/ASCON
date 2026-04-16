const router = require("express").Router();
const EventRegistration = require("../models/EventRegistration");
const verifyToken = require("./verifyToken");
const verifyAdmin = require("./verifyAdmin");
const Joi = require("joi");
const { sendPersonalNotification } = require("../utils/notificationHandler"); // ✅ Added

// ==========================================
// 🛡️ VALIDATION SCHEMA (UPDATED)
// ==========================================
const eventRegSchema = Joi.object({
  eventId: Joi.string().required(),
  // ✅ ADDED: Allow these fields so Joi doesn't reject them
  eventTitle: Joi.string().optional().allow(""),
  eventType: Joi.string().optional().allow(""),

  fullName: Joi.string().min(3).required(),
  email: Joi.string().email().required(),
  phone: Joi.string().min(10).required(),

  // ✅ ADDED: Profile fields sent by App
  sex: Joi.string().optional().allow(""),
  organization: Joi.string().optional().allow(""),
  jobTitle: Joi.string().optional().allow(""),
  specialRequirements: Joi.string().optional().allow(""),

  userId: Joi.string().optional().allow(null, ""),
});

// ==========================================
// 1. POST: Register for an event
// ==========================================
// @route   POST /api/event-registration
router.post("/", async (req, res) => {
  // ✅ Joi Validation
  const { error } = eventRegSchema.validate(req.body);
  if (error) {
    return res.status(400).json({
      success: false,
      message: error.details[0].message,
    });
  }

  try {
    const { eventId, email, userId, eventTitle } = req.body;
    const emailLower = email.toLowerCase().trim();

    // ✅ CHECK DUPLICATE
    const alreadyRegistered = await EventRegistration.findOne({
      eventId,
      email: emailLower,
    });

    if (alreadyRegistered) {
      return res.status(400).json({
        success: false,
        message: "You are already registered for this event.",
      });
    }

    // Prepare data
    const finalData = {
      ...req.body, // Spread all fields (sex, org, etc.)
      email: emailLower,
      userId: userId && userId.length > 5 ? userId : null,
    };

    // Save to Database
    const newReg = new EventRegistration(finalData);
    await newReg.save();

    // ✅ SEND CONFIRMATION NOTIFICATION
    if (finalData.userId) {
      try {
        await sendPersonalNotification(
          finalData.userId,
          "Registration Confirmed ✅",
          `We have received your registration for: ${eventTitle || "the event"}.`,
          { route: "event_detail", id: eventId },
        );
      } catch (e) {
        console.error("Event reg notification failed", e);
      }
    }

    res.status(201).json({
      success: true,
      message: "Registration successful! We will contact you shortly.",
    });
  } catch (err) {
    console.error("EVENT_REG_ERROR:", err);
    res.status(500).json({
      success: false,
      message: "Server Error: " + err.message,
    });
  }
});

// ==========================================
// 2. GET: View all registrations (Admin only)
// ==========================================
// @route   GET /api/event-registration
router.get("/", verifyToken, verifyAdmin, async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const skip = (page - 1) * limit;

    const regs = await EventRegistration.find()
      .populate("userId", "fullName alumniId profilePicture")
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit);

    const total = await EventRegistration.countDocuments();

    // Ensure virtuals like 'id' are included
    const formattedRegs = regs.map((reg) => reg.toJSON());

    res.json({
      success: true,
      registrations: formattedRegs,
      total,
      page,
      pages: Math.ceil(total / limit),
    });
  } catch (err) {
    console.error("GET_REGS_ERROR:", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

// ==========================================
// 3. DELETE: Remove a registration (Admin only)
// ==========================================
// @route   DELETE /api/event-registration/:id
router.delete("/:id", verifyToken, verifyAdmin, async (req, res) => {
  try {
    const deleted = await EventRegistration.findByIdAndDelete(req.params.id);
    if (!deleted) {
      return res
        .status(404)
        .json({ success: false, message: "Registration not found" });
    }

    res.json({ success: true, message: "Registration deleted successfully." });
  } catch (err) {
    console.error("DELETE_REG_ERROR:", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

module.exports = router;
