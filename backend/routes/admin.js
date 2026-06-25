const router = require("express").Router();
const mongoose = require("mongoose");
const UserAuth = require("../models/UserAuth");
const UserProfile = require("../models/UserProfile");
const UserSettings = require("../models/UserSettings");

// Related Models for Cascade Delete
const MentorshipRequest = require("../models/MentorshipRequest");
const Message = require("../models/Message");
const Notification = require("../models/Notification");
const EventRegistration = require("../models/EventRegistration");
const ProgrammeInterest = require("../models/ProgrammeInterest");

const Event = require("../models/Event");
const Programme = require("../models/Programme");
const UpdatePost = require("../models/UpdatePost");
const jwt = require("jsonwebtoken");
const Joi = require("joi");

// ✅ NEW: Enhanced Cloudinary Config for Admin Uploads
const multer = require("multer");
const { CloudinaryStorage } = require("multer-storage-cloudinary");
// We access the 'cloudinary' object attached to your config export
const cloudinary = require("../config/cloudinary").cloudinary;

// Configure Storage for Admin Content (Events/Programmes)
const adminStorage = new CloudinaryStorage({
  cloudinary: cloudinary,
  params: {
    folder: "ascon_content", // Clean separate folder
    allowed_formats: ["jpg", "png", "jpeg", "webp"], // Added WebP support
  },
});
const adminUpload = multer({ storage: adminStorage });

const {
  sendBroadcastNotification,
  sendPersonalNotification,
} = require("../utils/notificationHandler");

// ==========================================
// 🛡️ MIDDLEWARE
// ==========================================
const verifyAdmin = (req, res, next) => {
  const token = req.header("auth-token");
  if (!token) return res.status(401).json({ message: "Access Denied" });

  try {
    const verified = jwt.verify(token, process.env.JWT_SECRET);
    if (!verified.isAdmin) {
      return res.status(403).json({ message: "Admin privileges required." });
    }
    req.user = verified;
    next();
  } catch (err) {
    res.status(400).json({ message: "Invalid Token" });
  }
};

const verifyEditor = (req, res, next) => {
  const token = req.header("auth-token");
  if (!token) return res.status(401).json({ message: "Access Denied" });

  try {
    const verified = jwt.verify(token, process.env.JWT_SECRET);
    if (!verified.isAdmin)
      return res.status(403).json({ message: "Admin access required" });

    if (!verified.canEdit) {
      return res
        .status(403)
        .json({ message: "View Only: You do not have permission to edit." });
    }

    req.user = verified;
    next();
  } catch (err) {
    res.status(400).json({ message: "Invalid Token" });
  }
};

// ==========================================
// 🛡️ VALIDATION SCHEMAS
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

const programmeSchema = Joi.object({
  title: Joi.string().min(3).required(),
  description: Joi.string().min(5).required(),
  location: Joi.string().required(),
  duration: Joi.string().required(),
  fee: Joi.string().optional().allow(""),
  image: Joi.string().optional().allow(""),
});

// ==========================================
// 📊 DASHBOARD STATS
// ==========================================
router.get("/stats", verifyAdmin, async (req, res) => {
  try {
    const [
      userCount,
      eventCount,
      progCount,
      progInterestCount,
      eventRegCount,
      updatesCount,
    ] = await Promise.all([
      UserAuth.countDocuments(),
      Event.countDocuments(),
      Programme.countDocuments(),
      ProgrammeInterest.countDocuments(),
      EventRegistration.countDocuments(),
      UpdatePost.countDocuments(),
    ]);

    res.json({
      users: userCount,
      events: eventCount,
      programmes: progCount,
      totalRegistrations: progInterestCount + eventRegCount,
      updates: updatesCount,
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ==========================================
// 1. USER MANAGEMENT (Aggregated)
// ==========================================
router.get("/users", verifyAdmin, async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const search = req.query.search || "";
    const skip = (page - 1) * limit;

    let matchQuery = {};
    if (search) {
      matchQuery = {
        $or: [
          { "profile.fullName": { $regex: search, $options: "i" } },
          { email: { $regex: search, $options: "i" } },
          { "profile.alumniId": { $regex: search, $options: "i" } },
          { "profile.programmeTitle": { $regex: search, $options: "i" } },
        ],
      };
    }

    const users = await UserAuth.aggregate([
      {
        $lookup: {
          from: "userprofiles",
          localField: "_id",
          foreignField: "userId",
          as: "profile",
        },
      },
      { $unwind: "$profile" },
      {
        $lookup: {
          from: "usersettings",
          localField: "_id",
          foreignField: "userId",
          as: "settings",
        },
      },
      { $unwind: "$settings" },
      { $match: matchQuery },
      { $sort: { isAdmin: -1, createdAt: -1 } },
      { $skip: skip },
      { $limit: limit },
      {
        $project: {
          password: 0,
          "profile._id": 0,
          "settings._id": 0,
        },
      },
      {
        $addFields: {
          fullName: "$profile.fullName",
          alumniId: "$profile.alumniId",
          programmeTitle: "$profile.programmeTitle",
          yearOfAttendance: "$profile.yearOfAttendance",
          profilePicture: "$profile.profilePicture",
        },
      },
    ]);

    const totalPipeline = await UserAuth.aggregate([
      {
        $lookup: {
          from: "userprofiles",
          localField: "_id",
          foreignField: "userId",
          as: "profile",
        },
      },
      { $unwind: "$profile" },
      { $match: matchQuery },
      { $count: "total" },
    ]);
    const total = totalPipeline.length > 0 ? totalPipeline[0].total : 0;

    res.json({ users, total, page, pages: Math.ceil(total / limit) });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ✅ UPDATED: Cascade Delete is KEPT active for standard Admin use
router.delete("/users/:id", verifyEditor, async (req, res) => {
  try {
    const userId = req.params.id;

    await Promise.all([
      // 1. Core Auth & Profile
      UserAuth.findByIdAndDelete(userId),
      UserProfile.findOneAndDelete({ userId: userId }),
      UserSettings.findOneAndDelete({ userId: userId }),

      // 2. Mentorship Interactions
      MentorshipRequest.deleteMany({
        $or: [{ mentor: userId }, { mentee: userId }],
      }),

      // 3. Communications
      Notification.deleteMany({ userId: userId }),
      Message.deleteMany({ sender: userId }),

      // 4. Registrations
      EventRegistration.deleteMany({ userId: userId }),
      ProgrammeInterest.deleteMany({ userId: userId }),
    ]);

    res.json({
      message: "User and all associated records permanently deleted.",
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

router.put("/users/:id/toggle-edit", verifyEditor, async (req, res) => {
  try {
    const userAuth = await UserAuth.findById(req.params.id);
    userAuth.canEdit = !userAuth.canEdit;
    await userAuth.save();
    res.json({
      message: `Edit permission ${userAuth.canEdit ? "GRANTED" : "REVOKED"}`,
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

router.put("/users/:id/toggle-admin", verifyEditor, async (req, res) => {
  try {
    const userAuth = await UserAuth.findById(req.params.id);
    userAuth.isAdmin = !userAuth.isAdmin;
    if (!userAuth.isAdmin) userAuth.canEdit = false;
    await userAuth.save();
    res.json({
      message: `Admin Access ${userAuth.isAdmin ? "GRANTED" : "REVOKED"}`,
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

router.put("/users/:id/verify", verifyEditor, async (req, res) => {
  try {
    const userAuth = await UserAuth.findById(req.params.id);
    const userProfile = await UserProfile.findOne({ userId: req.params.id });

    if (!userAuth || !userProfile)
      return res.status(404).json({ message: "User not found" });
    if (userAuth.isVerified)
      return res.status(400).json({ message: "User is already verified." });

    if (!userProfile.alumniId) {
      const targetYear = userProfile.yearOfAttendance
        ? userProfile.yearOfAttendance.toString()
        : new Date().getFullYear().toString();
      const regex = new RegExp(`ASC/${targetYear}/`);
      const lastUser = await UserProfile.findOne({
        alumniId: { $regex: regex },
      }).sort({ _id: -1 });

      let nextNum = 1;
      if (lastUser && lastUser.alumniId) {
        const parts = lastUser.alumniId.split("/");
        const lastNum = parseInt(parts[parts.length - 1]);
        if (!isNaN(lastNum)) nextNum = lastNum + 1;
      }
      const paddedNum = nextNum.toString().padStart(4, "0");
      userProfile.alumniId = `ASC/${targetYear}/${paddedNum}`;
      if (!userProfile.yearOfAttendance)
        userProfile.yearOfAttendance = targetYear;
    }

    userAuth.isVerified = true;
    await Promise.all([userAuth.save(), userProfile.save()]);

    await sendPersonalNotification(
      userAuth._id,
      "Account Verified! 🎉",
      "Your ASCON Alumni account has been approved. You can now access your Digital ID.",
    );

    res.json({ message: "User Verified & Notified!" });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ==========================================
// 2. EVENT MANAGEMENT
// ==========================================

// ✅ UPDATED: Create Event (Multiple Images)
router.post(
  "/events",
  verifyEditor,
  adminUpload.array("images", 5), // Allow up to 5 images
  async (req, res) => {
    try {
      const { title, description, date, time, type, location } = req.body;

      // Extract Image URLs
      let imageUrls = [];
      if (req.files && req.files.length > 0) {
        imageUrls = req.files.map(file => file.path);
      } else if (req.body.image) {
        imageUrls = [req.body.image]; // Fallback
      }

      const mainImage = imageUrls.length > 0 ? imageUrls[0] : "";

      const newEvent = new Event({
        title,
        description,
        date: date ? new Date(date) : undefined,
        time,
        type: type || "News",
        image: mainImage,    // For backward compatibility with mobile app
        images: imageUrls,   // New array of images
        location,
      });
      await newEvent.save();

      await sendBroadcastNotification(
        title,
        `${description.substring(0, 60)}...`,
        { route: "event_detail", id: newEvent._id.toString() },
      );

      res.status(201).json({ message: "Event created!", event: newEvent });
    } catch (err) {
      console.error("Event Create Error:", err);
      res.status(500).json({ message: err.message });
    }
  },
);

// ✅ UPDATED: Update Event (Multiple Images)
router.put(
  "/events/:id",
  verifyEditor,
  adminUpload.array("images", 5),
  async (req, res) => {
    try {
      const updateData = { ...req.body };

      // Update images only if new files are uploaded
      if (req.files && req.files.length > 0) {
        updateData.images = req.files.map(file => file.path);
        updateData.image = updateData.images[0]; // Update fallback image
      }

      const updatedEvent = await Event.findByIdAndUpdate(
        req.params.id,
        updateData,
        { new: true },
      );
      res.json({ message: "Event updated!", event: updatedEvent });
    } catch (err) {
      res.status(500).json({ message: err.message });
    }
  },
);

router.delete("/events/:id", verifyEditor, async (req, res) => {
  try {
    await Event.findByIdAndDelete(req.params.id);
    res.json({ message: "Event deleted." });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ==========================================
// 3. PROGRAMME MANAGEMENT
// ==========================================

router.get("/programmes", async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const search = req.query.search || "";
    let query = search
      ? { $or: [{ title: { $regex: search, $options: "i" } }] }
      : {};

    const skip = (page - 1) * limit;
    const programmes = await Programme.find(query)
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit);
    const total = await Programme.countDocuments(query);

    res.json({ programmes, total, page, pages: Math.ceil(total / limit) });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

router.get("/programmes/:id", async (req, res) => {
  try {
    const programme = await Programme.findById(req.params.id);
    if (!programme)
      return res.status(404).json({ message: "Programme not found" });
    res.json({ data: programme });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

router.post(
  "/programmes",
  verifyEditor,
  adminUpload.single("image"), // ✅ Updated middleware
  async (req, res) => {
    // Validate text fields
    const { error } = programmeSchema.validate(req.body);
    if (error)
      return res.status(400).json({ message: error.details[0].message });

    try {
      const { title, description, location, duration, fee } = req.body;

      // Check duplication
      const exists = await Programme.findOne({ title });
      if (exists)
        return res.status(400).json({ message: "Programme already exists." });

      let imageUrl = "";
      if (req.file) {
        imageUrl = req.file.path; // Cloudinary URL
      }

      const newProg = new Programme({
        title,
        description,
        location,
        duration,
        fee,
        image: imageUrl, // Save image URL
      });
      await newProg.save();

      await sendBroadcastNotification(
        title,
        `${description.substring(0, 60)}...`,
        { route: "programme_detail", id: newProg._id.toString() },
      );

      res.status(201).json({ message: "Programme added!", programme: newProg });
    } catch (err) {
      res.status(500).json({ message: err.message });
    }
  },
);

router.put(
  "/programmes/:id",
  verifyEditor,
  adminUpload.single("image"), // ✅ Updated middleware
  async (req, res) => {
    const { error } = programmeSchema.validate(req.body);
    if (error)
      return res.status(400).json({ message: error.details[0].message });

    try {
      const updateData = { ...req.body };

      // ✅ Update image only if new file
      if (req.file) {
        updateData.image = req.file.path;
      }

      const updatedProg = await Programme.findByIdAndUpdate(
        req.params.id,
        updateData,
        { new: true },
      );
      res.json({ message: "Programme updated!", programme: updatedProg });
    } catch (err) {
      res.status(500).json({ message: err.message });
    }
  },
);

router.delete("/programmes/:id", verifyEditor, async (req, res) => {
  try {
    await Programme.findByIdAndDelete(req.params.id);
    res.json({ message: "Programme deleted." });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

router.put("/users/:id/fix-id", verifyEditor, async (req, res) => {
  try {
    const { year } = req.body;
    const profile = await UserProfile.findOne({ userId: req.params.id });
    if (!profile)
      return res.status(404).json({ message: "User Profile not found" });

    const targetYear = year
      ? year.toString()
      : new Date().getFullYear().toString();
    const regex = new RegExp(`ASC/${targetYear}/`);
    const lastUser = await UserProfile.findOne({
      alumniId: { $regex: regex },
    }).sort({ _id: -1 });

    let nextNum = 1;
    if (lastUser && lastUser.alumniId) {
      const parts = lastUser.alumniId.split("/");
      const lastNum = parseInt(parts[parts.length - 1]);
      if (!isNaN(lastNum)) nextNum = lastNum + 1;
    }
    const paddedNum = nextNum.toString().padStart(4, "0");

    profile.alumniId = `ASC/${targetYear}/${paddedNum}`;
    profile.yearOfAttendance = targetYear;
    await profile.save();

    res.json({ message: "ID Fixed Successfully!" });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ✅ NEW: Toggle Poll Creator Permission
router.put("/users/:id/toggle-poll-admin", verifyEditor, async (req, res) => {
  try {
    const userAuth = await UserAuth.findById(req.params.id);
    if (!userAuth) return res.status(404).json({ message: "User not found" });

    userAuth.canCreatePolls = !userAuth.canCreatePolls;
    await userAuth.save();

    res.json({
      message: `Poll Creator permission ${userAuth.canCreatePolls ? "GRANTED" : "REVOKED"}`,
      canCreatePolls: userAuth.canCreatePolls
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
