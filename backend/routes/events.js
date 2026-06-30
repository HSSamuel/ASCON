const router = require("express").Router();
const Event = require("../models/Event");
const Joi = require("joi");
const { sendBroadcastNotification } = require("../utils/notificationHandler");
const verifyToken = require("./verifyToken");
const verifyAdmin = require("./verifyAdmin");

// ✅ NEW: Image Upload Dependencies
const multer = require("multer");
const { CloudinaryStorage } = require("multer-storage-cloudinary");
const cloudinary = require("../config/cloudinary").cloudinary;

// ✅ Configure Cloudinary Storage
const storage = new CloudinaryStorage({
  cloudinary: cloudinary,
  params: {
    folder: "ascon_events",
    allowed_formats: ["jpg", "png", "jpeg", "webp"],
  },
});

const parser = multer({ storage: storage });

// ==========================================
// 🛡️ VALIDATION SCHEMA
// ==========================================
const eventSchema = Joi.object({
  title: Joi.string().min(5).required(),
  description: Joi.string().min(10).required(),
  date: Joi.date().optional(),
  time: Joi.string().optional().allow(""),
  location: Joi.string().optional().allow(""),
  type: Joi.string()
    .valid(
      "News",
      "Event",
      "Reunion",
      "Webinar",
      "Seminar",
      "Conference",
      "Workshop",
      "Symposium",
      "AGM",
      "Induction",
    )
    .default("News"),
  image: Joi.string().optional().allow(""),
});

// @route   GET /api/events
// @desc    Get all events
router.get("/", async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const skip = (page - 1) * limit;

    const events = await Event.find()
      .sort({ date: -1 })
      .skip(skip)
      .limit(limit);

    const total = await Event.countDocuments();

    res.json({
      events,
      total,
      page,
      pages: Math.ceil(total / limit),
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// @route   POST /api/events
// @desc    Create a new Event (Supports Multiple File Upload)
router.post(
  "/",
  verifyToken,
  verifyAdmin,
  parser.array("images", 5), // ✅ FIXED: Expects an array named "images"
  async (req, res) => {
    const { error } = eventSchema.validate(req.body);
    if (error)
      return res.status(400).json({ message: error.details[0].message });

    try {
      // ✅ Extract Image URLs
      let imageUrls = [];
      if (req.files && req.files.length > 0) {
        imageUrls = req.files.map((file) => file.path);
      } else if (req.body.image) {
        imageUrls = [req.body.image]; // Fallback
      }

      const mainImage = imageUrls.length > 0 ? imageUrls[0] : "";

      const event = new Event({
        title: req.body.title,
        description: req.body.description,
        date: req.body.date,
        time: req.body.time,
        location: req.body.location,
        type: req.body.type,
        image: mainImage,
        images: imageUrls,
      });

      const savedEvent = await event.save();

      try {
        await sendBroadcastNotification(
          savedEvent.title,
          `${savedEvent.description.substring(0, 50)}...`,
          { route: "event_detail", id: savedEvent._id.toString(), type: "event" }, // Added type: "event"
  mainImage // ✅ Pass the uploaded image URL here
);
      } catch (notifyErr) {
        console.error("Notification failed:", notifyErr);
      }

      res.status(201).json(savedEvent);
    } catch (err) {
      res.status(400).json({ message: err.message });
    }
  },
);

// @route   PUT /api/events/:id
// @desc    Update an existing Event (Supports Multiple File Upload)
router.put(
  "/:id",
  verifyToken,
  verifyAdmin,
  parser.array("images", 5), // ✅ FIXED: Expects an array named "images"
  async (req, res) => {
    const { error } = eventSchema.validate(req.body);
    if (error)
      return res.status(400).json({ message: error.details[0].message });

    try {
      const updateData = {
        title: req.body.title,
        description: req.body.description,
        date: req.body.date,
        time: req.body.time,
        location: req.body.location,
        type: req.body.type,
      };

      // ✅ Update images if new files are uploaded
      if (req.files && req.files.length > 0) {
        updateData.images = req.files.map((file) => file.path);
        updateData.image = updateData.images[0];
      } else if (req.body.image) {
        updateData.image = req.body.image;
      }

      const updatedEvent = await Event.findByIdAndUpdate(
        req.params.id,
        updateData,
        { new: true },
      );

      if (!updatedEvent)
        return res.status(404).json({ message: "Event not found" });
      res.json(updatedEvent);
    } catch (err) {
      res.status(500).json({ message: err.message });
    }
  },
);

// @route   DELETE /api/events/:id
// @desc    Delete an event
router.delete("/:id", verifyToken, verifyAdmin, async (req, res) => {
  try {
    const removedEvent = await Event.findByIdAndDelete(req.params.id);
    if (!removedEvent) {
      return res.status(404).json({ message: "Event not found" });
    }
    res.json({ message: "Event deleted successfully" });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// @route   GET /api/events/:id
// @desc    Get single event
router.get("/:id", async (req, res) => {
  try {
    const event = await Event.findById(req.params.id);
    if (!event) return res.status(404).json({ message: "Event not found" });
    res.json({ data: event });
  } catch (err) {
    res.status(500).json({ message: "Server error" });
  }
});

module.exports = router;
