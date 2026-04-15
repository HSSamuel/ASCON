const router = require("express").Router();
const CallLog = require("../models/CallLog");
const UserProfile = require("../models/UserProfile");
const verify = require("./verifyToken");

// ==========================================
// 1. GET MY CALL HISTORY
// ==========================================
router.get("/", verify, async (req, res) => {
  try {
    const userId = req.user._id;

    const logs = await CallLog.find({
      $or: [{ caller: userId }, { receiver: userId }],
    })
      .sort({ createdAt: -1 })
      .limit(50) // Limit to last 50 calls
      .lean();

    // Enrich with current profile data (in case names/pics changed)
    const enrichedLogs = await Promise.all(
      logs.map(async (log) => {
        const isCaller = log.caller.toString() === userId.toString();
        const otherId = isCaller ? log.receiver : log.caller;

        const profile = await UserProfile.findOne({ userId: otherId }).select(
          "fullName profilePicture",
        );

        return {
          _id: log._id,
          type: _determineType(log, isCaller),
          callType: log.callType || "voice",
          remoteId: otherId,
          remoteName: profile ? profile.fullName : "Unknown User",
          remotePic: profile ? profile.profilePicture : "",
          status: log.status,
          duration: log.duration,
          createdAt: log.createdAt,
        };
      }),
    );

    res.json({ success: true, data: enrichedLogs });
  } catch (err) {
    console.error("Call Logs Error:", err);
    res.status(500).json({ success: false, message: "Failed to fetch logs" });
  }
});

// Helper to map DB status to UI type
function _determineType(log, isCaller) {
  if (log.status === "missed") return "missed";
  if (log.status === "declined") return isCaller ? "dialed" : "missed";
  if (isCaller) return "dialed";
  return "received";
}

// ==========================================
// 2. DELETE CALL LOG
// ==========================================
router.delete("/:id", verify, async (req, res) => {
  try {
    await CallLog.findOneAndDelete({
      _id: req.params.id,
      $or: [{ caller: req.user._id }, { receiver: req.user._id }],
    });
    res.json({ success: true, message: "Deleted" });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
