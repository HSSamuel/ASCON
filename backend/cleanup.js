const mongoose = require("mongoose");
const dotenv = require("dotenv");

// Load your environment variables so it can connect to your DB
dotenv.config();

// Connect to MongoDB
mongoose
  .connect(process.env.DB_CONNECT)
  .then(async () => {
    console.log("✅ Connected to MongoDB.");
    console.log("🧹 Starting database cleanup...");

    try {
      // 1. Clean up User Profiles
      const profileResult = await mongoose.connection.db
        .collection("userprofiles")
        .updateMany(
          {}, // Match all documents
          {
            $unset: {
              phoneNumber: "",
              linkedin: "",
              industry: "",
              city: "",
              state: "",
              country: "",
              dateOfBirth: "",
              isOpenToMentorship: "",
              isLocationVisible: "",
            },
          },
        );
      console.log(
        `✅ Cleaned ${profileResult.modifiedCount} UserProfile documents.`,
      );

      // 2. Clean up User Settings
      const settingsResult = await mongoose.connection.db
        .collection("usersettings")
        .updateMany(
          {}, // Match all documents
          {
            $unset: {
              isPhoneVisible: "",
              isLocationVisible: "",
              isOpenToMentorship: "",
              isBirthdayVisible: "",
            },
          },
        );
      console.log(
        `✅ Cleaned ${settingsResult.modifiedCount} UserSettings documents.`,
      );

      console.log("🎉 Database cleanup complete!");
      process.exit(0); // Exit the script successfully
    } catch (error) {
      console.error("❌ Cleanup failed:", error);
      process.exit(1);
    }
  })
  .catch((err) => {
    console.error("❌ Database Connection Failed:", err);
  });
