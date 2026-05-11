const router = require("express").Router();
const UserAuth = require("../models/UserAuth");
const UserProfile = require("../models/UserProfile");
const UserSettings = require("../models/UserSettings");
const Group = require("../models/Group");
const verifyToken = require("./verifyToken");
const upload = require("../config/cloudinary");
const { generateAlumniId } = require("../utils/idGenerator");
const { notifyPeersOfNewUser } = require("../utils/notificationHandler");

// =========================================================
// ✅ CLEANED: Profile Completeness Logic
// =========================================================
const calculateProfileCompleteness = (profile) => {
  let totalScore = 0;
  // We now base completion strictly on the 5 available core fields
  const maxScore = 5;

  if (profile.profilePicture && profile.profilePicture.trim() !== "")
    totalScore++;
  if (profile.jobTitle && profile.jobTitle.trim() !== "") totalScore++;
  if (profile.organization && profile.organization.trim() !== "") totalScore++;
  if (profile.bio && profile.bio.trim() !== "") totalScore++;
  if (profile.yearOfAttendance) totalScore++;

  const percent = totalScore / maxScore;
  return {
    percent: percent,
    isComplete: percent >= 0.99, // Using 0.99 to account for tiny JS float math discrepancies
  };
};

// =========================================================
// 1. UPDATE PROFILE
// =========================================================
router.put("/update", verifyToken, (req, res) => {
  const uploadMiddleware = upload.single("profilePicture");

  uploadMiddleware(req, res, async (err) => {
    if (err) {
      console.error("❌ UPLOAD CRASH:", err);
      return res.status(500).json({
        message: "Image upload failed. Check Cloudinary keys.",
        error: err.message,
      });
    }

    try {
      // 1. Sanitize Year
      let newYear = req.body.yearOfAttendance;
      if (!newYear || newYear === "null" || newYear === "" || isNaN(newYear)) {
        newYear = null;
      }

      // 2. Fetch Current Profile
      const currentProfile = await UserProfile.findOne({
        userId: req.user._id,
      });
      if (!currentProfile) {
        return res.status(404).json({ message: "User profile not found" });
      }

      // Generate Alumni ID if missing
      let generatedAlumniId = currentProfile.alumniId;
      let isFirstTimeSetup = false;

      if (!generatedAlumniId && newYear) {
        generatedAlumniId = await generateAlumniId(newYear);
        isFirstTimeSetup = true;
      }

      // 3. GROUP SYNC LOGIC (Year Change)
      const oldYear = currentProfile.yearOfAttendance;
      if (newYear && newYear != oldYear) {
        if (oldYear) {
          const oldGroupName = `Class of ${oldYear}`;
          await Group.findOneAndUpdate(
            { name: oldGroupName, type: "Class" },
            { $pull: { members: req.user._id } },
          );
        }
        const newGroupName = `Class of ${newYear}`;
        await Group.findOneAndUpdate(
          { name: newGroupName, type: "Class" },
          {
            $addToSet: { members: req.user._id },
            $setOnInsert: {
              description: `Official group for the ${newGroupName}`,
            },
          },
          { upsert: true, new: true },
        );
      }

      // 4. ✅ CLEANED: PREPARE PROFILE DATA (Old fields completely removed)
      const profileUpdateData = {
        fullName: req.body.fullName,
        bio: req.body.bio,
        jobTitle: req.body.jobTitle,
        organization: req.body.organization,
        yearOfAttendance: newYear,
        alumniId: generatedAlumniId,
        programmeTitle: req.body.programmeTitle,
        customProgramme: req.body.customProgramme,
      };

      if (req.file) {
        profileUpdateData.profilePicture = req.file.path;
      }

      // 5. UPDATE PROFILE
      const updatedProfile = await UserProfile.findOneAndUpdate(
        { userId: req.user._id },
        { $set: profileUpdateData },
        { new: true, runValidators: true },
      );

      // Fetch settings just to maintain UI data contract safely
      const currentSettings =
        (await UserSettings.findOne({ userId: req.user._id })) || {};

      // 6. NOTIFY PEERS (Only on first-time setup)
      if (isFirstTimeSetup) {
        notifyPeersOfNewUser(updatedProfile).catch((err) =>
          console.error("❌ Peer notification failed:", err),
        );
      }

      res
        .status(200)
        .json({
          ...updatedProfile.toObject(),
          ...(currentSettings.toObject ? currentSettings.toObject() : {}),
        });
    } catch (dbError) {
      console.error("❌ DATABASE ERROR:", dbError);
      res
        .status(500)
        .json({ message: "Database Error", error: dbError.message });
    }
  });
});

// =========================================================
// 2. GET MY PROFILE (With Calculated Stats)
// =========================================================
router.get("/me", verifyToken, async (req, res) => {
  try {
    const [auth, profile, settings] = await Promise.all([
      UserAuth.findById(req.user._id).select("-password"),
      UserProfile.findOne({ userId: req.user._id }),
      UserSettings.findOne({ userId: req.user._id }),
    ]);

    if (!auth || !profile) {
      return res.status(404).json({ message: "User not found" });
    }

    const completeness = calculateProfileCompleteness(profile);

    const fullProfile = {
      _id: auth._id,
      email: auth.email,
      isVerified: auth.isVerified,
      isAdmin: auth.isAdmin,
      isOnline: auth.isOnline,
      lastSeen: auth.lastSeen,
      ...profile.toObject(),
      ...(settings ? settings.toObject() : {}),
      profileCompletionPercent: completeness.percent,
      isProfileComplete: completeness.isComplete,
    };

    res.status(200).json(fullProfile);
  } catch (err) {
    res.status(500).json(err);
  }
});

// =========================================================
// 3. WELCOME STATUS
// =========================================================
router.put("/welcome-seen", verifyToken, async (req, res) => {
  try {
    const settings = await UserSettings.findOneAndUpdate(
      { userId: req.user._id },
      { hasSeenWelcome: true },
    );

    if (!settings) {
      return res.status(404).json({ message: "User settings not found" });
    }

    res.status(200).json({ message: "Welcome status updated" });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
