const router = require("express").Router();
const mongoose = require("mongoose");
const MentorshipRequest = require("../models/MentorshipRequest");
const UserAuth = require("../models/UserAuth");
const UserProfile = require("../models/UserProfile");
const UserSettings = require("../models/UserSettings");
const Conversation = require("../models/Conversation");
const Message = require("../models/Message");
const verifyToken = require("./verifyToken");
const { sendPersonalNotification } = require("../utils/notificationHandler");

// ==========================================
// 1. SEND A REQUEST (Mentee -> Mentor)
// ==========================================
router.post("/request", verifyToken, async (req, res) => {
  try {
    const { mentorId, pitch } = req.body;

    console.log(`[Mentorship] Request from ${req.user._id} to ${mentorId}`);

    // 1. Validate ID Format
    if (!mongoose.Types.ObjectId.isValid(mentorId)) {
      console.log("[Mentorship] Invalid Mentor ID format");
      return res.status(400).json({ message: "Invalid Mentor ID." });
    }

    // 2. Prevent Self-Mentoring
    if (mentorId === req.user._id) {
      return res.status(400).json({ message: "You cannot mentor yourself." });
    }

    // 3. Check Auth Existence (The Source of Truth)
    const mentorAuth = await UserAuth.findOne({ _id: mentorId });
    if (!mentorAuth) {
      console.log(`[Mentorship] Mentor Auth NOT found for ID: ${mentorId}`);
      return res.status(404).json({ message: "Mentor user not found." });
    }

    // 4. Fetch or Create Settings (Self-Healing)
    let mentorSettings = await UserSettings.findOne({ userId: mentorId });

    if (!mentorSettings) {
      console.log(
        `[Mentorship] Settings missing for ${mentorId}. Auto-creating...`,
      );
      mentorSettings = new UserSettings({
        userId: mentorId,
        isOpenToMentorship: true, // Default to true if missing to allow connection
        isPhoneVisible: false,
        isEmailVisible: true,
        hasSeenWelcome: true,
      });
      await mentorSettings.save();
    }

    // 5. Check Eligibility
    if (!mentorSettings.isOpenToMentorship) {
      return res.status(400).json({
        message: "This user is not currently accepting mentorship requests.",
      });
    }

    // 6. Check for Existing Requests
    const existing = await MentorshipRequest.findOne({
      mentor: mentorId,
      mentee: req.user._id,
    });

    if (existing) {
      if (existing.status === "Pending")
        return res.status(400).json({ message: "Request already pending." });
      if (existing.status === "Accepted")
        return res
          .status(400)
          .json({ message: "You are already mentoring this user." });
      if (existing.status === "Rejected")
        return res
          .status(400)
          .json({ message: "Your previous request was declined." });
    }

    // 7. Create Request
    const newRequest = new MentorshipRequest({
      mentor: mentorId,
      mentee: req.user._id,
      pitch: pitch || "I would like to request your mentorship.",
    });

    await newRequest.save();

    // 8. Notify Mentor
    try {
      await sendPersonalNotification(
        mentorId,
        "New Mentorship Request 🤝",
        "Someone has requested your mentorship. Tap to review.",
        { route: "mentorship_requests" },
      );
    } catch (e) {
      console.error("Notification failed:", e.message);
    }

    res.status(201).json(newRequest);
  } catch (err) {
    console.error("Mentorship Request Error:", err);
    res.status(500).json({ message: err.message });
  }
});

// ==========================================
// 2. RESPOND TO REQUEST (Mentor -> Mentee)
// ==========================================
router.put("/respond/:id", verifyToken, async (req, res) => {
  try {
    const { status } = req.body;
    const request = await MentorshipRequest.findById(req.params.id).populate(
      "mentee",
    );

    if (!request) return res.status(404).json({ message: "Request not found" });

    if (request.mentor.toString() !== req.user._id) {
      return res.status(403).json({ message: "Access Denied" });
    }

    request.status = status;
    await request.save();

    if (status === "Accepted") {
      let conversation = await Conversation.findOne({
        participants: { $all: [request.mentor, request.mentee._id] },
      });

      if (!conversation) {
        conversation = new Conversation({
          participants: [request.mentor, request.mentee._id],
        });
        await conversation.save();
      }

      const systemMsg = new Message({
        conversationId: conversation._id,
        sender: request.mentor,
        text: "👋 I have accepted your mentorship request! Let's connect.",
        isRead: false,
      });
      await systemMsg.save();

      conversation.lastMessage = "👋 Mentorship Accepted";
      conversation.lastMessageAt = Date.now();
      await conversation.save();

      if (req.io) {
        req.io.to(request.mentee._id.toString()).emit("new_message", {
          message: systemMsg,
          conversationId: conversation._id,
        });
      }

      await sendPersonalNotification(
        request.mentee._id.toString(),
        "Mentorship Accepted! 👋",
        "Your mentor has accepted your request. Chat now!",
        { route: "chat_screen", id: conversation._id.toString() },
      );
    } else if (status === "Rejected") {
      // ✅ NOTIFY MENTEE OF REJECTION
      await sendPersonalNotification(
        request.mentee._id.toString(),
        "Mentorship Update",
        "Your mentorship request was not accepted at this time.",
        { route: "mentorship_requests" },
      );
    }

    res.json(request);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: err.message });
  }
});

// ==========================================
// 3. GET MY DASHBOARD
// ==========================================
router.get("/dashboard", verifyToken, async (req, res) => {
  try {
    const myId = req.user._id;

    const sentRequests = await MentorshipRequest.find({ mentee: myId })
      .populate("mentor")
      .sort({ createdAt: -1 })
      .lean();

    const receivedRequests = await MentorshipRequest.find({
      mentor: myId,
      status: "Pending",
    })
      .populate("mentee")
      .sort({ createdAt: -1 })
      .lean();

    const myMentors = await MentorshipRequest.find({
      mentee: myId,
      status: "Accepted",
    })
      .populate("mentor")
      .lean();

    const myMentees = await MentorshipRequest.find({
      mentor: myId,
      status: "Accepted",
    })
      .populate("mentee")
      .lean();

    const enrichWithProfiles = async (list, field) => {
      if (!list || list.length === 0) return [];

      const ids = list
        .map((item) => (item[field] ? item[field]._id : null))
        .filter((id) => id !== null);
      const profiles = await UserProfile.find({ userId: { $in: ids } }).lean();
      const profileMap = {};
      profiles.forEach((p) => (profileMap[p.userId.toString()] = p));

      return list.map((item) => {
        if (!item[field]) return item;
        const pid = item[field]._id.toString();
        if (profileMap[pid]) {
          item[field].fullName = profileMap[pid].fullName;
          item[field].profilePicture = profileMap[pid].profilePicture;
          item[field].jobTitle = profileMap[pid].jobTitle;
        }
        return item;
      });
    };

    const sentEnriched = await enrichWithProfiles(sentRequests, "mentor");
    const receivedEnriched = await enrichWithProfiles(
      receivedRequests,
      "mentee",
    );
    const mentorsEnriched = await enrichWithProfiles(myMentors, "mentor");
    const menteesEnriched = await enrichWithProfiles(myMentees, "mentee");

    res.json({
      sent: sentEnriched,
      received: receivedEnriched,
      activeMentors: mentorsEnriched,
      activeMentees: menteesEnriched,
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ==========================================
// 4. CHECK STATUS
// ==========================================
router.get("/status/:targetUserId", verifyToken, async (req, res) => {
  try {
    const targetId = req.params.targetUserId;

    const request = await MentorshipRequest.findOne({
      $or: [
        { mentor: targetId, mentee: req.user._id },
        { mentor: req.user._id, mentee: targetId },
      ],
    });

    if (!request) return res.json({ status: "None", requestId: null });

    res.json({ status: request.status, requestId: request._id });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ==========================================
// 5. WITHDRAW (CANCEL) REQUEST
// ==========================================
router.delete("/cancel/:id", verifyToken, async (req, res) => {
  try {
    const request = await MentorshipRequest.findById(req.params.id);
    if (!request) return res.status(404).json({ message: "Request not found" });

    // Ensure only involved parties can cancel
    if (
      request.mentee.toString() !== req.user._id &&
      request.mentor.toString() !== req.user._id
    ) {
      return res.status(403).json({ message: "Access denied" });
    }

    // 1. Capture IDs before deletion
    const { mentor, mentee } = request;

    // 2. Delete the Request
    await MentorshipRequest.findByIdAndDelete(req.params.id);

    // 3. ✅ CLEANUP: Find and Delete associated Conversation
    const conversation = await Conversation.findOne({
      participants: { $all: [mentor, mentee] },
    });

    if (conversation) {
      await Conversation.findByIdAndDelete(conversation._id);
      await Message.deleteMany({ conversationId: conversation._id });
      console.log(`[Mentorship] Auto-cleaned conversation ${conversation._id}`);
    }

    res.json({ message: "Request withdrawn and chat history cleared." });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ==========================================
// 6. END MENTORSHIP
// ==========================================
router.delete("/end/:id", verifyToken, async (req, res) => {
  try {
    const request = await MentorshipRequest.findById(req.params.id);
    if (!request)
      return res.status(404).json({ message: "Mentorship not found" });

    if (
      request.mentee.toString() !== req.user._id &&
      request.mentor.toString() !== req.user._id
    ) {
      return res.status(403).json({ message: "Access denied" });
    }

    // 1. Capture IDs
    const { mentor, mentee } = request;

    // 2. Delete the Mentorship Record
    await MentorshipRequest.findByIdAndDelete(req.params.id);

    // 3. ✅ CLEANUP: Remove Conversation on End
    const conversation = await Conversation.findOne({
      participants: { $all: [mentor, mentee] },
    });

    if (conversation) {
      await Conversation.findByIdAndDelete(conversation._id);
      await Message.deleteMany({ conversationId: conversation._id });
      console.log(
        `[Mentorship] Ended & cleaned conversation ${conversation._id}`,
      );
    }

    // ✅ NOTIFY THE OTHER PARTY
    try {
      const otherPartyId = req.user._id === mentor.toString() ? mentee : mentor;
      await sendPersonalNotification(
        otherPartyId.toString(),
        "Mentorship Ended",
        "Your mentorship connection has been ended.",
      );
    } catch (e) {
      console.error("End mentorship notification failed", e);
    }

    res.json({ message: "Mentorship ended and chat history cleared." });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
