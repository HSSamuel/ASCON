const { Server } = require("socket.io");
const { createAdapter } = require("@socket.io/redis-adapter");
const { createClient } = require("redis");
const jwt = require("jsonwebtoken");
const mongoose = require("mongoose");
const UserAuth = require("../models/UserAuth");
const UserProfile = require("../models/UserProfile");
const Group = require("../models/Group");
const Message = require("../models/Message");
const CallLog = require("../models/CallLog");
const logger = require("../utils/logger");

let io;
let redisClient;
const onlineUsersMemory = new Map();
const disconnectTimers = new Map();

// ✅ COST SAFEGUARD TIMERS
const activeCallTimers = new Map();
const MAX_RING_TIME = 60 * 1000; // 60 Seconds
const MAX_CALL_DURATION = 45 * 60 * 1000; // 45 Minutes (Kept as fallback/reference if needed elsewhere)

const addSocketToUser = async (userId, socketId) => {
  if (redisClient && redisClient.isOpen) {
    await redisClient.sAdd(`online_users:${userId}`, socketId);
    await redisClient.expire(`online_users:${userId}`, 86400);
    return await redisClient.sCard(`online_users:${userId}`);
  } else {
    if (!onlineUsersMemory.has(userId))
      onlineUsersMemory.set(userId, new Set());
    onlineUsersMemory.get(userId).add(socketId);
    return onlineUsersMemory.get(userId).size;
  }
};

const removeSocketFromUser = async (userId, socketId) => {
  if (redisClient && redisClient.isOpen) {
    await redisClient.sRem(`online_users:${userId}`, socketId);
    return await redisClient.sCard(`online_users:${userId}`);
  } else {
    if (onlineUsersMemory.has(userId)) {
      onlineUsersMemory.get(userId).delete(socketId);
      return onlineUsersMemory.get(userId).size;
    }
    return 0;
  }
};

const getSocketCount = async (userId) => {
  if (redisClient && redisClient.isOpen) {
    return await redisClient.sCard(`online_users:${userId}`);
  } else {
    return onlineUsersMemory.has(userId)
      ? onlineUsersMemory.get(userId).size
      : 0;
  }
};

const initializeSocket = async (server) => {
  const ioConfig = {
    cors: {
      origin: "*",
      methods: ["GET", "POST"],
      credentials: true,
    },
    pingTimeout: 60000, // 60 seconds: Wait much longer before assuming the mobile client is dead
    pingInterval: 25000, // 25 seconds: Send heartbeats less frequently to save battery
  };

  io = new Server(server, ioConfig);

  if (process.env.USE_REDIS === "true") {
    logger.info("🔌 Redis Enabled. Attempting to connect...");
    try {
      const pubClient = createClient({
        url: process.env.REDIS_URL || "redis://localhost:6379",
      });
      const subClient = pubClient.duplicate();

      pubClient.on("error", (err) =>
        logger.warn(`Redis Pub Error: ${err.message}`),
      );
      subClient.on("error", (err) =>
        logger.warn(`Redis Sub Error: ${err.message}`),
      );

      await Promise.all([pubClient.connect(), subClient.connect()]);

      io.adapter(createAdapter(pubClient, subClient));
      redisClient = pubClient;

      logger.info("✅ Redis Connected & Adapter Configured");
    } catch (err) {
      logger.warn("⚠️ Redis Connection Failed (Using Memory): " + err.message);
    }
  }

  io.use(async (socket, next) => {
    try {
      const token =
        socket.handshake.auth?.token ||
        socket.handshake.headers?.["auth-token"] ||
        socket.handshake.headers?.authorization?.split(" ")[1];

      if (!token) {
        return next(new Error("Authentication error: Token required"));
      }

      // Verify token
      const decoded = jwt.verify(token, process.env.JWT_SECRET);

      // ✅ ENHANCEMENT: Verify user actually exists in the database
      const user = await UserAuth.findById(decoded._id).select("_id");
      if (!user) {
        logger.warn(
          `Blocked socket connection for deleted/invalid user: ${decoded._id}`,
        );
        return next(new Error("Authentication error: User no longer exists"));
      }

      socket.userId = decoded._id;
      return next();
    } catch (err) {
      logger.error(`Socket Auth Error: ${err.message}`);
      return next(new Error("Authentication error: Invalid or Expired Token"));
    }
  });

  io.on("connection", async (socket) => {
    const userId = socket.userId;
    logger.info(`🔌 Socket Connected: ${socket.id} (User: ${userId})`);

    socket.join(userId);
    try {
      const userGroups = await Group.find({ members: userId }).select("_id");
      if (userGroups && userGroups.length > 0) {
        userGroups.forEach((group) => socket.join(group._id.toString()));
      }
    } catch (err) {
      logger.error(`Error joining group rooms: ${err.message}`);
    }

    await handleConnection(socket, userId);

    socket.on("join_room", (room) => socket.join(room));
    socket.on("leave_room", (room) => socket.leave(room));

    socket.on("user_connected", async (uid) => {
      if (uid === userId) {
        await handleConnection(socket, userId);
      }
    });

    socket.on("check_user_status", async ({ userId: targetId }) => {
      try {
        const count = await getSocketCount(targetId);
        const isOnline = count > 0;

        let lastSeen = new Date();
        if (!isOnline) {
          const userAuth = await UserAuth.findById(targetId).select("lastSeen");
          if (userAuth) lastSeen = userAuth.lastSeen;
        }

        socket.emit("user_status_update", {
          userId: targetId,
          isOnline: isOnline,
          lastSeen: lastSeen,
        });
      } catch (e) {
        logger.error(`Check Status Error: ${e.message}`);
      }
    });

    socket.on(
      "mark_messages_read",
      async ({ chatId, messageIds, userId: readerId }) => {
        try {
          if (!messageIds || messageIds.length === 0) return;
          await Message.updateMany(
            { _id: { $in: messageIds }, conversationId: chatId },
            { $set: { status: "read", isRead: true } },
          );
          socket
            .to(chatId)
            .emit("messages_read_update", { chatId, messageIds, readerId });
        } catch (error) {
          logger.error("❌ Error marking messages read:", error);
        }
      },
    );

    socket.on("message_delivered", async ({ messageId, chatId }) => {
      try {
        const msg = await Message.findByIdAndUpdate(
          messageId,
          { status: "delivered" },
          { new: true },
        );
        if (msg) {
          io.to(chatId).emit("message_status_update", {
            messageId,
            status: "delivered",
            chatId,
          });
        }
      } catch (error) {
        logger.error("Delivered status error:", error);
      }
    });

    // ==========================================
    // --- REAL-TIME TYPING INDICATORS ---
    // ==========================================

    socket.on("typing", ({ receiverId, conversationId, groupId }) => {
      if (groupId) {
        socket
          .to(groupId)
          .emit("typing_start", { senderId: userId, conversationId });
      } else if (conversationId) {
        socket
          .to(conversationId)
          .emit("typing_start", { senderId: userId, conversationId });
      }
    });

    socket.on("stop_typing", ({ receiverId, conversationId, groupId }) => {
      if (groupId) {
        socket
          .to(groupId)
          .emit("typing_stop", { senderId: userId, conversationId });
      } else if (conversationId) {
        socket
          .to(conversationId)
          .emit("typing_stop", { senderId: userId, conversationId });
      }
    });

    // ==========================================
    // --- EMOJI REACTIONS ---
    // ==========================================
    socket.on("add_reaction", async ({ messageId, chatId, emoji }) => {
      try {
        const msg = await Message.findById(messageId);
        if (!msg) return;

        // Check if user already reacted with this exact emoji
        const existingIndex = msg.reactions.findIndex(
          (r) => r.userId === userId && r.emoji === emoji,
        );

        if (existingIndex > -1) {
          // Toggle off
          msg.reactions.splice(existingIndex, 1);
        } else {
          // Optional: Limit to 1 emoji per user per message
          msg.reactions = msg.reactions.filter((r) => r.userId !== userId);
          msg.reactions.push({ userId, emoji });
        }

        await msg.save();

        io.to(chatId).emit("message_reaction_update", {
          messageId,
          reactions: msg.reactions,
          conversationId: chatId,
        });
      } catch (error) {
        logger.error("Reaction Error:", error);
      }
    });

    // ==========================================
    // --- AGORA CALL SIGNALING & DB LOGGING ---
    // ==========================================

    socket.on(
      "initiate_call",
      async ({ targetUserId, channelName, callerData }) => {
        let enrichedCallerData = { ...callerData };

        try {
          const callerProfile = await UserProfile.findOne({
            userId: userId,
          }).select("fullName profilePicture");

          if (callerProfile) {
            enrichedCallerData.callerName =
              callerProfile.fullName || "Alumni User";
            enrichedCallerData.callerAvatar =
              callerProfile.profilePicture || null;
          }

          if (!callerData.isGroupCall) {
            await CallLog.create({
              caller: userId,
              receiver: targetUserId,
              channelName: channelName,
              callType: callerData.isVideoCall ? "video" : "voice",
              status: "initiated",
            });
          }
        } catch (error) {
          logger.error("Error creating CallLog:", error);
        }

        socket.to(targetUserId).emit("incoming_call", {
          callerId: userId,
          channelName,
          callerData: enrichedCallerData,
        });

        const ringTimer = setTimeout(async () => {
          logger.info(`Call Ring Timeout triggered for ${channelName}`);
          io.to(targetUserId)
            .to(userId)
            .emit("call_ended", { channelName, reason: "No Answer" });

          await CallLog.updateOne(
            { channelName: channelName, status: "initiated" },
            { status: "missed", endTime: new Date() },
          );
          activeCallTimers.delete(channelName);
        }, MAX_RING_TIME);

        activeCallTimers.set(channelName, {
          timer: ringTimer,
          caller: userId,
          receiver: targetUserId,
        });
      },
    );

    // ==========================================
    // --- CALL HEARTBEAT & STUCK CALL FIX ---
    // ==========================================
    socket.on("answer_call", async ({ targetUserId, channelName }) => {
      try {
        await CallLog.findOneAndUpdate(
          { channelName: channelName },
          { status: "ongoing", startTime: new Date() },
        );
      } catch (error) {
        logger.error("Error answering CallLog:", error);
      }

      socket.to(targetUserId).emit("call_answered", { channelName });

      const callData = activeCallTimers.get(channelName);
      if (callData) clearTimeout(callData.timer);

      // ✅ Start the strict 25-second heartbeat timer
      const heartbeatTimer = setTimeout(async () => {
        logger.warn(
          `Missed heartbeat for ${channelName}. Force terminating stuck call.`,
        );

        io.to(targetUserId)
          .to(userId)
          .emit("call_ended", { channelName, reason: "Connection Lost" });

        await CallLog.updateOne(
          { channelName: channelName, status: "ongoing" },
          { status: "ended", endTime: new Date() },
        );
        activeCallTimers.delete(channelName);
      }, 25000);

      activeCallTimers.set(channelName, {
        timer: heartbeatTimer,
        caller: userId,
        receiver: targetUserId,
      });
    });

    // ✅ New Heartbeat Listener from Mobile Client
    socket.on("call_heartbeat", ({ channelName }) => {
      const callData = activeCallTimers.get(channelName);

      if (callData) {
        clearTimeout(callData.timer);

        // Reset the strict 25-second countdown
        const newTimer = setTimeout(async () => {
          logger.warn(
            `Missed heartbeat for ${channelName}. Force terminating stuck call.`,
          );
          io.to(callData.receiver)
            .to(callData.caller)
            .emit("call_ended", { channelName, reason: "Connection Lost" });

          await CallLog.updateOne(
            { channelName: channelName, status: "ongoing" },
            { status: "ended", endTime: new Date() },
          );
          activeCallTimers.delete(channelName);
        }, 25000);

        callData.timer = newTimer;
      }
    });

    socket.on("end_call", async ({ targetUserId, channelName }) => {
      const callData = activeCallTimers.get(channelName);
      if (callData) {
        clearTimeout(callData.timer);
        activeCallTimers.delete(channelName);
      }

      try {
        const log = await CallLog.findOne({ channelName: channelName });
        if (log) {
          let finalStatus = "ended";
          let duration = 0;

          if (log.status === "initiated") {
            finalStatus =
              userId.toString() === log.caller.toString()
                ? "missed"
                : "declined";
          } else if (log.status === "ongoing") {
            const endTime = new Date();
            duration = Math.round((endTime - log.startTime) / 1000);
            finalStatus = "ended";
          }

          await CallLog.updateOne(
            { _id: log._id },
            { status: finalStatus, endTime: new Date(), duration: duration },
          );

          io.to(targetUserId).emit("call_log_generated");
          socket.emit("call_log_generated");
        }
      } catch (error) {
        logger.error("Error ending CallLog:", error);
      }

      socket.to(targetUserId).emit("call_ended", { channelName });
    });

    // ==========================================
    // --- BUSY SIGNAL / CALL REJECTION ---
    // ==========================================
    socket.on("reject_call", async ({ targetUserId, reason }) => {
      // 'targetUserId' is the ID of the person who originally initiated the call.
      // We need to tell them that the person they are calling is busy.
      if (targetUserId) {
        io.to(targetUserId).emit("call_rejected", {
          callerId: userId, // The ID of the person who is currently busy
          reason: reason || "user_busy",
        });

        // 1. Clear the ringing timer so the server stops tracking this call
        // (We need to find the channelName from the activeCallTimers map)
        for (const [channelName, data] of activeCallTimers.entries()) {
          if (data.receiver === userId && data.caller === targetUserId) {
            clearTimeout(data.timer);
            activeCallTimers.delete(channelName);

            // 2. Update the Database Call Log to show it was declined/busy
            try {
              await CallLog.updateOne(
                { channelName: channelName, status: "initiated" },
                { status: "declined", endTime: new Date() },
              );
            } catch (error) {
              logger.error("Error updating CallLog on busy reject:", error);
            }
            break; // Found and handled, exit loop
          }
        }
      }
    });

    socket.on("disconnect", async () => {
      await handleDisconnect(socket, userId);
    });
  });

  return io;
};

const handleConnection = async (socket, userId) => {
  if (disconnectTimers.has(userId)) {
    clearTimeout(disconnectTimers.get(userId));
    disconnectTimers.delete(userId);
  }

  const count = await addSocketToUser(userId, socket.id);

  if (count === 1) {
    await UserAuth.findByIdAndUpdate(userId, { isOnline: true }).catch((e) =>
      logger.error(e),
    );
    io.emit("user_status_update", { userId, isOnline: true });
  }
};

const handleDisconnect = async (socket, userId) => {
  await removeSocketFromUser(userId, socket.id);

  const timer = setTimeout(async () => {
    const count = await getSocketCount(userId);

    if (count === 0) {
      const lastSeen = new Date();
      await UserAuth.findByIdAndUpdate(userId, { isOnline: false, lastSeen });
      io.emit("user_status_update", { userId, isOnline: false, lastSeen });
    }
  }, 5000);

  disconnectTimers.set(userId, timer);
};

const getIO = () => {
  if (!io) throw new Error("Socket.io not initialized!");
  return io;
};

// ✅ Cleanup function for graceful shutdown
const closeSocket = async () => {
  if (io) {
    io.close();
    logger.info("🛑 Socket.io server closed.");
  }
  if (redisClient && redisClient.isOpen) {
    await redisClient.quit();
    logger.info("🛑 Redis client disconnected.");
  }
};

module.exports = { initializeSocket, getIO, closeSocket };
