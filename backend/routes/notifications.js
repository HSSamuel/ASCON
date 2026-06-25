const router = require("express").Router();
const UserAuth = require("../models/UserAuth"); // ✅ Correct Model
const Notification = require("../models/Notification");
const verify = require("./verifyToken");
const Joi = require("joi");

// ==========================================
// 1. SAVE FCM TOKEN (Optimized)
// ==========================================
router.post("/save-token", verify, async (req, res) => {
  // 1. Validate Input
  const schema = Joi.object({
    fcmToken: Joi.string().allow(null, ""), // Allow empty strings to prevent crashes
  }).unknown(true);

  const { error } = schema.validate(req.body);

  // Support both key names for compatibility, default to empty string
  const token = req.body.fcmToken || req.body.token || "";

  if (error) {
    return res
      .status(400)
      .json({ success: false, message: "Invalid data format" });
  }

  // 2. Silent Exit for Empty Tokens (Web/Simulator Safety)
  // If the app sends an empty string (common on Web), simply ignore it
  // and return success. This keeps server logs clean.
  if (!token || token.trim() === "") {
    return res
      .status(200)
      .json({ success: true, message: "Empty token ignored" });
  }

  try {
    // ✅ STEP 1: Remove the token if it already exists (prevents duplicates)
    await UserAuth.findByIdAndUpdate(req.user._id, {
      $pull: { fcmTokens: token },
    });

    // ✅ STEP 2: Push new token to the front & keep only the latest 5
    // "Cap & Slice" Strategy: Ensures one user doesn't flood the DB with tokens
    await UserAuth.findByIdAndUpdate(req.user._id, {
      $push: {
        fcmTokens: {
          $each: [token],
          $position: 0,
          $slice: 5, // Keep only the 5 most recent devices
        },
      },
    });

    res
      .status(200)
      .json({ success: true, message: "Token saved successfully" });
  } catch (err) {
    console.error("Notification Token Error:", err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// ==========================================
// 2. GET NOTIFICATIONS (Filters out Deleted)
// ==========================================
router.get("/my-notifications", verify, async (req, res) => {
  try {
    const notifications = await Notification.find({
      $or: [{ recipientId: req.user._id }, { isBroadcast: true }],
      // ✅ FILTER: Exclude notifications deleted by this user
      deletedBy: { $ne: req.user._id },
    })
      .sort({ createdAt: -1 })
      .limit(30);

    const result = notifications.map((n) => {
      // Calculate isRead state dynamically for broadcasts
      const isRead = n.isBroadcast ? n.readBy.includes(req.user._id) : n.isRead;

      return {
        ...n.toObject(),
        isRead: isRead,
      };
    });

    res.json({ success: true, data: result });
  } catch (err) {
    console.error("Fetch Notifications Error:", err);
    res
      .status(500)
      .json({ success: false, message: "Error fetching notifications" });
  }
});

// ==========================================
// 3. GET UNREAD COUNT (Smart Badge)
// ==========================================
router.get("/unread-count", verify, async (req, res) => {
  try {
    const count = await Notification.countDocuments({
      $and: [
        // 1. Must be relevant to me (Personal unread OR Broadcast unread)
        {
          $or: [
            { recipientId: req.user._id, isRead: false },
            { isBroadcast: true, readBy: { $ne: req.user._id } },
          ],
        },
        // 2. ✅ MUST NOT be deleted by me
        { deletedBy: { $ne: req.user._id } },
      ],
    });

    res.json({ success: true, count: count });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ==========================================
// 4. MARK AS READ
// ==========================================
router.put("/:id/read", verify, async (req, res) => {
  try {
    const notification = await Notification.findById(req.params.id);
    if (!notification) return res.status(404).json({ message: "Not found" });

    if (notification.isBroadcast) {
      // For broadcasts, we add user ID to the 'readBy' array
      await Notification.findByIdAndUpdate(req.params.id, {
        $addToSet: { readBy: req.user._id },
      });
    } else {
      // For personal messages, we just flip the boolean
      if (
        notification.recipientId &&
        notification.recipientId.toString() === req.user._id.toString()
      ) {
        notification.isRead = true;
        await notification.save();
      }
    }
    res.json({ success: true, message: "Marked as read" });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
