const mongoose = require("mongoose");
const dotenv = require("dotenv");

// Load Environment Variables
dotenv.config();

// Import Models
const UserAuth = require("./models/UserAuth");
const UserProfile = require("./models/UserProfile");
const UserSettings = require("./models/UserSettings");

// ⚠️ We need to temporarily define the Old User schema just to read the old data
const oldUserSchema = new mongoose.Schema({}, { strict: false });
const OldUser = mongoose.model("User", oldUserSchema, "users");

const migrateUsers = async () => {
  try {
    console.log("⏳ Connecting to Database...");
    await mongoose.connect(process.env.DB_CONNECT);
    console.log("✅ Database Connected.");

    // 1. Fetch all old users
    const oldUsers = await OldUser.find({});
    console.log(`📦 Found ${oldUsers.length} users in the old collection.`);

    if (oldUsers.length === 0) {
      console.log("No users to migrate. Exiting.");
      process.exit(0);
    }

    let successCount = 0;
    let failCount = 0;

    // 2. Loop through and migrate each user
    for (const oldUser of oldUsers) {
      try {
        // Check if already migrated
        const existingAuth = await UserAuth.findOne({ email: oldUser.email });
        if (existingAuth) {
          console.log(`⏩ Skipping ${oldUser.email} (Already migrated)`);
          continue;
        }

        // STEP 1: Create UserAuth
        const newAuth = new UserAuth({
          email: oldUser.email,
          password: oldUser.password, // Keep existing hashed password
          isVerified: oldUser.isVerified ?? true,
          isAdmin: oldUser.isAdmin ?? false,
          canEdit: oldUser.canEdit ?? false,
          provider: oldUser.provider || "local",
          isOnline: false,
          fcmTokens: oldUser.fcmTokens || [],
        });
        const savedAuth = await newAuth.save();

        // STEP 2: Create UserProfile
        const newProfile = new UserProfile({
          userId: savedAuth._id,
          fullName: oldUser.fullName || "Unknown",
          alumniId: oldUser.alumniId,
          profilePicture: oldUser.profilePicture || "",
          bio: oldUser.bio || "",
          phoneNumber: oldUser.phoneNumber || "",
          linkedin: oldUser.linkedin || "",
          industry: oldUser.industry || "",
          skills: oldUser.skills || [],
          jobTitle: oldUser.jobTitle || "",
          organization: oldUser.organization || "",
          programmeTitle: oldUser.programmeTitle || "",
          yearOfAttendance: oldUser.yearOfAttendance || null,
          city: oldUser.city || "",
        });
        await newProfile.save();

        // STEP 3: Create UserSettings
        const newSettings = new UserSettings({
          userId: savedAuth._id,
          isPhoneVisible: oldUser.isPhoneVisible ?? false,
          isEmailVisible: oldUser.isEmailVisible ?? true,
          isLocationVisible: oldUser.isLocationVisible ?? false,
          isOpenToMentorship: oldUser.isOpenToMentorship ?? false,
          hasSeenWelcome: oldUser.hasSeenWelcome ?? true,
        });
        await newSettings.save();

        successCount++;
        console.log(`✅ Migrated: ${oldUser.email}`);
      } catch (err) {
        failCount++;
        console.error(`❌ Failed to migrate ${oldUser.email}:`, err.message);
      }
    }

    console.log("-----------------------------------");
    console.log("🎉 MIGRATION COMPLETE!");
    console.log(`✅ Successfully Migrated: ${successCount}`);
    console.log(`❌ Failed: ${failCount}`);
    console.log("-----------------------------------");

    process.exit(0);
  } catch (error) {
    console.error("❌ Fatal Error during migration:", error);
    process.exit(1);
  }
};

// Run the script
migrateUsers();
