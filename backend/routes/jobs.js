const router = require("express").Router();
const Job = require("../models/Job");

// ✅ FIX: Pointing to the same folder (./) based on your previous code
const verifyToken = require("./verifyToken");
const verifyAdmin = require("./verifyAdmin");

// Ensure this path is correct too. If this file doesn't exist, it will also crash.
const { sendBroadcastNotification } = require("../utils/notificationHandler");

// @route   GET /api/jobs
// @desc    Get all jobs (Public)
router.get("/", async (req, res) => {
  try {
    const jobs = await Job.find().sort({ createdAt: -1 });
    // Return array directly for Admin Panel compatibility
    res.status(200).json(jobs);
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// @route   POST /api/jobs
// @desc    Post a new job (Admin Only)
router.post("/", verifyToken, verifyAdmin, async (req, res) => {
  try {
    const newJob = new Job(req.body);
    const savedJob = await newJob.save();

    // 🔔 Notify all users
    try {
      if (sendBroadcastNotification) {
        await sendBroadcastNotification(
          `New Opportunity: ${savedJob.title}`,
          `at ${savedJob.company}. Tap to view details.`,
          { route: "job_detail", id: savedJob._id.toString() }
        );
      }
    } catch (notifyErr) {
      console.error("Notification failed:", notifyErr);
    }

    res.status(201).json(savedJob);
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
});

// @route   PUT /api/jobs/:id
// @desc    Update a job
router.put("/:id", verifyToken, verifyAdmin, async (req, res) => {
  try {
    const updatedJob = await Job.findByIdAndUpdate(req.params.id, req.body, {
      new: true,
    });
    res.json(updatedJob);
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
});

// @route   DELETE /api/jobs/:id
// @desc    Delete a job
router.delete("/:id", verifyToken, verifyAdmin, async (req, res) => {
  try {
    await Job.findByIdAndDelete(req.params.id);
    res.json({ message: "Job deleted" });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
