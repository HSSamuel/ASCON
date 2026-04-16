const router = require("express").Router();
const DocumentRequest = require("../models/DocumentRequest");
const verifyToken = require("./verifyToken");
const verifyAdmin = require("./verifyAdmin");
const { sendPersonalNotification } = require("../utils/notificationHandler");

// 1. Create a Request (User)
router.post("/", verifyToken, async (req, res) => {
  try {
    const { type, details } = req.body;
    const newDoc = new DocumentRequest({
      user: req.user._id,
      type,
      details,
    });
    const savedDoc = await newDoc.save();
    res.status(201).json(savedDoc);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// 2. Get My Requests (User)
router.get("/my", verifyToken, async (req, res) => {
  try {
    const docs = await DocumentRequest.find({ user: req.user._id }).sort({
      createdAt: -1,
    });
    res.json(docs);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// 3. Get All Requests (Admin)
router.get("/all", verifyToken, verifyAdmin, async (req, res) => {
  try {
    const docs = await DocumentRequest.find()
      .populate("user", "fullName email alumniId yearOfAttendance")
      .sort({ createdAt: -1 });
    res.json(docs);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// 4. Update Status (Admin)
router.put("/:id", verifyToken, verifyAdmin, async (req, res) => {
  try {
    const { status, adminComment } = req.body;
    const doc = await DocumentRequest.findByIdAndUpdate(
      req.params.id,
      { status, adminComment },
      { new: true },
    );

    if (doc) {
      await sendPersonalNotification(
        doc.user,
        "Document Update 📄",
        `Your ${doc.type} request is now ${status}.`,
      );
    }

    res.json(doc);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ✅ 5. DELETE REQUEST (User) - NEW ROUTE
router.delete("/:id", verifyToken, async (req, res) => {
  try {
    // Find the doc and ensure it belongs to the requesting user
    const doc = await DocumentRequest.findOne({
      _id: req.params.id,
      user: req.user._id,
    });

    if (!doc) {
      return res
        .status(404)
        .json({ message: "Request not found or access denied" });
    }

    // Delete it
    await DocumentRequest.findByIdAndDelete(req.params.id);

    res.json({ message: "Request deleted successfully" });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
