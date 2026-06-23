const admin = require("../config/firebase");
const UserAuth = require("../models/UserAuth");
const Notification = require("../models/Notification");
const UserProfile = require("../models/UserProfile");
const logger = require("./logger");

const getUniqueTokens = (user) => {
  let allTokens = [];
  if (user.fcmTokens && user.fcmTokens.length > 0) {
    allTokens = [...user.fcmTokens];
  }
  if (user.deviceToken && !allTokens.includes(user.deviceToken)) {
    allTokens.push(user.deviceToken);
  }
  return [...new Set(allTokens)];
};

const cleanupTokens = async (userId, tokensToRemove) => {
  if (tokensToRemove.length === 0) return;
  try {
    await UserAuth.findByIdAndUpdate(userId, {
      $pull: { fcmTokens: { $in: tokensToRemove } },
    });
    logger.info(
      `🧹 Cleaned up ${tokensToRemove.length} invalid tokens for user ${userId}`,
    );
  } catch (err) {
    logger.error(`❌ Token Cleanup Error: ${err.message}`);
  }
};

const sendBroadcastNotification = async (title, body, data = {}) => {
  try {
    const newNotification = new Notification({
      title,
      message: body,
      isBroadcast: true,
      data: data,
    });
    await newNotification.save();
    logger.info("💾 Broadcast saved to database.");

    const usersWithTokens = await UserAuth.find({
      $or: [
        { fcmTokens: { $exists: true, $not: { $size: 0 } } },
        { deviceToken: { $exists: true, $ne: null, $ne: "" } },
      ],
    }).select("_id fcmTokens deviceToken");

    if (usersWithTokens.length === 0) {
      logger.warn("⚠️ No users found with FCM Tokens.");
      return;
    }

    const promises = usersWithTokens.map(async (user) => {
      const uniqueTokens = getUniqueTokens(user);
      if (uniqueTokens.length === 0) return;

      const message = {
        notification: { title, body },
        android: {
          notification: {
            channelId: "ascon_high_importance",
            priority: "high",
          },
        },
        data: { ...data, click_action: "FLUTTER_NOTIFICATION_CLICK" },
        tokens: uniqueTokens,
      };

      try {
        const response = await admin.messaging().sendEachForMulticast(message);
        const failedTokens = [];

        response.responses.forEach((res, idx) => {
          if (!res.success) {
            const errorCode = res.error?.code;
            const invalidTokenErrors = [
              "messaging/registration-token-not-registered",
              "messaging/invalid-registration-token",
              "messaging/invalid-argument",
              "messaging/mismatched-credential",
            ];

            if (invalidTokenErrors.includes(errorCode)) {
              failedTokens.push(uniqueTokens[idx]);
            }
          }
        });

        if (failedTokens.length > 0) {
          await cleanupTokens(user._id, failedTokens);
        }
      } catch (sendError) {
        logger.warn(`Failed to send to user ${user._id}: ${sendError.message}`);
      }
    });

    await Promise.all(promises);
  } catch (error) {
    logger.error(`❌ Broadcast Failed: ${error.message}`);
  }
};

const sendPersonalNotification = async (userId, title, body, data = {}) => {
  try {
    // ✅ FIX: Ensure call_ended and call_rejected are processed as silent data calls
    const isCall =
      data.type === "call_offer" ||
      data.type === "video_call" ||
      data.type === "incoming_call" ||
      data.type === "call_ended" ||
      data.type === "call_rejected";

    const extractedSenderId = data.senderId || data.id || null;
    const extractedProfilePic = data.profilePicture || "";

    if (title && body && !isCall) {
      const newNotification = new Notification({
        recipientId: userId,
        title,
        message: body,
        isBroadcast: false,
        senderId: extractedSenderId,
        profilePicture: extractedProfilePic,
        data: data,
      });
      await newNotification.save();
    }

    const user = await UserAuth.findById(userId).select(
      "fcmTokens deviceToken",
    );
    if (!user) return;

    const uniqueTokens = getUniqueTokens(user);
    if (uniqueTokens.length === 0) {
      logger.warn(`⚠️ User ${userId} has no tokens.`);
      return;
    }

    let message = {
      tokens: uniqueTokens,
    };

    if (isCall) {
      const safeStringifiedData = {};
      for (const [key, value] of Object.entries(data)) {
        safeStringifiedData[key] =
          typeof value === "object" ? JSON.stringify(value) : String(value);
      }

      message.data = {
        ...safeStringifiedData,
        type: data.type || "incoming_call",
      };

      message.android = {
        priority: "high",
      };

      message.apns = {
        headers: { "apns-priority": "10" },
        payload: { aps: { "content-available": 1 } },
      };
    } else {
      message.notification = {
        title: title || "New Notification",
        body: body || "You have a new message",
      };
      message.data = {
        ...data,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      };
      message.android = {
        notification: {
          channelId: "ascon_high_importance",
          priority: "high",
          sound: "default",
          visibility: "public",
        },
      };
    }

    const response = await admin.messaging().sendEachForMulticast(message);

    const failedTokens = [];
    response.responses.forEach((res, idx) => {
      if (!res.success) {
        const errorCode = res.error?.code;
        const invalidTokenErrors = [
          "messaging/registration-token-not-registered",
          "messaging/invalid-registration-token",
          "messaging/invalid-argument",
          "messaging/mismatched-credential",
        ];

        if (invalidTokenErrors.includes(errorCode)) {
          failedTokens.push(uniqueTokens[idx]);
        }
      }
    });

    if (failedTokens.length > 0) {
      await cleanupTokens(user._id, failedTokens);
    }
  } catch (error) {
    logger.error(`❌ Personal Notification Error: ${error.message}`);
  }
};

const notifyPeersOfNewUser = async (newUserProfile) => {
  try {
    const { userId, fullName, yearOfAttendance, city, profilePicture } =
      newUserProfile;

    const queries = [];

    if (
      yearOfAttendance &&
      yearOfAttendance !== "General" &&
      yearOfAttendance !== "Unknown"
    ) {
      queries.push({ yearOfAttendance: yearOfAttendance });
    }

    if (city && city.trim() !== "") {
      queries.push({ city: { $regex: new RegExp(`^${city.trim()}$`, "i") } });
    }

    if (queries.length === 0) return;

    const peers = await UserProfile.find({
      userId: { $ne: userId },
      $or: queries,
    }).select("userId yearOfAttendance city");

    if (peers.length === 0) return;

    const newUserIdStr = userId.toString();
    const firstName = fullName.split(" ")[0];

    const promises = peers.map((peer) => {
      let title = "New Alumni Joined! 🎉";
      let body = `${firstName} just joined the ASCON Alumni Network!`;

      if (peer.yearOfAttendance == yearOfAttendance) {
        title = "Classmate Alert! 🎓";
        body = `${fullName} from your Class of ${yearOfAttendance} just joined!`;
      } else if (
        peer.city &&
        city &&
        peer.city.toLowerCase() === city.toLowerCase()
      ) {
        title = "New Alumni Near You! 📍";
        body = `${firstName} just joined the network from ${city}. Say hi!`;
      }

      return sendPersonalNotification(peer.userId.toString(), title, body, {
        type: "new_alumni",
        route: "alumni_detail",
        id: newUserIdStr,
        senderId: newUserIdStr,
        profilePicture: profilePicture || "",
        fullName: fullName,
      });
    });

    await Promise.all(promises);
    logger.info(`📢 Notified ${peers.length} peers about new user ${fullName}`);
  } catch (err) {
    logger.error(`❌ Error notifying peers: ${err.message}`);
  }
};

module.exports = {
  sendBroadcastNotification,
  sendPersonalNotification,
  notifyPeersOfNewUser,
};
