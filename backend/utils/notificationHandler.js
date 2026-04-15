const admin = require("../config/firebase");
const UserAuth = require("../models/UserAuth");
const Notification = require("../models/Notification");
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
            if (
              errorCode === "messaging/registration-token-not-registered" ||
              errorCode === "messaging/invalid-registration-token"
            ) {
              failedTokens.push(uniqueTokens[idx]);
            }
          }
        });
        if (failedTokens.length > 0)
          await cleanupTokens(user._id, failedTokens);
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
    const isCall = data.type === "call_offer" || data.type === "video_call";

    // Only save non-call notifications to DB history
    if (title && body && !isCall) {
      const newNotification = new Notification({
        recipientId: userId,
        title,
        message: body,
        isBroadcast: false,
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

    // ✅ FIX: ALWAYS send Standard Notification (Visible Banner)
    // This forces the user to tap the notification to open the app.
    // CallKit is removed, so we rely on this title/body to alert the user.

    // If title is null (e.g. from socketService), use default
    const displayTitle =
      title || (isCall ? "Incoming Call" : "New Notification");
    const displayBody =
      body || (isCall ? "Tap to answer..." : "You have a new message");

    const message = {
      notification: {
        title: displayTitle,
        body: displayBody,
      },
      android: {
        notification: {
          channelId: isCall ? "ascon_call_channel" : "ascon_high_importance",
          priority: "high",
          sound: "default",
          visibility: "public",
        },
      },
      data: {
        ...data,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      tokens: uniqueTokens,
    };

    const response = await admin.messaging().sendEachForMulticast(message);

    const failedTokens = [];
    response.responses.forEach((res, idx) => {
      if (!res.success) {
        const errorCode = res.error?.code;
        if (
          errorCode === "messaging/registration-token-not-registered" ||
          errorCode === "messaging/invalid-registration-token"
        ) {
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

module.exports = { sendBroadcastNotification, sendPersonalNotification };
