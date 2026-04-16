// backend/routes/groups.js
const router = require("express").Router();
const Group = require("../models/Group");
const GroupFile = require("../models/GroupFile");
const UserProfile = require("../models/UserProfile");
const Conversation = require("../models/Conversation");
const verifyToken = require("./verifyToken");
const {
  sendBroadcastNotification,
  sendPersonalNotification,
} = require("../utils/notificationHandler");

// Cloudinary & Multer Config
const multer = require("multer");
const { CloudinaryStorage } = require("multer-storage-cloudinary");
const cloudinary = require("../config/cloudinary").cloudinary;

// --- Config 1: Group Icons (Images Only) ---
const iconStorage = new CloudinaryStorage({
  cloudinary: cloudinary,
  params: {
    folder: "ascon_groups",
    allowed_formats: ["jpg", "png", "jpeg"],
  },
});
const uploadIcon = multer({ storage: iconStorage });

// --- Config 2: Group Documents (PDFs, Docs, etc.) ---
const docStorage = new CloudinaryStorage({
  cloudinary: cloudinary,
  params: {
    folder: "ascon_group_docs",
    resource_type: "raw",
    format: async (req, file) => {
      const ext = file.originalname.split(".").pop();
      return ext;
    },
    public_id: (req, file) =>
      file.originalname.split(".")[0] + "_" + Date.now(),
  },
});
const uploadDoc = multer({ storage: docStorage });

// Helper to safely check if a user is an admin
const isUserAdmin = (group, userId) => {
  if (!group || !group.admins) return false;
  return group.admins.some(
    (adminId) => adminId.toString() === userId.toString(),
  );
};

// ==========================================
// 1. GET GROUP INFO
// ==========================================
router.get("/:groupId/info", verifyToken, async (req, res) => {
  try {
    const group = await Group.findById(req.params.groupId).lean();
    if (!group) return res.status(404).json({ message: "Group not found" });

    const memberProfiles = await UserProfile.find({
      userId: { $in: group.members },
    }).select("userId fullName profilePicture jobTitle alumniId");

    const enrichedMembers = memberProfiles.map((p) => ({
      _id: p.userId,
      fullName: p.fullName,
      profilePicture: p.profilePicture,
      jobTitle: p.jobTitle,
      alumniId: p.alumniId,
      isAdmin: isUserAdmin(group, p.userId),
    }));

    res.json({
      success: true,
      data: {
        ...group,
        members: enrichedMembers,
        admins: group.admins || [],
        isCurrentUserAdmin: isUserAdmin(group, req.user._id),
      },
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ==========================================
// 2. UPDATE GROUP ICON
// ==========================================
router.put(
  "/:groupId/icon",
  verifyToken,
  uploadIcon.single("icon"),
  async (req, res) => {
    try {
      const group = await Group.findById(req.params.groupId);
      if (!group) return res.status(404).json({ message: "Group not found" });

      if (!isUserAdmin(group, req.user._id)) {
        return res
          .status(403)
          .json({ message: "Only Admins can change the icon." });
      }

      if (req.file) {
        group.icon = req.file.path;
        await group.save();
        res.json({
          success: true,
          message: "Group icon updated!",
          icon: group.icon,
        });
      } else {
        res.status(400).json({ message: "No image uploaded." });
      }
    } catch (err) {
      res.status(500).json({ message: err.message });
    }
  },
);

// ==========================================
// 3. DOCUMENT ROUTES
// ==========================================

// Upload Document
router.post(
  "/:groupId/documents",
  verifyToken,
  uploadDoc.single("file"),
  async (req, res) => {
    try {
      if (!req.file)
        return res.status(400).json({ message: "No file uploaded" });

      const newFile = new GroupFile({
        groupId: req.params.groupId,
        uploader: req.user._id,
        fileName: req.file.originalname,
        fileUrl: req.file.path,
        fileType: req.file.mimetype,
        size: req.file.size,
      });

      await newFile.save();

      res.json({
        success: true,
        message: "File uploaded successfully",
        data: newFile,
      });
    } catch (err) {
      console.error("Upload Error:", err);
      res.status(500).json({ message: "Upload failed: " + err.message });
    }
  },
);

// Get Documents
router.get("/:groupId/documents", verifyToken, async (req, res) => {
  try {
    const files = await GroupFile.find({ groupId: req.params.groupId })
      .populate("uploader", "email _id") // ✅ Get ID to check permission
      .sort({ createdAt: -1 });

    res.json({ success: true, data: files });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ✅ DELETE DOCUMENT
router.delete("/:groupId/documents/:docId", verifyToken, async (req, res) => {
  try {
    const file = await GroupFile.findById(req.params.docId);
    if (!file) return res.status(404).json({ message: "File not found" });

    const group = await Group.findById(req.params.groupId);

    // Permission Check: Uploader OR Group Admin
    const isUploader = file.uploader._id.toString() === req.user._id;
    const isAdmin = isUserAdmin(group, req.user._id);

    if (!isUploader && !isAdmin) {
      return res
        .status(403)
        .json({ message: "Unauthorized to delete this file." });
    }

    await GroupFile.findByIdAndDelete(req.params.docId);

    // Note: To delete from Cloudinary, we'd need the public_id stored in the model.
    // For now, removing from DB hides it from the app.

    res.json({ success: true, message: "File deleted successfully" });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ==========================================
// 4. EXISTING GROUP LOGIC
// ==========================================

// Get My Groups
router.get("/my-groups", verifyToken, async (req, res) => {
  try {
    const groups = await Group.find({ members: req.user._id })
      .select("name type icon members")
      .lean();
    const formattedGroups = groups.map((g) => ({
      _id: g._id,
      name: g.name,
      type: g.type,
      icon: g.icon,
      memberCount: g.members.length,
    }));
    res.json({ success: true, data: formattedGroups });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Toggle Admin
router.put("/:groupId/toggle-admin", verifyToken, async (req, res) => {
  try {
    const { targetUserId } = req.body;
    const group = await Group.findById(req.params.groupId);
    if (!group) return res.status(404).json({ message: "Group not found" });

    const amIAdmin = isUserAdmin(group, req.user._id);
    if (!amIAdmin && (!group.admins || group.admins.length > 0)) {
      return res
        .status(403)
        .json({ message: "Only Group Admins can do this." });
    }

    if (!group.admins) group.admins = [];
    const strAdmins = group.admins.map((id) => id.toString());
    const index = strAdmins.indexOf(targetUserId);
    let isAdminNow = false;

    if (index === -1) {
      group.admins.push(targetUserId);
      isAdminNow = true;
    } else {
      const actualIndex = group.admins.findIndex(
        (id) => id.toString() === targetUserId,
      );
      if (actualIndex !== -1) group.admins.splice(actualIndex, 1);
    }

    await group.save();

    // ✅ NOTIFY USER
    try {
      const msg = isAdminNow
        ? `You are now an Admin of ${group.name}`
        : `You have been removed as Admin of ${group.name}`;

      await sendPersonalNotification(targetUserId, "Group Update", msg, {
        route: "group_info",
        id: group._id.toString(),
      });
    } catch (e) {
      console.error("Admin toggle notification failed", e);
    }

    res.json({ success: true, message: "Admin role updated successfully." });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Remove Member
router.put("/:groupId/remove-member", verifyToken, async (req, res) => {
  try {
    const { targetUserId } = req.body;
    const group = await Group.findById(req.params.groupId);
    if (!group) return res.status(404).json({ message: "Group not found" });

    if (!isUserAdmin(group, req.user._id)) {
      return res
        .status(403)
        .json({ message: "Only Group Admins can remove members." });
    }

    group.members = group.members.filter(
      (id) => id.toString() !== targetUserId,
    );
    if (group.admins)
      group.admins = group.admins.filter(
        (id) => id.toString() !== targetUserId,
      );
    await group.save();

    await Conversation.updateOne(
      { groupId: req.params.groupId },
      { $pull: { participants: targetUserId } },
    );

    if (req.io) {
      req.io.to(targetUserId).emit("removed_from_group", {
        groupId: req.params.groupId,
        groupName: group.name,
      });
    }

    // ✅ NOTIFY REMOVED USER
    try {
      await sendPersonalNotification(
        targetUserId,
        "Group Alert",
        `You have been removed from the group: ${group.name}`,
      );
    } catch (e) {
      console.error("Remove member notification failed", e);
    }

    res.json({ success: true, message: "User removed from group." });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Get Notices
router.get("/:groupId/notices", verifyToken, async (req, res) => {
  try {
    const group = await Group.findById(req.params.groupId)
      .select("notices")
      .populate("notices.postedBy", "email");
    if (!group) return res.status(404).json({ message: "Group not found" });
    const sortedNotices = group.notices.sort(
      (a, b) => b.createdAt - a.createdAt,
    );
    res.json({ success: true, data: sortedNotices });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Post Notice
router.post("/:groupId/notices", verifyToken, async (req, res) => {
  try {
    const { title, content } = req.body;
    const group = await Group.findById(req.params.groupId);
    if (!group) return res.status(404).json({ message: "Group not found" });

    if (!isUserAdmin(group, req.user._id)) {
      return res
        .status(403)
        .json({ message: "Only Group Admins can post notices." });
    }

    group.notices.push({
      title,
      content,
      postedBy: req.user._id,
      createdAt: new Date(),
    });
    await group.save();

    // ✅ NOTIFY GROUP MEMBERS (BROADCAST simulation via socket loop or similar)
    // Since `sendBroadcastNotification` sends to ALL users, we need to iterate here
    // or improve `notificationHandler` to accept a list of IDs.
    // For now, we will use `sendPersonalNotification` in a loop for the members.
    try {
      const membersToNotify = group.members.filter(
        (id) => id.toString() !== req.user._id,
      );

      // We process this asynchronously so we don't block the response
      membersToNotify.forEach(async (memberId) => {
        await sendPersonalNotification(
          memberId.toString(),
          `Notice: ${group.name}`,
          title,
          { route: "group_info", id: group._id.toString() },
        );
      });
    } catch (e) {
      console.error("Notice notification failed", e);
    }

    res.json({ success: true, message: "Notice posted successfully!" });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Delete Notice
router.delete("/:groupId/notices/:noticeId", verifyToken, async (req, res) => {
  try {
    const group = await Group.findById(req.params.groupId);
    if (!group) return res.status(404).json({ message: "Group not found" });

    const notice = group.notices.id(req.params.noticeId);
    if (!notice) return res.status(404).json({ message: "Notice not found" });

    const isPoster =
      notice.postedBy && notice.postedBy.toString() === req.user._id;
    const isAdmin = isUserAdmin(group, req.user._id);

    if (!isPoster && !isAdmin)
      return res
        .status(403)
        .json({ message: "Unauthorized to delete this notice." });

    group.notices.pull(req.params.noticeId);
    await group.save();
    res.json({ success: true, message: "Notice deleted." });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Edit Notice
router.put("/:groupId/notices/:noticeId", verifyToken, async (req, res) => {
  try {
    const { title, content } = req.body;
    const group = await Group.findById(req.params.groupId);
    if (!group) return res.status(404).json({ message: "Group not found" });

    const notice = group.notices.id(req.params.noticeId);
    if (!notice) return res.status(404).json({ message: "Notice not found" });

    const isPoster =
      notice.postedBy && notice.postedBy.toString() === req.user._id;
    const isAdmin = isUserAdmin(group, req.user._id);

    if (!isPoster && !isAdmin)
      return res
        .status(403)
        .json({ message: "Unauthorized to edit this notice." });

    if (title) notice.title = title;
    if (content) notice.content = content;
    await group.save();
    res.json({ success: true, message: "Notice updated." });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Delete Icon
router.delete("/:groupId/icon", verifyToken, async (req, res) => {
  try {
    const group = await Group.findById(req.params.groupId);
    if (!group) return res.status(404).json({ message: "Group not found" });

    if (!isUserAdmin(group, req.user._id)) {
      return res
        .status(403)
        .json({ message: "Only Admins can remove the icon." });
    }

    group.icon = "";
    await group.save();
    res.json({ success: true, message: "Group icon removed." });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
