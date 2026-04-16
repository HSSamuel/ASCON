const admin = require("firebase-admin");
const dotenv = require("dotenv");
const logger = require("../utils/logger"); // ✅ Import Logger

dotenv.config();

try {
  const serviceAccount = JSON.parse(
    Buffer.from(process.env.FIREBASE_SERVICE_ACCOUNT, "base64").toString("utf8")
  );

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
  logger.info("🔥 Firebase Admin Initialized Successfully"); // ✅ Logger
} catch (error) {
  logger.error(`❌ Firebase Admin Init Error: ${error.message}`); // ✅ Logger
}

module.exports = admin;
