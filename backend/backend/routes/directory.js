const router = require("express").Router();
const mongoose = require("mongoose");
const UserAuth = require("../models/UserAuth");
const UserProfile = require("../models/UserProfile");
const UserSettings = require("../models/UserSettings");
const verifyToken = require("./verifyToken");

// =========================================================
// 🔒 HELPER: REGEX SANITIZER (PREVENTS ReDoS ATTACKS)
// =========================================================
const escapeRegex = (string) => {
  return string.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
};

// =========================================================
// 1. DIRECTORY SEARCH (PROTECTED)
// =========================================================
router.get("/", verifyToken, async (req, res) => {
  try {
    const { search, mentorship, classmates } = req.query;

    let profileMatch = {};
    let settingsMatch = {};

    // Filter by Mentorship Status
    if (mentorship === "true") {
      settingsMatch["settings.isOpenToMentorship"] = true;
    }

    // Filter by Classmates (Same Year)
    if (classmates === "true") {
      const currentUser = await UserProfile.findOne({
        userId: req.user._id,
      }).select("yearOfAttendance");
      if (currentUser && currentUser.yearOfAttendance) {
        profileMatch.yearOfAttendance = currentUser.yearOfAttendance;
      } else {
        profileMatch.yearOfAttendance = -1;
      }
    }

    // Search Logic (Profile Text Search)
    if (search) {
      const isYear = !isNaN(search);
      if (isYear) {
        profileMatch.yearOfAttendance = Number(search);
      } else {
        const sanitizedSearch = escapeRegex(search);
        profileMatch.$text = { $search: sanitizedSearch };
      }
    }

    // Aggregation Pipeline
    const alumniList = await UserProfile.aggregate([
      { $match: profileMatch },

      // ✅ OPTIMIZATION: Exclude the currently logged-in user right at the database level!
      {
        $match: { userId: { $ne: new mongoose.Types.ObjectId(req.user._id) } },
      },

      // Join with Auth table to check verification & online status
      {
        $lookup: {
          from: "userauths",
          localField: "userId",
          foreignField: "_id",
          as: "auth",
        },
      },
      { $unwind: "$auth" },
      { $match: { "auth.isVerified": true } },

      // Join with Settings table
      {
        $lookup: {
          from: "usersettings",
          localField: "userId",
          foreignField: "userId",
          as: "settings",
        },
      },
      { $unwind: "$settings" },
      { $match: settingsMatch },

      // Sorting: Online first, then Mentors, then Year
      {
        $sort: {
          "auth.isOnline": -1,
          "settings.isOpenToMentorship": -1,
          yearOfAttendance: -1,
        },
      },

      // Limits the payload size sent over the network
      { $limit: 50 },

      // Project final fields
      {
        $project: {
          _id: "$userId",
          fullName: 1,
          profilePicture: 1,
          programmeTitle: 1,
          yearOfAttendance: 1,
          alumniId: 1,
          jobTitle: 1,
          organization: 1,
          bio: 1,
          linkedin: 1,
          phoneNumber: 1,
          industry: 1,
          city: 1,
          email: "$auth.email",
          isOnline: "$auth.isOnline",
          lastSeen: "$auth.lastSeen",
          isOpenToMentorship: "$settings.isOpenToMentorship",
        },
      },
    ]);

    res.json({ success: true, data: alumniList });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// =========================================================
// 2. SMART CAREER MATCH (AI-LITE)
// =========================================================
router.get("/smart-matches", verifyToken, async (req, res) => {
  try {
    const currentUserId = new mongoose.Types.ObjectId(req.user._id);

    const currentProfile = await UserProfile.findOne({ userId: currentUserId });
    if (!currentProfile)
      return res.status(404).json({ message: "User not found" });

    const userSkills = currentProfile.skills || [];
    const userIndustry = currentProfile.industry
      ? currentProfile.industry.toLowerCase()
      : "";

    const topMatches = await UserProfile.aggregate([
      { $match: { userId: { $ne: currentUserId } } },
      {
        $lookup: {
          from: "userauths",
          localField: "userId",
          foreignField: "_id",
          as: "auth",
        },
      },
      { $unwind: "$auth" },
      { $match: { "auth.isVerified": true } },
      {
        $lookup: {
          from: "usersettings",
          localField: "userId",
          foreignField: "userId",
          as: "settings",
        },
      },
      { $unwind: "$settings" },

      // Calculate scores
      {
        $addFields: {
          industryMatch: {
            $cond: [{ $eq: [{ $toLower: "$industry" }, userIndustry] }, 10, 0],
          },
          programmeMatch: {
            $cond: [
              { $eq: ["$programmeTitle", currentProfile.programmeTitle] },
              1,
              0,
            ],
          },
          yearMatch: {
            $cond: [
              { $eq: ["$yearOfAttendance", currentProfile.yearOfAttendance] },
              1,
              0,
            ],
          },
          skillMatch: {
            $multiply: [
              {
                $size: {
                  $setIntersection: [{ $ifNull: ["$skills", []] }, userSkills],
                },
              },
              2,
            ],
          },
        },
      },
      {
        $addFields: {
          matchScore: {
            $add: [
              "$industryMatch",
              "$programmeMatch",
              "$yearMatch",
              "$skillMatch",
            ],
          },
        },
      },
      { $match: { matchScore: { $gt: 0 } } },
      { $sort: { matchScore: -1 } },
      { $limit: 15 },
      {
        $project: {
          _id: "$userId",
          fullName: 1,
          jobTitle: 1,
          organization: 1,
          profilePicture: 1,
          industry: 1,
          skills: 1,
          city: 1,
          programmeTitle: 1,
          yearOfAttendance: 1,
          isOnline: "$auth.isOnline",
          lastSeen: "$auth.lastSeen",
          isOpenToMentorship: "$settings.isOpenToMentorship",
          matchScore: 1,
        },
      },
    ]);

    res.json({ success: true, data: topMatches });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// =========================================================
// 3. ALUMNI NEAR ME (GEOLOCATION)
// =========================================================
router.get("/near-me", verifyToken, async (req, res) => {
  try {
    const currentUserId = new mongoose.Types.ObjectId(req.user._id);
    const { city } = req.query;

    const currentProfile = await UserProfile.findOne({ userId: currentUserId });
    const targetLocation = city || currentProfile.city || currentProfile.state;

    if (!targetLocation) {
      return res.json({
        success: true,
        data: [],
        message: "No location set in your profile.",
      });
    }

    const safeLocation = escapeRegex(targetLocation);

    const nearbyUsers = await UserProfile.aggregate([
      {
        $match: {
          userId: { $ne: currentUserId },
          $or: [
            { city: { $regex: new RegExp(safeLocation, "i") } },
            { state: { $regex: new RegExp(safeLocation, "i") } },
          ],
        },
      },
      {
        $lookup: {
          from: "userauths",
          localField: "userId",
          foreignField: "_id",
          as: "auth",
        },
      },
      { $unwind: "$auth" },
      { $match: { "auth.isVerified": true } },
      {
        $lookup: {
          from: "usersettings",
          localField: "userId",
          foreignField: "userId",
          as: "settings",
        },
      },
      { $unwind: "$settings" },
      { $match: { "settings.isLocationVisible": true } },
      { $limit: 30 }, // Pagination limit you approved earlier
      {
        $project: {
          _id: "$userId",
          fullName: 1,
          jobTitle: 1,
          organization: 1,
          profilePicture: 1,
          city: 1,
          state: 1,
          phoneNumber: 1,
          email: "$auth.email",
          isOnline: "$auth.isOnline",
          lastSeen: "$auth.lastSeen",
          isOpenToMentorship: "$settings.isOpenToMentorship",
        },
      },
    ]);

    res.json({ success: true, data: nearbyUsers, location: targetLocation });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// =========================================================
// 4. RECOMMENDATIONS (FOR CAROUSEL)
// =========================================================
router.get("/recommendations", verifyToken, async (req, res) => {
  try {
    const currentUserId = new mongoose.Types.ObjectId(req.user._id);

    const currentProfile = await UserProfile.findOne({ userId: currentUserId });
    if (!currentProfile)
      return res.status(404).json({ message: "Profile not found" });

    const { yearOfAttendance, programmeTitle } = currentProfile;

    const matches = await UserProfile.aggregate([
      {
        $match: {
          userId: { $ne: currentUserId },
          $or: [{ yearOfAttendance }, { programmeTitle }],
        },
      },
      {
        $lookup: {
          from: "userauths",
          localField: "userId",
          foreignField: "_id",
          as: "auth",
        },
      },
      { $unwind: "$auth" },
      { $match: { "auth.isVerified": true } },
      {
        $lookup: {
          from: "usersettings",
          localField: "userId",
          foreignField: "userId",
          as: "settings",
        },
      },
      { $unwind: "$settings" },
      { $limit: 10 },
      {
        $project: {
          _id: "$userId",
          fullName: 1,
          profilePicture: 1,
          jobTitle: 1,
          organization: 1,
          yearOfAttendance: 1,
          bio: 1,
          programmeTitle: 1,
          phoneNumber: 1,
          linkedin: 1,
          email: "$auth.email",
          isOnline: "$auth.isOnline",
          lastSeen: "$auth.lastSeen",
          isOpenToMentorship: "$settings.isOpenToMentorship",
          isPhoneVisible: "$settings.isPhoneVisible",
        },
      },
    ]);

    res.json({ success: true, matches });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// =========================================================
// 5. BIRTHDAY & ANNIVERSARY CELEBRATIONS
// =========================================================
router.get("/celebrations", verifyToken, async (req, res) => {
  try {
    const today = new Date();
    const day = today.getDate();
    const month = today.getMonth() + 1;
    const currentYear = today.getFullYear();

    const birthdays = await UserProfile.aggregate([
      {
        $match: {
          dateOfBirth: { $exists: true, $ne: null },
        },
      },
      {
        $lookup: {
          from: "usersettings",
          localField: "userId",
          foreignField: "userId",
          as: "settings",
        },
      },
      {
        $unwind: {
          path: "$settings",
          preserveNullAndEmptyArrays: true,
        },
      },
      {
        $project: {
          fullName: 1,
          profilePicture: 1,
          jobTitle: 1,
          dobDay: { $dayOfMonth: "$dateOfBirth" },
          dobMonth: { $month: "$dateOfBirth" },
          isVisible: { $ifNull: ["$settings.isBirthdayVisible", true] },
        },
      },
      {
        $match: {
          dobDay: day,
          dobMonth: month,
          isVisible: true,
        },
      },
    ]);

    const milestoneYears = [];
    for (let i = 5; i <= 60; i += 5) {
      milestoneYears.push(currentYear - i);
    }

    const anniversaries = await UserProfile.aggregate([
      {
        $match: {
          yearOfAttendance: { $in: milestoneYears },
        },
      },
      {
        $group: {
          _id: "$yearOfAttendance",
          count: { $sum: 1 },
          representativeImages: { $push: "$profilePicture" },
        },
      },
      {
        $project: {
          year: "$_id",
          yearsAgo: { $subtract: [currentYear, "$_id"] },
          count: 1,
          images: { $slice: ["$representativeImages", 3] },
        },
      },
      { $sort: { year: -1 } },
    ]);

    res.json({
      success: true,
      data: {
        birthdays,
        anniversaries,
      },
    });
  } catch (err) {
    console.error("Celebration Error:", err);
    res.status(500).json({ message: err.message });
  }
});

// =========================================================
// 6. SINGLE ALUMNI DETAILS
// =========================================================
router.get("/:userId", verifyToken, async (req, res) => {
  try {
    const [auth, profile, settings] = await Promise.all([
      UserAuth.findById(req.params.userId).select(
        "email isOnline lastSeen isVerified",
      ),
      UserProfile.findOne({ userId: req.params.userId }),
      UserSettings.findOne({ userId: req.params.userId }),
    ]);

    if (!profile || !auth)
      return res.status(404).json({ message: "User not found" });

    const fullDetails = {
      _id: auth._id,
      email: auth.email,
      isOnline: auth.isOnline,
      lastSeen: auth.lastSeen,
      isVerified: auth.isVerified,
      ...profile.toObject(),
      ...settings?.toObject(),
    };

    res.json({ success: true, data: fullDetails });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// =========================================================
// 7. VERIFICATION ENDPOINT (PUBLIC)
// =========================================================
router.get("/verify/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const formattedId = id.replace(/-/g, "/");

    const profile = await UserProfile.findOne({ alumniId: formattedId });
    if (!profile) return res.status(404).json({ message: "ID not found" });

    const auth = await UserAuth.findById(profile.userId);

    const publicProfile = {
      fullName: profile.fullName,
      profilePicture: profile.profilePicture,
      programmeTitle: profile.programmeTitle,
      yearOfAttendance: profile.yearOfAttendance,
      alumniId: profile.alumniId,
      status: auth?.isVerified ? "Active" : "Pending",
      jobTitle: profile.jobTitle,
      organization: profile.organization,
    };

    res.json(publicProfile);
  } catch (err) {
    res.status(500).json({ message: "Server Error" });
  }
});

module.exports = router;
