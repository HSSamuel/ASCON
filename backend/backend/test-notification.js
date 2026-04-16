require("dotenv").config();
const mongoose = require("mongoose");
const {
  sendPersonalNotification,
  sendBroadcastNotification,
} = require("./utils/notificationHandler");

// ✅ FIX: Import the correct split models
const UserAuth = require("./models/UserAuth");
const UserProfile = require("./models/UserProfile");

const runTest = async () => {
  try {
    console.log("⏳ Connecting to MongoDB...");

    // Modern Mongoose connection
    await mongoose.connect(process.env.DB_CONNECT);

    console.log("📦 Connected to MongoDB Successfully!");

    // ============================================================
    // 2. FIND ALL USERS WITH TOKENS
    // ============================================================
    console.log("🔍 Scanning UserAuth for active FCM tokens...");

    // ✅ FIX: Query UserAuth instead of User
    const usersWithTokens = await UserAuth.find({
      $or: [
        { fcmTokens: { $exists: true, $not: { $size: 0 } } },
        { deviceToken: { $exists: true, $ne: null, $ne: "" } },
      ],
    });

    console.log(`✅ Found ${usersWithTokens.length} users with tokens.`);

    if (usersWithTokens.length === 0) {
      console.log("⚠️  No users found with tokens. Skipping personal tests.");
    }

    for (const authUser of usersWithTokens) {
      // ✅ FIX: Fetch Profile to get the Name (since it's not in UserAuth)
      const profile = await UserProfile.findOne({ userId: authUser._id });
      const name = profile ? profile.fullName : "Unknown User";

      console.log(
        `🚀 Sending personal test to: ${name} (${authUser.email})...`,
      );

      // 3. TRIGGER PERSONAL NOTIFICATION
      await sendPersonalNotification(
        authUser._id,
        "Test Internal Alert 🔔",
        `Hello ${name}, your ASCON Notification is working!`,
        { route: "profile", status: "testing" },
      );
    }

    console.log("\n📢 Sending a Broadcast test to ALL users...");

    // 4. TRIGGER BROADCAST
    await sendBroadcastNotification(
      "Public Announcement 🏛️",
      "This is a broadcast test from the ASCON Backend.",
    );

    console.log("\n✅ Test sequence complete. Check your phones!");

    // Close connection cleanly
    await mongoose.connection.close();
    process.exit(0);
  } catch (error) {
    console.error("💥 Test Script Crashed:", error);
    process.exit(1);
  }
};

runTest();
