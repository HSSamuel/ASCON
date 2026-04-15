const router = require("express").Router();
const UserAuth = require("../models/UserAuth");
const UserProfile = require("../models/UserProfile");
const UserSettings = require("../models/UserSettings");
const Group = require("../models/Group");
const verifyToken = require("./verifyToken");
const upload = require("../config/cloudinary");
// ✅ ADDED: Import ID Generator
const { generateAlumniId } = require("../utils/idGenerator");

// ✅ Centralized Profile Completeness Logic
const calculateProfileCompleteness = (profile) => {
  let totalScore = 0;
  const maxScore = 8;

  if (profile.profilePicture) totalScore++;
  if (profile.jobTitle) totalScore++;
  if (profile.organization) totalScore++;
  if (profile.industry) totalScore++;
  if (profile.city) totalScore++;
  if (profile.bio) totalScore++;
  if (profile.linkedin) totalScore++;
  if (profile.dateOfBirth) totalScore++;

  const percent = totalScore / maxScore;
  return {
    percent: percent,
    isComplete: percent >= 0.85,
  };
};

// =========================================================
// 1. UPDATE PROFILE & SETTINGS
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

      // 2. ✅ CRITICAL: Fetch Current Profile (To detect changes)
      const currentProfile = await UserProfile.findOne({
        userId: req.user._id,
      });
      if (!currentProfile) {
        return res.status(404).json({ message: "User profile not found" });
      }

      // ✅ NEW: GENERATE ID IF MISSING
      // If the user doesn't have an ID yet, generate it now based on the NEW year provided.
      let generatedAlumniId = currentProfile.alumniId;
      if (!generatedAlumniId && newYear) {
        console.log(
          `🆕 First-time setup: Generating Alumni ID for Year ${newYear}`,
        );
        generatedAlumniId = await generateAlumniId(newYear);
      }

      // 3. ✅ GROUP SYNC LOGIC (Year Change)
      const oldYear = currentProfile.yearOfAttendance;

      // Check if year changed (using loose equality to handle string/number diffs)
      // OR if we are assigning it for the first time (oldYear is null)
      if (newYear && newYear != oldYear) {
        console.log(
          `🔄 Year changed from ${oldYear} to ${newYear}. Syncing Groups...`,
        );

        // A. Remove from Old Group (Only if exists)
        if (oldYear) {
          const oldGroupName = `Class of ${oldYear}`;
          await Group.findOneAndUpdate(
            { name: oldGroupName, type: "Class" },
            { $pull: { members: req.user._id } },
          );
        }

        // B. Add to New Group
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

      // Handle Boolean Toggles
      const isMentor = req.body.isOpenToMentorship === "true";
      const isLocationVisible = req.body.isLocationVisible === "true";
      const isBirthdayVisible = req.body.isBirthdayVisible === "true";

      // Handle Skills Array
      let skillsArray = [];
      if (req.body.skills && typeof req.body.skills === "string") {
        skillsArray = req.body.skills
          .split(",")
          .map((s) => s.trim())
          .filter((s) => s.length > 0);
      }

      // ✅ 4. PREPARE PROFILE DATA
      const profileUpdateData = {
        fullName: req.body.fullName,
        bio: req.body.bio,
        jobTitle: req.body.jobTitle,
        organization: req.body.organization,
        linkedin: req.body.linkedin,
        phoneNumber: req.body.phoneNumber,
        yearOfAttendance: newYear, // Use sanitized year
        alumniId: generatedAlumniId, // ✅ Save the potentially new ID
        programmeTitle: req.body.programmeTitle,
        customProgramme: req.body.customProgramme,
        industry: req.body.industry || "",
        city: req.body.city || "",
        state: req.body.state || "",
        skills: skillsArray,
      };

      if (req.body.dateOfBirth && req.body.dateOfBirth !== "null") {
        profileUpdateData.dateOfBirth = new Date(req.body.dateOfBirth);
      }

      if (req.file) {
        profileUpdateData.profilePicture = req.file.path;
      }

      // ✅ 5. PREPARE SETTINGS DATA
      const settingsUpdateData = {
        isLocationVisible: isLocationVisible,
        isOpenToMentorship: isMentor,
        isBirthdayVisible: isBirthdayVisible,
      };

      // ✅ 6. RUN UPDATES IN PARALLEL
      const [updatedProfile, updatedSettings] = await Promise.all([
        UserProfile.findOneAndUpdate(
          { userId: req.user._id },
          { $set: profileUpdateData },
          { new: true, runValidators: true },
        ),
        UserSettings.findOneAndUpdate(
          { userId: req.user._id },
          { $set: settingsUpdateData },
          { new: true },
        ),
      ]);

      res
        .status(200)
        .json({ ...updatedProfile.toObject(), ...updatedSettings.toObject() });
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
      ...settings.toObject(),
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
