const cron = require("node-cron");
const mongoose = require("mongoose");
const UserProfile = require("../models/UserProfile");
const UserAuth = require("../models/UserAuth");
const admin = require("firebase-admin");
const logger = require("../utils/logger");

const runWeeklySmartMatch = () => {
  // ⏰ Runs every Tuesday at 9:00 AM
  cron.schedule("0 9 * * 2", async () => {
    logger.info("🤖 Starting Weekly Smart Match Engine...");

    try {
      // 1. Get all active users who have an FCM Token (Can receive pushes)
      const activeUsers = await UserAuth.find({
        fcmTokens: { $exists: true, $not: { $size: 0 } },
        isVerified: true,
      }).select("_id fcmTokens");

      let pushCount = 0;

      // 2. Loop through users to find their optimal match
      for (const authUser of activeUsers) {
        const currentUserProfile = await UserProfile.findOne({
          userId: authUser._id,
        });
        if (!currentUserProfile) continue;

        // 3. AI-Lite Aggregation Pipeline
        const matchPipeline = [
          { $match: { userId: { $ne: authUser._id } } }, // Exclude self
          {
            $addFields: {
              // Rule 1: Industry Match (10 pts)
              industryScore: {
                $cond: [
                  { $eq: ["$industry", currentUserProfile.industry] },
                  10,
                  0,
                ],
              },
              // Rule 2: Class Year Match (1 pt)
              yearScore: {
                $cond: [
                  {
                    $eq: [
                      "$yearOfAttendance",
                      currentUserProfile.yearOfAttendance,
                    ],
                  },
                  1,
                  0,
                ],
              },
              // Rule 3: Shared Skills (2 pts per shared skill)
              skillsIntersect: {
                $setIntersection: [
                  { $ifNull: ["$skills", []] },
                  { $ifNull: [currentUserProfile.skills, []] },
                ],
              },
            },
          },
          {
            $addFields: {
              skillScore: { $multiply: [{ $size: "$skillsIntersect" }, 2] },
            },
          },
          {
            $addFields: {
              totalScore: {
                $add: ["$industryScore", "$yearScore", "$skillScore"],
              },
            },
          },
          // Filter out low-value matches (Must have at least something in common)
          { $match: { totalScore: { $gt: 0 } } },
          // Sort by highest score and take the top 1
          { $sort: { totalScore: -1 } },
          { $limit: 1 },
        ];

        const topMatchResult = await UserProfile.aggregate(matchPipeline);

        // 4. Send the targeted FCM Push Notification
        if (topMatchResult.length > 0) {
          const match = topMatchResult[0];

          let title = "🌟 New Connection Highlight";
          let body = `You share a strong professional background with ${match.fullName}. Tap to view their profile.`;

          if (match.isOpenToMentorship) {
            title = "🤝 Mentorship Opportunity";
            body = `${match.fullName} is open to mentorship in your industry. Tap to connect!`;
          }

          const message = {
            notification: {
              title: title,
              body: body,
            },
            data: {
              type: "new_match",
              route: "alumni_detail", // Triggers frontend routing
              id: match.userId.toString(),
              fullName: match.fullName,
            },
            tokens: authUser.fcmTokens,
          };

          try {
            await admin.messaging().sendEachForMulticast(message);
            pushCount++;
          } catch (err) {
            // Silently catch inactive tokens
          }
        }
      }

      logger.info(
        `✅ Smart Match Engine Complete. Sent ${pushCount} personalized pushes.`,
      );
    } catch (error) {
      logger.error("❌ Smart Match Engine Failed:", error);
    }
  });
};

module.exports = runWeeklySmartMatch;
