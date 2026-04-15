// backend/routes/chat.js
const router = require("express").Router();
const Conversation = require("../models/Conversation");
const Message = require("../models/Message");
const UserAuth = require("../models/UserAuth");
const UserProfile = require("../models/UserProfile");
const Group = require("../models/Group");
const verify = require("./verifyToken");

const cloudinaryConfig = require("../config/cloudinary");
const cloudinary = cloudinaryConfig.cloudinary;
const multer = require("multer");
const { CloudinaryStorage } = require("multer-storage-cloudinary");
const { sendPersonalNotification } = require("../utils/notificationHandler");

// ---------------------------------------------------------
// 🛠️ SETUP FILE UPLOAD
// ---------------------------------------------------------
const storage = new CloudinaryStorage({
  cloudinary: cloudinary,
  params: async (req, file) => {
    let resourceType = "raw";
    if (file.mimetype.startsWith("image/")) resourceType = "image";
    if (
      file.originalname.match(
        /\.(pdf|doc|docx|xls|xlsx|ppt|pptx|zip|rar|txt|csv)$/i,
      )
    ) {
      resourceType = "raw";
    }

    const nameWithoutExt = file.originalname
      .replace(/\.[^/.]+$/, "")
      .replace(/[^a-zA-Z0-9]/g, "_");
    const extension = file.originalname.split(".").pop();

    let publicId = `${nameWithoutExt}-${Date.now()}`;
    if (resourceType === "raw" && extension) {
      publicId += `.${extension}`;
    }

    return {
      folder: "ascon_chat_files",
      resource_type: resourceType,
      public_id: publicId,
      format: resourceType === "raw" ? undefined : file.mimetype.split("/")[1],
    };
  },
});
const upload = multer({ storage: storage });

// ---------------------------------------------------------
// 1. CHECK UNREAD STATUS
// ---------------------------------------------------------
router.get("/unread-status", verify, async (req, res) => {
  try {
    const conversations = await Conversation.find({
      participants: req.user._id,
    }).select("_id");
    const conversationIds = conversations.map((c) => c._id);
    const hasUnread = await Message.exists({
      conversationId: { $in: conversationIds },
      sender: { $ne: req.user._id },
      isRead: false,
    });
    res.status(200).json({ hasUnread: !!hasUnread });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ---------------------------------------------------------
// 2. GET ALL CONVERSATIONS
// ---------------------------------------------------------
router.get("/", verify, async (req, res) => {
  try {
    const chats = await Conversation.find({
      participants: { $in: [req.user._id] },
      // ✅ FIX: Only return chats that have a last message.
      // Removed { isGroup: true } to prevent empty groups from auto-appearing.
      lastMessage: { $exists: true, $ne: null, $ne: "" },
    })
      .populate("groupId", "name icon")
      .sort({ updatedAt: -1 })
      .lean();

    const allParticipantIds = new Set();
    chats.forEach((chat) =>
      chat.participants.forEach((pId) => allParticipantIds.add(pId.toString())),
    );

    const profiles = await UserProfile.find({
      userId: { $in: Array.from(allParticipantIds) },
    }).lean();

    const auths = await UserAuth.find({
      _id: { $in: Array.from(allParticipantIds) },
    })
      .select("email")
      .lean();

    const profileMap = {};
    const authMap = {};

    profiles.forEach((p) => (profileMap[p.userId.toString()] = p));
    auths.forEach((a) => (authMap[a._id.toString()] = a));

    const enrichedChats = await Promise.all(
      chats.map(async (chat) => {
        if (chat.isGroup && chat.groupId) {
          chat.groupName = chat.groupId.name;
          chat.groupIcon = chat.groupId.icon;
        }

        const enrichedParticipants = chat.participants.map((pId) => {
          const idStr = pId.toString();
          const profile = profileMap[idStr];
          const auth = authMap[idStr];

          let displayName = "Unknown User";
          if (profile && profile.fullName) displayName = profile.fullName;
          else if (auth && auth.email) displayName = auth.email.split("@")[0];

          return {
            _id: idStr,
            fullName: displayName,
            profilePicture: profile ? profile.profilePicture : "",
            jobTitle: profile ? profile.jobTitle : "",
            exists: !!auth,
          };
        });

        const unreadCount = await Message.countDocuments({
          conversationId: chat._id,
          sender: { $ne: req.user._id },
          isRead: false,
        });

        return {
          ...chat,
          participants: enrichedParticipants,
          unreadCount: unreadCount,
        };
      }),
    );

    const validChats = enrichedChats.filter((chat) => chat !== null);
    res.json({ success: true, data: validChats });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ---------------------------------------------------------
// 3. START OR GET CONVERSATION (LAZY CREATION FIX)
// ---------------------------------------------------------
router.post("/start", verify, async (req, res) => {
  const { receiverId, groupId } = req.body;

  if (!receiverId && !groupId) {
    return res.status(400).json({ message: "Missing receiverId or groupId" });
  }

  try {
    let chat;
    if (groupId) {
      // Groups must theoretically exist or be created by admin
      chat = await Conversation.findOne({ groupId: groupId });
      if (!chat) {
        // Fallback: If group exists in Group DB but not Conversation DB, create it.
        const group = await Group.findById(groupId);
        if (!group) return res.status(404).json({ message: "Group not found" });

        let initialParticipants = group.members || [];
        if (!initialParticipants.some((id) => id.toString() === req.user._id))
          initialParticipants.push(req.user._id);

        chat = new Conversation({
          isGroup: true,
          groupId: groupId,
          participants: initialParticipants,
        });
        await chat.save();
      } else {
        // Ensure user is participant
        if (!chat.participants.includes(req.user._id)) {
          const group = await Group.findById(groupId).select("members");
          if (
            group &&
            group.members.some((m) => m.toString() === req.user._id)
          ) {
            chat.participants.push(req.user._id);
            await chat.save();
          } else {
            return res
              .status(403)
              .json({ message: "You are no longer a member of this group." });
          }
        }
      }
    } else {
      // 1-on-1 Chat Check
      chat = await Conversation.findOne({
        isGroup: false,
        participants: { $all: [req.user._id, receiverId], $size: 2 },
      });

      // ✅ FIX: DO NOT CREATE HERE. Return null to indicate no history.
      if (!chat) {
        return res.status(200).json({ success: true, data: null });
      }
    }

    const chatObj = chat.toObject ? chat.toObject() : chat;
    res.status(200).json({ success: true, data: chatObj });
  } catch (err) {
    console.error("Chat Start Error:", err);
    res.status(500).json({ message: err.message || "Failed to start chat" });
  }
});

// ---------------------------------------------------------
// 4. BULK DELETE MESSAGES
// ---------------------------------------------------------
router.post("/delete-multiple", verify, async (req, res) => {
  try {
    const { messageIds, deleteForEveryone } = req.body;
    const firstMsg = await Message.findById(messageIds[0]);
    if (!firstMsg)
      return res.status(404).json({ message: "Message not found" });

    const conversation = await Conversation.findById(firstMsg.conversationId);
    let isAdmin = false;

    if (conversation && conversation.groupId) {
      const group = await Group.findById(conversation.groupId);
      if (group && group.admins.includes(req.user._id)) {
        isAdmin = true;
      }
    }

    if (deleteForEveryone) {
      const query = { _id: { $in: messageIds } };
      if (!isAdmin) query.sender = req.user._id;

      await Message.deleteMany(query);

      const latestMsg = await Message.findOne({
        conversationId: firstMsg.conversationId,
      }).sort({ createdAt: -1 });

      let newPreview = "";
      let newSender = null;
      let newTime = conversation.createdAt;

      if (latestMsg) {
        if (latestMsg.type === "image") newPreview = "📷 Image";
        else if (latestMsg.type === "audio") newPreview = "🎤 Voice Note";
        else if (latestMsg.type === "file") newPreview = "📎 Document";
        else newPreview = latestMsg.text;

        newSender = latestMsg.sender;
        newTime = latestMsg.createdAt;
      }

      await Conversation.findByIdAndUpdate(firstMsg.conversationId, {
        lastMessage: newPreview,
        lastMessageSender: newSender,
        lastMessageAt: newTime,
      });

      _emitDeleteEvent(
        req,
        firstMsg.conversationId,
        messageIds,
        true,
        conversation,
      );
    } else {
      await Message.updateMany(
        { _id: { $in: messageIds } },
        { $addToSet: { deletedFor: req.user._id } },
      );
      _emitDeleteEvent(
        req,
        firstMsg.conversationId,
        messageIds,
        false,
        conversation,
      );
    }
    res.status(200).json({ success: true });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

async function _emitDeleteEvent(
  req,
  conversationId,
  messageIds,
  isHardDelete,
  conversation,
) {
  if (!conversation) return;
  if (conversation.isGroup && conversation.groupId) {
    req.io.to(conversation.groupId.toString()).emit("messages_deleted_bulk", {
      conversationId,
      messageIds,
      isHardDelete,
    });
  } else {
    conversation.participants.forEach((userId) => {
      if (isHardDelete || userId.toString() === req.user._id) {
        req.io.to(userId.toString()).emit("messages_deleted_bulk", {
          conversationId,
          messageIds,
          isHardDelete,
        });
      }
    });
  }
}

// ---------------------------------------------------------
// 5. GET MESSAGES
// ---------------------------------------------------------
router.get("/:conversationId", verify, async (req, res) => {
  try {
    const conversation = await Conversation.findOne({
      _id: req.params.conversationId,
      participants: req.user._id,
    });
    if (!conversation)
      return res
        .status(403)
        .json({ message: "Access denied or conversation not found." });

    const { beforeId } = req.query;
    const limit = 20;
    let query = {
      conversationId: req.params.conversationId,
      deletedFor: { $ne: req.user._id },
    };
    if (beforeId) query._id = { $lt: beforeId };

    const messages = await Message.find(query)
      .populate("replyTo", "text sender type fileUrl")
      .populate("replyTo.sender", "email")
      .sort({ createdAt: -1 })
      .limit(limit)
      .lean();

    const userIds = new Set();
    messages.forEach((m) => {
      userIds.add(m.sender.toString());
      if (m.replyTo && m.replyTo.sender)
        userIds.add(m.replyTo.sender._id.toString());
    });

    const profiles = await UserProfile.find({
      userId: { $in: Array.from(userIds) },
    }).lean();
    const profileMap = {};
    profiles.forEach((p) => (profileMap[p.userId.toString()] = p));

    const enrichedMessages = messages.map((msg) => {
      const senderProfile = profileMap[msg.sender.toString()];
      const senderName = senderProfile
        ? senderProfile.fullName
        : "Unknown User";
      const senderPic = senderProfile ? senderProfile.profilePicture : "";

      if (msg.replyTo && msg.replyTo.sender) {
        const replyProfile = profileMap[msg.replyTo.sender._id.toString()];
        msg.replyTo.sender.fullName = replyProfile
          ? replyProfile.fullName
          : "User";
      }

      return {
        ...msg,
        sender: {
          _id: msg.sender,
          fullName: senderName,
          profilePicture: senderPic,
        },
      };
    });

    res.status(200).json({ success: true, data: enrichedMessages.reverse() });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ---------------------------------------------------------
// 6. SEND MESSAGE (LAZY CREATION UPDATE)
// ---------------------------------------------------------
// ✅ We place this BEFORE the generic /:id route so it doesn't get confused
router.post(
  "/message/send",
  verify,
  upload.single("file"),
  async (req, res) => {
    try {
      const { text, type, replyToId, pollId, conversationId, recipientId } =
        req.body;
      let fileUrl = "",
        fileName = "";
      if (req.file) {
        fileUrl = req.file.path;
        fileName = req.file.originalname;
      }

      let activeConvId = conversationId;
      let conversation = null;

      // ✅ LAZY CREATION LOGIC
      // If we don't have a valid conversation ID yet...
      if (
        !activeConvId ||
        activeConvId === "null" ||
        activeConvId === "undefined"
      ) {
        if (!recipientId)
          return res
            .status(400)
            .json({ message: "Recipient ID required to start new chat" });

        // Double-check if one exists (race condition check)
        conversation = await Conversation.findOne({
          isGroup: false,
          participants: { $all: [req.user._id, recipientId], $size: 2 },
        });

        if (!conversation) {
          // 🆕 CREATE IT NOW (because user is actually sending a message)
          conversation = new Conversation({
            participants: [req.user._id, recipientId],
            lastMessage:
              text || (type === "image" ? "Sent an image" : "Sent a file"),
            updatedAt: Date.now(),
          });
          await conversation.save();
        }
        activeConvId = conversation._id;
      } else {
        // Standard flow: Use existing ID
        conversation = await Conversation.findById(activeConvId);
        if (!conversation)
          return res.status(404).json({ message: "Conversation not found" });
      }

      // ... (Standard Group Logic and Message Saving) ...
      if (conversation.isGroup && conversation.groupId) {
        const group = await Group.findById(conversation.groupId);
        if (
          group &&
          !group.members.some((m) => m.toString() === req.user._id)
        ) {
          return res.status(403).json({
            message: "You are no longer a participant of this group.",
          });
        }
        if (
          group &&
          group.members.length !== conversation.participants.length
        ) {
          conversation.participants = group.members;
          await conversation.save();
        }
      }

      const newMessage = new Message({
        conversationId: activeConvId,
        sender: req.user._id,
        text: text || "",
        type: type || "text",
        fileUrl: fileUrl,
        fileName: fileName,
        replyTo: replyToId || null,
        pollId: pollId || null,
        isRead: false,
      });

      const savedMessage = await newMessage.save();

      // Profile Enrichment
      const senderProfile = await UserProfile.findOne({ userId: req.user._id });
      const senderName = senderProfile
        ? senderProfile.fullName
        : "Unknown User";
      const senderPic = senderProfile ? senderProfile.profilePicture : "";

      const messageObj = savedMessage.toObject();
      messageObj.sender = {
        _id: req.user._id,
        fullName: senderName,
        profilePicture: senderPic,
      };

      let lastMessagePreview = text;
      if (type === "image") lastMessagePreview = "📷 Sent an image";
      if (type === "audio") lastMessagePreview = "🎤 Sent a voice note";
      if (type === "file") lastMessagePreview = "📎 Sent a document";
      if (type === "poll") lastMessagePreview = "📊 Created a poll";

      await Conversation.findByIdAndUpdate(activeConvId, {
        lastMessage: lastMessagePreview,
        lastMessageSender: req.user._id,
        lastMessageAt: Date.now(),
      });

      // Socket Emission
      if (conversation.isGroup && conversation.groupId) {
        req.io.to(conversation.groupId.toString()).emit("new_message", {
          message: messageObj,
          conversationId: conversation._id,
        });

        conversation.participants.forEach(async (participantId) => {
          if (participantId.toString() === req.user._id) return;
          try {
            await sendPersonalNotification(
              participantId.toString(),
              conversation.groupName || "Group Chat",
              `${senderName}: ${lastMessagePreview}`,
              {
                type: "chat_message",
                conversationId: conversation._id.toString(),
                senderId: req.user._id.toString(),
                isGroup: "true",
                groupId: conversation.groupId.toString(),
                groupName: conversation.groupName,
                senderName: senderName,
              },
            );
          } catch (e) {}
        });
      } else {
        conversation.participants.forEach(async (participantId) => {
          if (participantId.toString() === req.user._id) return;
          req.io.to(participantId.toString()).emit("new_message", {
            message: messageObj,
            conversationId: conversation._id,
          });
          try {
            await sendPersonalNotification(
              participantId.toString(),
              senderName,
              lastMessagePreview,
              {
                type: "chat_message",
                conversationId: conversation._id.toString(),
                senderId: req.user._id.toString(),
                isGroup: "false",
                senderName: senderName,
                senderProfilePic: senderPic,
              },
            );
          } catch (e) {}
        });
      }

      // ✅ Return the NEW conversation ID so the frontend can update its state
      res.status(200).json({ ...messageObj, newConversationId: activeConvId });
    } catch (err) {
      console.error("Send Message Error:", err);
      res.status(500).json({ message: err.message });
    }
  },
);

// ---------------------------------------------------------
// 7. READ RECEIPT
// ---------------------------------------------------------
router.put("/read/:conversationId", verify, async (req, res) => {
  try {
    await Message.updateMany(
      {
        conversationId: req.params.conversationId,
        sender: { $ne: req.user._id },
        isRead: false,
      },
      { $set: { isRead: true } },
    );
    const conversation = await Conversation.findById(req.params.conversationId);
    if (!conversation) return res.status(200).json({ success: true });

    if (conversation.isGroup && conversation.groupId) {
      req.io.to(conversation.groupId.toString()).emit("messages_read", {
        conversationId: req.params.conversationId,
        readerId: req.user._id,
      });
    } else {
      conversation.participants.forEach((pId) => {
        if (pId.toString() !== req.user._id)
          req.io.to(pId.toString()).emit("messages_read", {
            conversationId: req.params.conversationId,
            readerId: req.user._id,
          });
      });
    }
    res.status(200).json({ success: true });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ---------------------------------------------------------
// 8. DELETE CONVERSATION
// ---------------------------------------------------------
router.delete("/conversation/:conversationId", verify, async (req, res) => {
  try {
    const conversation = await Conversation.findByIdAndDelete(
      req.params.conversationId,
    );
    if (conversation)
      await Message.deleteMany({ conversationId: req.params.conversationId });
    res.status(200).json({ message: "Deleted." });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ---------------------------------------------------------
// 9. EDIT & DELETE MESSAGE
// ---------------------------------------------------------
router.put("/message/:id", verify, async (req, res) => {
  try {
    const msg = await Message.findById(req.params.id);
    if (!msg) return res.status(404).json({ message: "Not found" });
    if (msg.sender.toString() !== req.user._id)
      return res.status(403).json({ message: "Unauthorized" });
    msg.text = req.body.text;
    msg.isEdited = true;
    await msg.save();
    res.status(200).json(msg);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

router.delete("/message/:id", verify, async (req, res) => {
  try {
    const msg = await Message.findById(req.params.id);
    if (!msg) return res.status(404).json({ message: "Not found" });

    await Message.findByIdAndDelete(req.params.id);

    const conversation = await Conversation.findById(msg.conversationId);
    _emitDeleteEvent(req, msg.conversationId, [msg._id], true, conversation);
    res.status(200).json({ message: "Deleted" });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
